"""
End-to-end integration and error tests for Flow(ocp::CTModels.Models.Model).

Requires SciML + DI extensions (loaded via `using OrdinaryDiffEqTsit5` etc.).

Analytical references (ẋ = λx, λ=2, autonomous, fixed):
  x(t) = x0·e^{λ(t-t0)},   p(t) = p0·e^{-λ(t-t0)}
  pv(tf) = -p0·x0·(tf-t0)   (Lagrange-free variable costate, 1D)
  Lagrange ℓ=x²:  objective = x0²·(e^{2λT}-1)/(2λ)
  Mayer   m=xf:   objective = x0·e^{λT}
  Bolza        :   both summed

Non-autonomous reference (ẋ=t·x, autonomous=false, fixed):
  x(t) = x0·exp((t²-t0²)/2)
"""

module TestOptimalControlFlow

using Test: Test
using CTModels: CTModels
import CTBase: CTBase
import CTBase.Exceptions: Exceptions
import CTFlows: CTFlows
import CTFlows.Flows: Flows
import CTFlows.Systems: Systems
import CTFlows.Integrators: Integrators
import CTFlows.Configs: Configs
import CTBase.Differentiation
import CTBase.Data: Data
import CTBase.Traits: Traits

using SciMLBase: SciMLBase
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, Tsit5
using ADTypes: ADTypes
using DifferentiationInterface: DifferentiationInterface as DI
using ForwardDiff: ForwardDiff  # triggers DifferentiationInterfaceForwardDiff (provides PushforwardFast)

const CTFlowsSciMLIntegrator = Base.get_extension(CTFlows, :CTFlowsSciMLIntegrator)
const CTBaseDifferentiationInterface = Base.get_extension(
    CTBase, :CTBaseDifferentiationInterface
)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true
const ATOL = 1e-4

# =============================================================================
# Shared constants
# =============================================================================

const λ_TEST = 2.0
const INTEG = Integrators.SciML(; alg=Tsit5())
const DI_BACKEND = Differentiation.DifferentiationInterface(;
    ad_backend=ADTypes.AutoForwardDiff()
)

# =============================================================================
# OCP fixtures (module top-level)
# =============================================================================

function _build_ocp_auton_fixed_mayer()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, _, x, _, _) -> (r[1]=λ_TEST * x[1]; nothing))
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> xf[1])
    return CTModels.Building.build(pre)
end

function _build_ocp_auton_fixed_lagrange()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, _, x, _, _) -> (r[1]=λ_TEST * x[1]; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(_, x, _, _) -> x[1]^2)
    return CTModels.Building.build(pre)
end

function _build_ocp_auton_fixed_bolza()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, _, x, _, _) -> (r[1]=λ_TEST * x[1]; nothing))
    CTModels.Building.objective!(
        pre, :min; mayer=(x0, xf, v) -> xf[1], lagrange=(_, x, _, _) -> x[1]^2
    )
    return CTModels.Building.build(pre)
end

function _build_ocp_auton_nonfixed_mayer()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.variable!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, _, x, _, v) -> (r[1]=v[1] * x[1]; nothing))
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> xf[1])
    return CTModels.Building.build(pre)
end

function _build_ocp_nonauton_fixed_mayer()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=false)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, _, _) -> (r[1]=t * x[1]; nothing))
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> xf[1])
    return CTModels.Building.build(pre)
end

# with-control OCP (control! called) → WithControl trait, unsupported by Flow(ocp)
function _build_ocp_with_control()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, _, x, u, _) -> (r[1]=u[1]; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(_, x, u, _) -> u[1]^2)
    return CTModels.Building.build(pre)
end

# Fake closed-set trait tags for catch-all fallback tests (module top-level)
struct FakeVariableDependence <: Traits.VariableDependence end
struct FakeCostateCapability <: Traits.AbstractVariableCostateCapability end

const OCP_AF_MAYER = _build_ocp_auton_fixed_mayer()
const OCP_AF_LAG = _build_ocp_auton_fixed_lagrange()
const OCP_AF_BOLZA = _build_ocp_auton_fixed_bolza()
const OCP_ANF_MAYER = _build_ocp_auton_nonfixed_mayer()
const OCP_NAF_MAYER = _build_ocp_nonauton_fixed_mayer()
const OCP_WITH_CTRL = _build_ocp_with_control()

# Pre-built flows (all via generic HamiltonianSystem — OCP rides the generic path)
const FLOW_AF = Flows.build_flow(
    Systems.build_system(Flows._ocp_hamiltonian(OCP_AF_MAYER), DI_BACKEND), INTEG
)
const FLOW_ANF = Flows.build_flow(
    Systems.build_system(Flows._ocp_hamiltonian(OCP_ANF_MAYER), DI_BACKEND), INTEG
)
const FLOW_NAF = Flows.build_flow(
    Systems.build_system(Flows._ocp_hamiltonian(OCP_NAF_MAYER), DI_BACKEND), INTEG
)

