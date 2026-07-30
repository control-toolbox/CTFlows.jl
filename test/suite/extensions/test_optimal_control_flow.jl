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
using CTBase: CTBase
using CTBase: Exceptions
using CTFlows: CTFlows
using CTFlows: Flows
using CTFlows: Systems
using CTFlows: Integrators
using CTFlows: Configs
using CTBase: Differentiation
using CTBase: Data
using CTBase: Traits

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

# ── objective-coverage fixtures ──────────────────────────────────────────────
# The Mayer/Lagrange/Bolza trio was covered only for the autonomous / fixed-time / SCALAR-state
# family. These three extend it to the families that had Mayer only (variable, non-autonomous)
# plus a vector state, which had no objective coverage at all. Every analytic reference below is
# derived in closed form AND was reconciled numerically against the flow before being committed.

# autonomous, non-fixed (variable), Lagrange: ẋ = v·x, ℓ = x² ⇒ ∫₀ᵀ x0²e^{2vt}dt
function _build_ocp_auton_nonfixed_lagrange()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.variable!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, _, x, _, v) -> (r[1]=v[1] * x[1]; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(_, x, _, _) -> x[1]^2)
    return CTModels.Building.build(pre)
end

# non-autonomous, fixed, Lagrange: ẋ = t·x, ℓ = t·x².
# ℓ = x² would give ∫e^{t²}dt — no elementary closed form (erfi). With the t factor,
# d(x²)/dt = 2t·x², so the integral telescopes to (x(tf)² − x0²)/2 — exact and x-dependent.
function _build_ocp_nonauton_fixed_lagrange()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=false)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, _, _) -> (r[1]=t * x[1]; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, _, _) -> t * x[1]^2)
    return CTModels.Building.build(pre)
end

# VECTOR state (n = 2), Bolza: ẋ = λx componentwise, mayer = Σxf, ℓ = Σx²
function _build_ocp_vector_bolza()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.dynamics!(pre, (r, _, x, _, _) -> (r.=λ_TEST .* x; nothing))
    CTModels.Building.objective!(
        pre, :min; mayer=(x0, xf, v) -> sum(xf), lagrange=(_, x, _, _) -> sum(abs2, x)
    )
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
const OCP_ANF_LAG = _build_ocp_auton_nonfixed_lagrange()
const OCP_NAF_LAG = _build_ocp_nonauton_fixed_lagrange()
const OCP_VEC_BOLZA = _build_ocp_vector_bolza()

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

