"""
Tests for the cost multiplier `p0` of `Flow(ocp)` and `Flow(ocp, law)`: the abnormal case
`p0 = 0`, a scaled `p0`, the default (normal) case, the wrong sign, and the control-free
flow. `p0` is forwarded to the CTModels getters (control-toolbox/CTModels.jl#532).
"""

module TestFlowP0

using Test: Test
using CTBase: Data
using CTBase: Exceptions
using CTModels: CTModels
using CTFlows: Flows
using CTFlows: Systems
using OrdinaryDiffEqTsit5: Tsit5
using ForwardDiff: ForwardDiff  # triggers the DI ForwardDiff extension (AutoForwardDiff)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

_opts() = (; alg=Tsit5(), reltol=1e-12, abstol=1e-12)

# ẋ = -x + u, ℓ = 0.5u²  (autonomous, fixed), :min or :max
function _build_lqr(criterion::Symbol)
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=(-x + u); nothing))
    CTModels.Building.objective!(pre, criterion; lagrange=(t, x, u, v) -> 0.5 * u^2)
    return CTModels.Building.build(pre)
end

# ẋ = -x, ℓ = 0.5x²  (control-free), :min
function _build_control_free()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=-x; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * x^2)
    return CTModels.Building.build(pre)
end

const U_LAW = (x, p) -> p