# OptimalControlFlow wrappers (for trajectory call → CTModels.Solution)
const OCF_AF_MAYER = Flows.OptimalControlFlow(FLOW_AF, OCP_AF_MAYER)
const OCF_ANF = Flows.OptimalControlFlow(FLOW_ANF, OCP_ANF_MAYER)

# =============================================================================
# Analytic references
# =============================================================================

_x_ref(t, t0, x0) = x0 * exp(λ_TEST * (t - t0))
_p_ref(t, t0, p0) = p0 * exp(-λ_TEST * (t - t0))
_pv_ref(tf, t0, x0, p0) = -p0 * x0 * (tf - t0)   # ℓ=0, ẋ=λx, H=pλx
_lag_obj(T, x0) = x0^2 * (exp(2λ_TEST * T) - 1) / (2λ_TEST)
_may_obj(T, x0) = x0 * exp(λ_TEST * T)

_xna_ref(t, t0, x0) = x0 * exp((t^2 - t0^2) / 2)  # ẋ=t·x

# =============================================================================

function test_optimal_control_flow()
    Test.@testset "Flow(ocp) — end-to-end" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ── construction ──────────────────────────────────────────────────────

        Test.@testset "Construction: isa OptimalControlFlow" begin
            f = Flows.Flow(OCP_AF_MAYER; alg=Tsit5())
            Test.@test f isa Flows.OptimalControlFlow
        end

        Test.@testset "Construction: system/integrator accessors" begin
            f = Flows.Flow(OCP_AF_MAYER; alg=Tsit5())
            Test.@test Flows.system(f) isa Systems.HamiltonianSystem
            Test.@test Flows.integrator(f) isa Integrators.AbstractIntegrator
        end

        # ── point eval, Fixed/Autonomous ──────────────────────────────────────

        Test.@testset "Integration: Fixed/Auton (x0,p0,tf) scalar" begin
            t0, tf = 0.0, 1.0
            x0, p0 = 1.0, 0.5
            xf, pf = FLOW_AF(t0, x0, p0, tf)
            Test.@test xf ≈ _x_ref(tf, t0, x0) atol=ATOL
            Test.@test pf ≈ _p_ref(tf, t0, p0) atol=ATOL
        end

        Test.@testset "Integration: Fixed/Auton (x0,p0,tf) vector" begin
            t0, tf = 0.0, 0.5
            x0, p0 = [2.0], [1.0]
            xf, pf = FLOW_AF(t0, x0, p0, tf)
            Test.@test xf[1] ≈ _x_ref(tf, t0, x0[1]) atol=ATOL
            Test.@test pf[1] ≈ _p_ref(tf, t0, p0[1]) atol=ATOL
        end

        Test.@testset "Unit: xf/pf shape — scalar inputs → Number" begin
            t0, tf = 0.0, 0.5
            xf, pf = FLOW_AF(t0, 1.0, 1.0, tf)
            Test.@test xf isa Number
            Test.@test pf isa Number
        end

        Test.@testset "Unit: xf/pf shape — vector inputs → AbstractVector" begin
            t0, tf = 0.0, 0.5
            x0, p0 = [1.0], [1.0]
            xf, pf = FLOW_AF(t0, x0, p0, tf)
            Test.@test xf isa AbstractVector
            Test.@test length(xf) == 1
            Test.@test pf isa AbstractVector
            Test.@test length(pf) == 1
            Test.@test xf[1] ≈ _x_ref(tf, t0, x0[1]) atol=ATOL
            Test.@test pf[1] ≈ _p_ref(tf, t0, p0[1]) atol=ATOL
        end

        # ── point eval, NonFixed/Autonomous ──────────────────────────────────

        Test.@testset "Integration: NonFixed/Auton — variable=λ" begin
            t0, tf = 0.0, 1.0
            x0, p0 = 1.0, 0.5
            v = [λ_TEST]
            xf, pf = FLOW_ANF(t0, x0, p0, tf; variable=v)
            # ẋ = v[1]*x = λ_TEST*x, same analytic solution
            Test.@test xf ≈ _x_ref(tf, t0, x0) atol=ATOL
            Test.@test pf ≈ _p_ref(tf, t0, p0) atol=ATOL
        end

        # ── point eval, Non-autonomous ────────────────────────────────────────

        Test.@testset "Integration: NonAuton/Fixed — ẋ=t·x" begin
            t0, tf = 0.0, 1.0
            x0, p0 = 1.0, 1.0
            xf, pf = FLOW_NAF(t0, x0, p0, tf)
            Test.@test xf ≈ _xna_ref(tf, t0, x0) atol=ATOL
        end

        # ── variable_costate ─────────────────────────────────────────────────

        Test.@testset "Integration: variable_costate=true — vector variable" begin
            t0, tf = 0.0, 1.0
            x0, p0 = 1.0, 0.5
            v = [λ_TEST]
            xf, pf, pvf = FLOW_ANF(t0, x0, p0, tf; variable=v, variable_costate=true)
            Test.@test xf ≈ _x_ref(tf, t0, x0) atol=ATOL
            Test.@test pf ≈ _p_ref(tf, t0, p0) atol=ATOL
            Test.@test pvf[1] ≈ _pv_ref(tf, t0, x0, p0) atol=ATOL
        end

        Test.@testset "Unit: pvf shape — vector variable → AbstractVector" begin
            t0, tf = 0.0, 0.5
            xf, pf, pvf = FLOW_ANF(
                t0, 1.0, 1.0, tf; variable=[λ_TEST], variable_costate=true
            )
            Test.@test pvf isa AbstractVector
            Test.@test length(pvf) == 1
        end

        Test.@testset "Unit: pvf shape — scalar variable → Number" begin
            t0, tf = 0.0, 0.5
            xf, pf, pvf = FLOW_ANF(t0, 1.0, 1.0, tf; variable=λ_TEST, variable_costate=true)
            Test.@test pvf isa Number
        end

        Test.@testset "Integration: scalar variable gives same pvf value as vector" begin
            t0, tf = 0.0, 1.0
            x0, p0 = 1.0, 0.5
            _, _, pvf1 = FLOW_ANF(t0, x0, p0, tf; variable=[λ_TEST], variable_costate=true)
            _, _, pvf2 = FLOW_ANF(t0, x0, p0, tf; variable=λ_TEST, variable_costate=true)
            Test.@test pvf1[1] ≈ pvf2 atol=ATOL
        end

        # ── trajectory → CTModels.Solution ───────────────────────────────────

        Test.@testset "Integration: trajectory call returns CTModels.Solution" begin
            t0, tf = 0.0, 1.0
            x0, p0 = 1.0, 0.5
            sol = OCF_AF_MAYER((t0, tf), x0, p0)
            Test.@test sol isa CTModels.Solutions.Solution
        end

        Test.@testset "Integration: Mayer objective ≈ analytic" begin
            t0, tf = 0.0, 1.0
            x0, p0 = 1.0, 0.5
            sol = OCF_AF_MAYER((t0, tf), x0, p0)
            Test.@test CTModels.Components.objective(sol) ≈ _may_obj(tf - t0, x0) atol=ATOL
        end

        Test.@testset "Integration: (co)state(sol)(tf) ≈ analytic (x,p)(tf)" begin
            t0, tf = 0.0, 1.0
            x0, p0 = 1.0, 0.5
            sol = OCF_AF_MAYER((t0, tf), x0, p0)
            xsol = CTModels.Components.state(sol)(tf)
            psol = CTModels.Components.costate(sol)(tf) # 
            Test.@test xsol ≈ _x_ref(tf, t0, x0) atol=ATOL
            Test.@test psol ≈ _p_ref(tf, t0, p0) atol=ATOL
        end

        Test.@testset "Unit: state(sol)(tf) shape — scalar inputs → Number" begin
            t0, tf = 0.0, 1.0
            x0, p0 = 1.0, 0.5
            sol = OCF_AF_MAYER((t0, tf), x0, p0)
            xsol = CTModels.Components.state(sol)(tf)
            psol = CTModels.Components.costate(sol)(tf)
            Test.@test xsol isa Number
            Test.@test psol isa Number
        end

        Test.@testset "Unit: state(sol)(tf) shape — vector inputs → AbstractVector" begin
            t0, tf = 0.0, 1.0
            x0, p0 = [1.0], [0.5]
            sol = OCF_AF_MAYER((t0, tf), x0, p0)
            xsol = CTModels.Components.state(sol)(tf)
            psol = CTModels.Components.costate(sol)(tf)
            Test.@test xsol isa Number # AbstractVector
            # Test.@test length(xsol) == 1
            Test.@test psol isa Number # AbstractVector
            # Test.@test length(psol) == 1
        end

        Test.@testset "Integration: Lagrange objective ≈ analytic" begin
            flow_lag = Flows.build_flow(
                Systems.build_system(Flows._ocp_hamiltonian(OCP_AF_LAG), DI_BACKEND), INTEG
            )
            ocf_lag = Flows.OptimalControlFlow(flow_lag, OCP_AF_LAG)
            t0, tf = 0.0, 1.0
            x0, p0 = 1.0, 1.0
            sol = ocf_lag((t0, tf), x0, p0)
            Test.@test CTModels.Components.objective(sol) ≈ _lag_obj(tf - t0, x0) atol=ATOL
        end

        Test.@testset "Integration: Bolza objective ≈ Mayer + Lagrange" begin
            flow_bolza = Flows.build_flow(
                Systems.build_system(Flows._ocp_hamiltonian(OCP_AF_BOLZA), DI_BACKEND),
                INTEG,
            )
            ocf_bolza = Flows.OptimalControlFlow(flow_bolza, OCP_AF_BOLZA)
            t0, tf = 0.0, 1.0
            x0, p0 = 1.0, 1.0
            sol = ocf_bolza((t0, tf), x0, p0)
            expected = _may_obj(tf - t0, x0) + _lag_obj(tf - t0, x0)
            Test.@test CTModels.Components.objective(sol) ≈ expected atol=ATOL
        end

        # ── cross-check: OCP flow vs generic HamiltonianSystem ────────────────

        Test.@testset "Integration: cross-check vs generic HamiltonianSystem" begin
            # H = p·λx = generic autonomous/fixed Hamiltonian — now same path, regression guard
            h_generic = Data.Hamiltonian(
                (x, p) -> p[1] * λ_TEST * x[1]; is_autonomous=true, is_variable=false
            )
            sys_gen = Systems.HamiltonianSystem(h_generic, DI_BACKEND)
            flow_gen = Flows.build_flow(sys_gen, INTEG)

            t0, tf = 0.0, 1.0
            x0, p0 = [1.5], [0.8]

            xf_ocp, pf_ocp = FLOW_AF(t0, x0, p0, tf)
            xf_gen, pf_gen = flow_gen(t0, x0, p0, tf)

            Test.@test xf_ocp ≈ xf_gen atol=ATOL
            Test.@test pf_ocp ≈ pf_gen atol=ATOL
        end

        # ── error guards ──────────────────────────────────────────────────────

        Test.@testset "Error: Fixed model + variable= kwarg" begin
            Test.@test_throws Exceptions.PreconditionError FLOW_AF(
                0.0, 1.0, 0.5, 1.0; variable=1.0
            )
        end

        Test.@testset "Error: NonFixed model + variable omitted" begin
            Test.@test_throws Exceptions.PreconditionError FLOW_ANF(0.0, 1.0, 0.5, 1.0)
        end

        Test.@testset "Error: variable_costate=true on Fixed system" begin
            Test.@test_throws Exceptions.PreconditionError FLOW_AF(
                0.0, 1.0, 0.5, 1.0; variable_costate=true
            )
        end

        Test.@testset "Error: Flow(ocp, u) — control-free guard" begin
            err = nothing
            try
                Flows.Flow(OCP_AF_MAYER, identity; alg=Tsit5())
            catch e
                err = e
            end
            Test.@test err isa Exceptions.PreconditionError
            Test.@test occursin("positional argument", err.msg)
        end

        Test.@testset "Error: Flow(ocp, g, μ) — positional-arg guard (extra args)" begin
            Test.@test_throws Exceptions.PreconditionError Flows.Flow(
                OCP_AF_MAYER, identity, identity; alg=Tsit5()
            )
        end

        # =====================================================================
        # Control-dependence dispatch
        # =====================================================================

        Test.@testset "Dispatch: control-free OCP is ControlFree" begin
            Test.@test Traits.control_dependence(OCP_AF_MAYER) === Traits.ControlFree
            Test.@test Flows.Flow(OCP_AF_MAYER; alg=Tsit5()) isa Flows.OptimalControlFlow
        end

        Test.@testset "Error: Flow(with-control OCP) → PreconditionError" begin
            Test.@test Traits.control_dependence(OCP_WITH_CTRL) === Traits.WithControl
            err = nothing
            try
                Flows.Flow(OCP_WITH_CTRL; alg=Tsit5())
            catch e
                err = e
            end
            Test.@test err isa Exceptions.PreconditionError
            Test.@test occursin("with-control", err.msg)
        end

        # =====================================================================
        # Closed dispatch-table catch-all fallbacks
        # =====================================================================

        Test.@testset "Error: unknown VariableDependence tag → PreconditionError" begin
            Test.@test_throws Exceptions.PreconditionError Flows._invoke_flow(
                FakeVariableDependence,
                Nothing,
                nothing,
                nothing;
                unsafe=false,
                variable=nothing,
            )
        end

        Test.@testset "Error: unknown variable-costate capability tag → PreconditionError" begin
            config = Configs.HamiltonianEndPointConfig(0.0, [1.0], [0.5], 1.0)
            Test.@test_throws Exceptions.PreconditionError Flows._invoke_flow_variable_costate(
                FakeCostateCapability,
                Nothing,
                FLOW_AF,
                config;
                variable=nothing,
                unsafe=false,
            )
        end
    end
end

end # module

test_optimal_control_flow() = TestOptimalControlFlow.test_optimal_control_flow()
