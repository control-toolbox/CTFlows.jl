"""
Integration tests for the basic (non-Hamiltonian, no-costate) flow of a control-free
OCP: `Flow(ocp)` called as `f(t0,x0,tf)` / `f((t0,tf),x0)` — the direct-shooting use
case (issue #230).
"""

module TestOCPBasicFlow

using Test: Test
using DifferentiationInterface: DifferentiationInterface
using ForwardDiff: ForwardDiff  # triggers DifferentiationInterfaceForwardDiff (provides PushforwardFast)
using StaticArrays: SA, SVector
import CTBase.Data: Data
import CTBase.Exceptions: Exceptions
import CTModels: CTModels
import CTFlows.Flows: Flows
import CTFlows.Trajectories: Trajectories
import CTFlows.Integrators: Integrators
using OrdinaryDiffEqTsit5: Tsit5

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

_opts() = (; alg=Tsit5(), reltol=1e-12, abstol=1e-12)

const λ_TEST = 2.0

# =============================================================================
# OCP fixtures at module top-level
# =============================================================================

# control-free, autonomous, fixed: ẋ = -λx, mayer = xf ⇒ xf = x0·e^{-λ(tf-t0)}
function _build_cf_fixed()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=(-λ_TEST * x[1]); nothing))
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> xf[1])
    return CTModels.Building.build(pre)
end

# control-free, autonomous, non-fixed: ẋ = v·x, mayer = xf ⇒ xf = x0·e^{v(tf-t0)}
function _build_cf_nonfixed()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.variable!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=v[1] * x[1]; nothing))
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> xf[1])
    return CTModels.Building.build(pre)
end

# with-control OCP + DynClosedLoop law — no state-only flow (needs the costate)
function _build_with_control()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=(-x + u); nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    return CTModels.Building.build(pre)
end

# control-free, autonomous, fixed, 2-D: ẋ₁ = -λx₁, ẋ₂ = -λx₂
function _build_cf_fixed_2d()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.dynamics!(
        pre, (r, t, x, u, v) -> (r[1]=(-λ_TEST * x[1]); r[2]=(-λ_TEST * x[2]); nothing)
    )
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> xf[1])
    return CTModels.Building.build(pre)
end

# control-free, autonomous, fixed, 2-D, broadcast dynamics — batch-safe (issue #358): unlike
# _build_cf_fixed_2d's r[1]/x[1] scalar indexing, `r .= -λ .* x` also works column-wise on a
# batched Matrix state (each column an independent trajectory).
function _build_cf_fixed_2d_broadcast()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r .= -λ_TEST .* x; nothing))
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> xf[1])
    return CTModels.Building.build(pre)
end

const OCP_CF_FIXED = _build_cf_fixed()
const OCP_CF_NONFIXED = _build_cf_nonfixed()
const OCP_CONTROL = _build_with_control()
const OCP_CF_FIXED_2D = _build_cf_fixed_2d()
const OCP_CF_FIXED_2D_BC = _build_cf_fixed_2d_broadcast()