function test_flow_p0()
    Test.@testset "Flow p0 (cost multiplier)" verbose = VERBOSE showtiming = SHOWTIMING begin
        ocp = _build_lqr(:min)
        t0, tf, x0, p0 = 0.0, 1.0, 1.0, 0.7

        Test.@testset "Unit: _p0_kwargs and _pop_p0" begin
            Test.@test Flows._p0_kwargs(nothing) == (;)
            Test.@test Flows._p0_kwargs(0) == (; p0=0)
            Test.@test Flows._pop_p0((; p0=0.0, method=:cpu)) == (0.0, (; method=:cpu))
            Test.@test Flows._pop_p0((; a=1)) == (nothing, (; a=1))
        end

        Test.@testset "Unit: builders forward p0 to the getters" begin
            Test.@test Flows._ocp_pseudo_hamiltonian(ocp; p0=0)(
                0.0, 1.0, 2.0, 3.0, nothing
            ) == CTModels.Models.pseudo_hamiltonian(ocp; p0=0)(
                0.0, 1.0, 2.0, 3.0, nothing
            )
            Test.@test Flows._ocp_pseudo_hamiltonian(ocp)(0.0, 1.0, 2.0, 3.0, nothing) ==
                CTModels.Models.pseudo_hamiltonian(ocp)(0.0, 1.0, 2.0, 3.0, nothing)
            # p·f + p⁰ℓ at x=1, p=2, u=3: abnormal 2(-1+3), normal 2(-1+3) - 4.5
            Test.@test Flows._ocp_pseudo_hamiltonian(ocp; p0=0)(
                0.0, 1.0, 2.0, 3.0, nothing
            ) ≈ 4.0
            Test.@test Flows._ocp_pseudo_hamiltonian(ocp)(0.0, 1.0, 2.0, 3.0, nothing) ≈
                -0.5
        end

        Test.@testset "Integration: p0 = default is the normal case (both modes)" begin
            for ht in (:total, :partial)
                f_def = Flows.Flow(ocp, U_LAW; hamiltonian_type=ht, _opts()...)
                f_m1 = Flows.Flow(ocp, U_LAW; p0=-1, hamiltonian_type=ht, _opts()...)
                Test.@test f_def(t0, x0, p0, tf) == f_m1(t0, x0, p0, tf)
            end
        end

        Test.@testset "Integration: abnormal p0 = 0 with u = p" begin
            # H̃ = p(-x + u), u = p: ṗ = p in both modes, p(t) = p0 eᵗ. `:partial` keeps u
            # fixed, ẋ = -x + p0 eᵗ; `:total` differentiates h = p(-x + p), ẋ = -x + 2p0 eᵗ.
            for ht in (:total, :partial)
                f0 = Flows.Flow(ocp, U_LAW; p0=0, hamiltonian_type=ht, _opts()...)
                xf, pf = f0(t0, x0, p0, tf)
                Test.@test pf ≈ p0 * exp(1) atol = 1e-8
                x_exact = x0 * exp(-1) + (ht === :total ? 2 : 1) * p0 * sinh(1)
                Test.@test xf ≈ x_exact atol = 1e-8
                h = Systems.pseudo_hamiltonian(Flows.system(f0))
                Test.@test h(0.0, 1.0, 2.0, 3.0, nothing) ≈ 4.0
            end
        end

        Test.@testset "Integration: scaled p0 and maximisation" begin
            f_scaled = Flows.Flow(ocp, U_LAW; p0=-2, _opts()...)
            h = Systems.pseudo_hamiltonian(Flows.system(f_scaled))
            Test.@test h(0.0, 1.0, 2.0, 3.0, nothing) ≈ 2 * (-1 + 3) - 2 * 4.5
            ocpmax = _build_lqr(:max)
            f_max = Flows.Flow(ocpmax, U_LAW; _opts()...)
            hmax = Systems.pseudo_hamiltonian(Flows.system(f_max))
            Test.@test hmax(0.0, 1.0, 2.0, 3.0, nothing) ≈ 2 * (-1 + 3) + 4.5
        end

        Test.@testset "Integration: constrained flow carries p0" begin
            pre = CTModels.Building.PreModel()
            CTModels.Building.time_dependence!(pre; autonomous=true)
            CTModels.Building.time!(pre; t0=0.0, tf=1.0)
            CTModels.Building.state!(pre, 1)
            CTModels.Building.control!(pre, 1)
            CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=(-x + u); nothing))
            CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
            CTModels.Building.constraint!(pre, :control; lb=[-1.0], ub=[1.0], label=:ubox)
            ocpc = CTModels.Building.build(pre)
            for ht in (:total, :partial)
                f = Flows.Flow(
                    ocpc,
                    U_LAW;
                    p0=0,
                    multipliers=:ubox => ((x, p) -> 0.0),
                    hamiltonian_type=ht,
                    _opts()...,
                )
                sys = Flows.system(f)
                h = Systems.pseudo_hamiltonian(sys)
                # H = p·f + p⁰ℓ + μ-term, μ = 0 and p⁰ = 0: p·f only
                Test.@test h(0.0, 1.0, 2.0, 0.5, 0.0, nothing) ≈ 2 * (-1 + 0.5)
            end
        end

        Test.@testset "Integration: control-free flow" begin
            ocpf = _build_control_free()
            f_def = Flows.Flow(ocpf; _opts()...)
            f_abn = Flows.Flow(ocpf; p0=0, _opts()...)
            h_abn = Systems.hamiltonian(Flows.system(f_abn))
            h_def = Systems.hamiltonian(Flows.system(f_def))
            # H = p·f + p⁰ℓ at x=1, p=2: abnormal -2, normal -2 - 0.5
            Test.@test h_abn(0.0, 1.0, 2.0, nothing) ≈ -2.0
            Test.@test h_def(0.0, 1.0, 2.0, nothing) ≈ -2.5
            # abnormal: ṗ = p, x(t) = x0 e^{-t}
            xf, pf = f_abn(t0, x0, p0, tf)
            Test.@test xf ≈ x0 * exp(-1) atol = 1e-8
            Test.@test pf ≈ p0 * exp(1) atol = 1e-8
        end

        Test.@testset "Error: p0 whose sign contradicts the criterion" begin
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(ocp, U_LAW; p0=1)
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(
                _build_lqr(:max), U_LAW; p0=-1
            )
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(
                _build_control_free(); p0=1
            )
        end
    end
end

end # module

test_flow_p0() = TestFlowP0.test_flow_p0()
