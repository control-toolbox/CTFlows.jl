"""
`ad_backend=AutoMooncake()` on host arrays (issue #448): every AD-backed right-hand side
integrates and gives the `AutoForwardDiff` result, and differentiating the flow itself with
ForwardDiff is refused with a structured error.

The views built by the Hamiltonian splitters reach Mooncake as dense copies through the
`CTBaseMooncake` extension of CTBase (Mooncake returns a structural tangent for a
`SubArray`, chalk-lab/Mooncake.jl#1294).
"""

module TestMooncakeCPU

using Test: Test
using CTBase: CTBase
using CTBase: Data
using CTBase: Exceptions
using CTFlows: Flows
using CTModels: CTModels
using ADTypes: ADTypes
using DifferentiationInterface: DifferentiationInterface  # loads the CTBase DI extension
using ForwardDiff: ForwardDiff
using Mooncake: Mooncake                                  # loads CTBaseMooncake
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ── fixtures (module top-level) ─────────────────────────────────────────────

const FD = ADTypes.AutoForwardDiff()
const MC = ADTypes.AutoMooncake()
const TOL = (reltol=1e-10, abstol=1e-10)

const H = Data.Hamiltonian((x, p) -> sum(abs2, p) / 2 + sum(sin, x))
const H1 = Data.Hamiltonian((x, p) -> p^2 / 2 + sin(x))
const HV = Data.Hamiltonian(
    (x, p, v) -> sum(abs2, p) / 2 + v[1] * sum(sin, x); is_variable=true
)
const H̃ = Data.PseudoHamiltonian((x, p, u) -> sum(p .* u) - sum(abs2, u) / 2 + sum(sin, x))
const LAW = Data.DynClosedLoop((x, p) -> p)

function _ocp(; variable::Bool=false, control::Bool=false)
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 2)
    variable && CTModels.Building.variable!(pre, 1)
    if control
        CTModels.Building.control!(pre, 2)
        CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r .= u .- sin.(x); nothing))
        CTModels.Building.objective!(
            pre, :min; lagrange=(t, x, u, v) -> 0.5 * sum(abs2, u)
        )
    else
        dyn = variable ? (r, t, x, u, v) -> (r .= v[1] .* sin.(x); nothing) :
            (r, t, x, u, v) -> (r .= sin.(x); nothing)
        CTModels.Building.dynamics!(pre, dyn)
        CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> sum(xf))
    end
    return CTModels.Building.build(pre)
end

const OCP = _ocp()
const OCP_V = _ocp(; variable=true)
const OCP_U = _ocp(; control=true)

const X0, P0 = [0.3, -0.7], [1.0, 0.5]
const BX0, BP0 = [0.3 0.1; -0.7 0.2], [1.0 -1.0; 0.5 0.4]   # a batch of two columns

_flat(r) = r isa Tuple ? reduce(vcat, map(_flat, r)) : r isa Number ? [r] : vec(collect(r))