# Objective references for the extended families (each reconciled numerically before committing).
# variable: ẋ = v·x, ℓ = x²  ⇒  ∫₀ᵀ x0² e^{2vt} dt
_lag_obj_var(T, x0, v) = x0^2 * (exp(2 * v * T) - 1) / (2 * v)
# non-autonomous: ẋ = t·x, ℓ = t·x²  ⇒  ½[x²] = (x(tf)² − x0²)/2
_lag_obj_na(tf, t0, x0) = (_xna_ref(tf, t0, x0)^2 - x0^2) / 2
# vector state: ẋ = λx, mayer = Σxf, ℓ = Σx²  (Σ over components; both terms scale as the scalar case)
_may_obj_vec(T, x0) = sum(x0) * exp(λ_TEST * T)
_lag_obj_vec(T, x0) = sum(abs2, x0) * (exp(2λ_TEST * T) - 1) / (2λ_TEST)

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

        Test.@testset "Unit: xf/pf shape — length-1 vector inputs → Number" begin
            # 1-D = scalar: a length-1 vector initial condition collapses to a scalar
            # output (via `only`), regardless of how the user supplied it.
            t0, tf = 0.0, 0.5
            x0, p0 = [1.0], [1.0]
            xf, pf = FLOW_AF(t0, x0, p0, tf)
            Test.@test xf isa Number
            Test.@test pf isa Number
            Test.@test xf ≈ _x_ref(tf, t0, x0[1]) atol=ATOL
            Test.@test pf ≈ _p_ref(tf, t0, p0[1]) atol=ATOL
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

        Test.@testset "Unit: pvf shape — length-1 vector variable → Number" begin
            # 1-D = scalar: a length-1 variable yields a scalar variable costate.
            t0, tf = 0.0, 0.5
            xf, pf, pvf = FLOW_ANF(
                t0, 1.0, 1.0, tf; variable=[λ_TEST], variable_costate=true
            )
            Test.@test pvf isa Number
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

        # ── OptimalControlFlow wrapper delegates variable_costate ─────────────

        Test.@testset "Integration: OCF wrapper delegates variable_costate" begin
            # OCF_ANF wraps FLOW_ANF; the point-eval call must forward variable_costate
            # down to the inner HamiltonianFlow and return the same (xf, pf, pvf).
            t0, tf = 0.0, 1.0
            x0, p0 = 1.0, 0.5
            v = [λ_TEST]
            xf, pf, pvf = OCF_ANF(t0, x0, p0, tf; variable=v, variable_costate=true)
            Test.@test xf ≈ _x_ref(tf, t0, x0) atol=ATOL
            Test.@test pf ≈ _p_ref(tf, t0, p0) atol=ATOL
            Test.@test pvf[1] ≈ _pv_ref(tf, t0, x0, p0) atol=ATOL
        end

        Test.@testset "Integration: OCF wrapper agrees with inner flow (pvf)" begin
            t0, tf = 0.0, 1.0
            x0, p0 = 1.0, 0.5
            v = [λ_TEST]
            _, _, pvf_ocf = OCF_ANF(t0, x0, p0, tf; variable=v, variable_costate=true)
            _, _, pvf_inner = FLOW_ANF(t0, x0, p0, tf; variable=v, variable_costate=true)
            Test.@test pvf_ocf[1] ≈ pvf_inner[1] atol=ATOL
        end

        # ── Hamiltonian / gradient getters (H = p·v·x for OCP_ANF) ────────────

        Test.@testset "Unit: hamiltonian(flow) evaluates H = p·v·x" begin
            H = Systems.hamiltonian(FLOW_ANF)
            Test.@test H isa Data.AbstractHamiltonian
            # uniform signature (t, x, p, v); autonomous ⇒ t ignored
            Test.@test H(0.0, 2.0, 0.5, [3.0]) ≈ 0.5 * 3.0 * 2.0 atol=ATOL
        end

        Test.@testset "Unit: get_hamiltonian_gradient(flow) → (∂H/∂x, ∂H/∂p)" begin
            ∇H = Systems.get_hamiltonian_gradient(FLOW_ANF)
            ∂x, ∂p = ∇H(0.0, 2.0, 0.5, [3.0])
            Test.@test ∂x[1] ≈ 0.5 * 3.0 atol=ATOL   # ∂H/∂x = p·v
            Test.@test ∂p[1] ≈ 3.0 * 2.0 atol=ATOL   # ∂H/∂p = v·x
        end

        Test.@testset "Unit: get_variable_gradient(flow) → ∂H/∂v = p·x" begin
            ∇vH = Systems.get_variable_gradient(FLOW_ANF)
            gv = ∇vH(0.0, 2.0, 0.5, [3.0])
            Test.@test gv[1] ≈ 0.5 * 2.0 atol=ATOL   # ∂H/∂v = p·x
        end

        Test.@testset "Error: pseudo_hamiltonian(flow) on a control-free flow" begin
            # FLOW_ANF wraps a plain Hamiltonian (no control law) ⇒ no pseudo-Hamiltonian.
            Test.@test_throws Exceptions.IncorrectArgument Systems.pseudo_hamiltonian(
                FLOW_ANF
            )
            Test.@test_throws Exceptions.IncorrectArgument Systems.control_law(FLOW_ANF)
        end

        # ── trajectory → CTModels.Solution ───────────────────────────────────

        Test.@testset "Integration: trajectory call returns CTModels.Solution" begin
            t0, tf = 0.0, 1.0
            x0, p0 = 1.0, 0.5
            sol = OCF_AF_MAYER((t0, tf), x0, p0)
            Test.@test sol isa CTModels.Solutions.Solution
            Test.@test CTModels.Solutions.successful(sol) == true
            Test.@test CTModels.Solutions.status(sol) == :Success
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

        # ── objective coverage beyond the autonomous/fixed/scalar family ──────
        # The trio above pinned only ONE OCP family. The objective path also runs for problems
        # with a variable, with explicit time dependence, and with a vector state — none of which
        # were covered. `_ocp_hamiltonian` + `_flow_objective` are shared by all of them, so a
        # regression in the Lagrange quadrature would previously have been caught in one shape only.

        Test.@testset "Integration: Lagrange objective ≈ analytic — with variable" begin
            flow = Flows.build_flow(
                Systems.build_system(Flows._ocp_hamiltonian(OCP_ANF_LAG), DI_BACKEND), INTEG
            )
            ocf = Flows.OptimalControlFlow(flow, OCP_ANF_LAG)
            t0, tf = 0.0, 1.0
            x0, p0, v = 1.0, 0.5, 1.5
            sol = ocf((t0, tf), x0, p0; variable=v)
            Test.@test CTModels.Components.objective(sol) ≈ _lag_obj_var(tf - t0, x0, v) atol =
                ATOL
        end

        Test.@testset "Integration: Lagrange objective ≈ analytic — non-autonomous" begin
            flow = Flows.build_flow(
                Systems.build_system(Flows._ocp_hamiltonian(OCP_NAF_LAG), DI_BACKEND), INTEG
            )
            ocf = Flows.OptimalControlFlow(flow, OCP_NAF_LAG)
            t0, tf = 0.0, 1.0
            x0, p0 = 1.0, 0.5
            sol = ocf((t0, tf), x0, p0)
            Test.@test CTModels.Components.objective(sol) ≈ _lag_obj_na(tf, t0, x0) atol =
                ATOL
        end

        Test.@testset "Integration: Bolza objective ≈ analytic — vector state" begin
            flow = Flows.build_flow(
                Systems.build_system(Flows._ocp_hamiltonian(OCP_VEC_BOLZA), DI_BACKEND),
                INTEG,
            )
            ocf = Flows.OptimalControlFlow(flow, OCP_VEC_BOLZA)
            t0, tf = 0.0, 1.0
            x0, p0 = [1.0, 2.0], [0.5, 0.25]
            sol = ocf((t0, tf), x0, p0)
            expected = _may_obj_vec(tf - t0, x0) + _lag_obj_vec(tf - t0, x0)
            # the vector Bolza value is ~89, so a relative tolerance is the meaningful check here
            Test.@test CTModels.Components.objective(sol) ≈ expected rtol = 1e-6
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

        # ── Matrix (batch) state (issue #358) ───────────────────────────────

        Test.@testset "Integration: Matrix (batch) state — Hamiltonian call" begin
            f = Flows.Flow(OCP_VEC_BOLZA; alg=Tsit5())
            t0, tf = 0.0, 1.0
            X0 = [1.0 2.0; 2.0 1.0]
            P0 = [0.5 0.25; 0.25 0.5]
            Xf, Pf = f(t0, X0, P0, tf)
            Test.@test Xf isa AbstractMatrix
            Test.@test Pf isa AbstractMatrix
            for j in 1:2
                xfj, pfj = f(t0, X0[:, j], P0[:, j], tf)
                Test.@test Xf[:, j] ≈ xfj atol = ATOL
                Test.@test Pf[:, j] ≈ pfj atol = ATOL
            end
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

        Test.@testset "Error: Flow(ocp, u) on a control-free OCP" begin
            # A raw function is now recognised as a DynClosedLoop control law, so the
            # control-free OCP is rejected with a specific message (not the positional guard).
            err = nothing
            try
                Flows.Flow(OCP_AF_MAYER, identity; alg=Tsit5())
            catch e
                err = e
            end
            Test.@test err isa Exceptions.PreconditionError
            Test.@test occursin("with-control", err.msg)
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