function test_ocp_basic_flow()
    Test.@testset "OCP basic (no-costate) flow" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ── point eval — Fixed ────────────────────────────────────────────

        Test.@testset "Integration: Fixed point eval vs analytic" begin
            f = Flows.Flow(OCP_CF_FIXED; _opts()...)
            t0, tf, x0 = 0.0, 1.0, 2.0
            xf = f(t0, x0, tf)
            Test.@test xf isa Number   # 1-D = scalar convention
            Test.@test xf ≈ x0 * exp(-λ_TEST * (tf - t0)) atol = 1e-8
        end

        Test.@testset "Error: Fixed + variable provided → PreconditionError" begin
            f = Flows.Flow(OCP_CF_FIXED; _opts()...)
            Test.@test_throws Exceptions.PreconditionError f(0.0, 2.0, 1.0; variable=0.1)
        end

        Test.@testset "1-D scalar convention: vector x0 input → scalar output" begin
            f = Flows.Flow(OCP_CF_FIXED; _opts()...)
            t0, tf, x0 = 0.0, 1.0, 2.0
            xf_scalar = f(t0, x0, tf)
            xf_vec = f(t0, [x0], tf)           # length-1 vector input
            Test.@test xf_vec isa Number        # must collapse to scalar
            Test.@test xf_vec ≈ xf_scalar atol = 1e-12
        end

        # ── point eval — NonFixed, + coherence with the Hamiltonian call ────

        Test.@testset "Integration: NonFixed point eval vs analytic" begin
            f = Flows.Flow(OCP_CF_NONFIXED; _opts()...)
            t0, tf, x0, v = 0.0, 1.0, 2.0, 0.5
            xf = f(t0, x0, tf; variable=v)
            Test.@test xf isa Number
            Test.@test xf ≈ x0 * exp(v * (tf - t0)) atol = 1e-8
        end

        Test.@testset "Integration: basic call agrees with the Hamiltonian call" begin
            f = Flows.Flow(OCP_CF_NONFIXED; _opts()...)
            t0, tf, x0, p0, v = 0.0, 1.0, 2.0, 0.0, 0.5
            xf = f(t0, x0, tf; variable=v)              # basic — new
            xf2, _ = f(t0, x0, p0, tf; variable=v)       # Hamiltonian — existing
            Test.@test xf ≈ xf2 atol = 1e-8
        end

        Test.@testset "Error: NonFixed + variable missing → PreconditionError" begin
            f = Flows.Flow(OCP_CF_NONFIXED; _opts()...)
            Test.@test_throws Exceptions.PreconditionError f(0.0, 2.0, 1.0)
        end

        # ── trajectory call — StateFlowTrajectory ───────────────────────────

        Test.@testset "Integration: trajectory call — StateFlowTrajectory" begin
            f = Flows.Flow(OCP_CF_FIXED; _opts()...)
            t0, tf, x0 = 0.0, 1.0, 2.0
            sol = f((t0, tf), x0)
            Test.@test sol isa Trajectories.StateFlowTrajectory
            x = Trajectories.state(sol)
            Test.@test x(tf) ≈ x0 * exp(-λ_TEST * (tf - t0)) atol = 1e-8
            Test.@test Trajectories.objective(sol) ≈ x0 * exp(-λ_TEST * (tf - t0)) atol =
                1e-8
            Test.@test Integrators.successful(sol) == true
            Test.@test Integrators.status(sol) == :Success
        end

        Test.@testset "Error: control / costate on a basic StateFlowTrajectory" begin
            f = Flows.Flow(OCP_CF_FIXED; _opts()...)
            sol = f((0.0, 1.0), 2.0)
            Test.@test_throws Exceptions.PreconditionError Trajectories.control(sol)
            Test.@test_throws Exceptions.PreconditionError Trajectories.costate(sol)
        end

        # ── n-D vector convention (n=2): output stays a vector ─────────────

        Test.@testset "n-D vector convention: 2-D state → vector output" begin
            f = Flows.Flow(OCP_CF_FIXED_2D; _opts()...)
            t0, tf = 0.0, 1.0
            x0 = [2.0, 3.0]
            xf = f(t0, x0, tf)
            Test.@test xf isa AbstractVector && length(xf) == 2
            Test.@test xf ≈ x0 .* exp(-λ_TEST * (tf - t0)) atol = 1e-8
        end

        # ── SVector state (issue #358) ──────────────────────────────────────

        Test.@testset "SVector: point + trajectory now succeed (issue #358)" begin
            f = Flows.Flow(OCP_CF_FIXED_2D; _opts()...)
            t0, tf = 0.0, 1.0
            x0 = SA[2.0, 3.0]
            xf = f(t0, x0, tf)
            Test.@test xf isa SVector
            Test.@test xf ≈ x0 .* exp(-λ_TEST * (tf - t0)) atol = 1e-8

            sol = f((t0, tf), x0)
            xt = Trajectories.state(sol)(tf)
            Test.@test xt isa SVector
            Test.@test xt ≈ x0 .* exp(-λ_TEST * (tf - t0)) atol = 1e-8
        end

        # ── Matrix (batch) state (issue #358) ───────────────────────────────

        Test.@testset "Matrix (batch): point + trajectory now succeed (issue #358)" begin
            # broadcast dynamics (batch-safe) — see OCP_CF_FIXED_2D_BC docstring
            f = Flows.Flow(OCP_CF_FIXED_2D_BC; _opts()...)
            t0, tf = 0.0, 1.0
            X0 = [2.0 3.0; 4.0 5.0]   # 2 columns = 2 independent trajectories, n=2

            Xf = f(t0, X0, tf)
            Test.@test Xf isa AbstractMatrix
            for j in 1:2
                Test.@test Xf[:, j] ≈ f(t0, X0[:, j], tf) atol = 1e-8
            end

            sol = f((t0, tf), X0)
            Xt = Trajectories.state(sol)(tf)
            for j in 1:2
                Test.@test Xt[:, j] ≈ f(t0, X0[:, j], tf) atol = 1e-8
            end
        end

        # ── guard: Flow(ocp, law) has no basic (no-costate) call ────────────

        Test.@testset "Error: Flow(ocp, law) basic call has no state flow" begin
            law = Data.DynClosedLoop((x, p) -> p)
            f = Flows.Flow(OCP_CONTROL, law; _opts()...)
            Test.@test_throws Exceptions.PreconditionError f(0.0, 1.0, 1.0)
            Test.@test_throws Exceptions.PreconditionError f((0.0, 1.0), 1.0)
        end
    end
end

end # module

test_ocp_basic_flow() = TestOCPBasicFlow.test_ocp_basic_flow()