# name => ad -> result of the call
const CASES = (
    "Flow(h) point" => ad -> Flows.Flow(H; ad_backend=ad, TOL...)(0.0, X0, P0, 1.0),
    "Flow(h) trajectory" =>
        ad -> Flows.Flow(H; ad_backend=ad, TOL...)((0.0, 1.0), X0, P0)(0.5),
    "Flow(h) Matrix batch" =>
        ad -> Flows.Flow(H; ad_backend=ad, TOL...)(0.0, BX0, BP0, 1.0),
    "Flow(h) 1-D" => ad -> Flows.Flow(H1; ad_backend=ad, TOL...)(0.0, 0.3, 1.0, 1.0),
    "Flow(h) variable" => ad -> Flows.Flow(HV; ad_backend=ad, TOL...)(
        0.0, X0, P0, 1.0; variable=[0.5]
    ),
    "Flow(h) variable_costate" => ad -> Flows.Flow(HV; ad_backend=ad, TOL...)(
        0.0, X0, P0, 1.0; variable=[0.5], variable_costate=true
    ),
    "Flow(h̃, law) :total" =>
        ad -> Flows.Flow(H̃, LAW; ad_backend=ad, TOL...)(0.0, X0, P0, 1.0),
    "Flow(h̃, law) :partial" => ad -> Flows.Flow(
        H̃, LAW; hamiltonian_type=:partial, ad_backend=ad, TOL...
    )(0.0, X0, P0, 1.0),
    "Flow(ocp) Hamiltonian call" =>
        ad -> Flows.Flow(OCP; ad_backend=ad, TOL...)(0.0, X0, P0, 1.0),
    "Flow(ocp) Matrix batch" =>
        ad -> Flows.Flow(OCP; ad_backend=ad, TOL...)(0.0, BX0, BP0, 1.0),
    "Flow(ocp) variable_costate" => ad -> Flows.Flow(OCP_V; ad_backend=ad, TOL...)(
        0.0, X0, P0, 1.0; variable=0.5, variable_costate=true
    ),
    "Flow(ocp, law) :total" =>
        ad -> Flows.Flow(OCP_U, LAW; ad_backend=ad, TOL...)(0.0, X0, P0, 1.0),
    "Flow(ocp, law) :partial" => ad -> Flows.Flow(
        OCP_U, LAW; hamiltonian_type=:partial, ad_backend=ad, TOL...
    )(0.0, X0, P0, 1.0),
    "Flow(ocp, law) constrained" => ad -> Flows.Flow(
        OCP_U,
        LAW;
        constraint=(x, u) -> sum(u),
        multiplier=(x, p) -> 0.3,
        ad_backend=ad,
        TOL...,
    )(0.0, X0, P0, 1.0),
)

function test_mooncake_cpu()
    Test.@testset "AutoMooncake on host arrays" verbose=VERBOSE showtiming=SHOWTIMING begin
        Test.@testset "Extension: CTBaseMooncake is loaded" begin
            Test.@test Base.get_extension(CTBase, :CTBaseMooncake) isa Module
        end

        # ====================================================================
        # INTEGRATION — every AD-backed right-hand side, against AutoForwardDiff
        # ====================================================================
        Test.@testset "Integration: $name" for (name, run) in CASES
            ref = _flat(run(FD))
            res = _flat(run(MC))
            Test.@test res ≈ ref atol = 1e-12
        end

        Test.@testset "Integration: large dimension (n = 200)" begin
            n = 200
            x0 = collect(range(-1.0, 1.0; length=n))
            p0 = collect(range(0.5, -0.5; length=n))
            xf_fd, pf_fd = Flows.Flow(H; ad_backend=FD, TOL...)(0.0, x0, p0, 1.0)
            xf_mc, pf_mc = Flows.Flow(H; ad_backend=MC, TOL...)(0.0, x0, p0, 1.0)
            Test.@test xf_mc ≈ xf_fd atol = 1e-12
            Test.@test pf_mc ≈ pf_fd atol = 1e-12
        end

        # ====================================================================
        # ERROR — ForwardDiff through a Mooncake flow (nested AD) is refused
        # ====================================================================
        Test.@testset "Error: outer ForwardDiff → PreconditionError [$kind]" for (kind, call) in
                                                                                 (
            (
                "initial state",
                () -> ForwardDiff.jacobian(
                    z -> _flat(Flows.Flow(H; ad_backend=MC)(0.0, z, P0, 1.0)), X0
                ),
            ),
            (
                "final time",
                () -> ForwardDiff.derivative(
                    T -> sum(Flows.Flow(H; ad_backend=MC)(0.0, X0, P0, T)[1]), 1.0
                ),
            ),
            (
                "variable",
                () -> ForwardDiff.derivative(
                    w -> sum(
                        Flows.Flow(HV; ad_backend=MC)(0.0, X0, P0, 1.0; variable=[w])[1]
                    ),
                    0.5,
                ),
            ),
        )
            Test.@test_throws Exceptions.PreconditionError call()
        end
    end
    return nothing
end

end # module

test_mooncake_cpu() = TestMooncakeCPU.test_mooncake_cpu()
