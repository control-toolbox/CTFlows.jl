"""
Integration tests for OpenLoop / ClosedLoop control flows: state flows returning a
StateFlowTrajectory (state + reconstructed control [+ objective from an OCP]).
"""

module TestStateControlFlows

using Test: Test
using CTBase: Data
using CTBase: Traits
using CTBase: Exceptions
using CTModels: CTModels
using CTFlows: Flows
using CTFlows: Trajectories
using CTFlows: Integrators
using OrdinaryDiffEqTsit5: Tsit5

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

_opts() = (; alg=Tsit5(), reltol=1e-12, abstol=1e-12)

# ẋ = -x + u, ℓ = 0.5u², :min  (autonomous, fixed, 1-D — scalar convention)
function _build_ocp()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=(-x + u); nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    return CTModels.Building.build(pre)
end

function _build_control_free()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=(-x); nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> x^2)
    return CTModels.Building.build(pre)
end

# ẋ = -x + u, ℓ = 0.5u², :min  (autonomous, fixed, 2-D)
function _build_ocp_2d()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 2)
    CTModels.Building.dynamics!(
        pre, (r, t, x, u, v) -> (r[1]=(-x[1] + u[1]); r[2]=(-x[2] + u[2]); nothing)
    )
    CTModels.Building.objective!(
        pre, :min; lagrange=(t, x, u, v) -> 0.5 * (u[1]^2 + u[2]^2)
    )
    return CTModels.Building.build(pre)
end

const OCP = _build_ocp()
const OCP_CF = _build_control_free()
const OCP_2D = _build_ocp_2d()

function test_state_control_flows()
    Test.@testset "State control flows" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ── ClosedLoop from an OCP: g(x) = -x + (-x) = -2x ⇒ x(t) = x0·e^{-2t} ──

        Test.@testset "Integration: ClosedLoop OCP flow" begin
            f = Flows.Flow(OCP, Data.ClosedLoop(x -> -x); _opts()...)
            Test.@test f isa Flows.ControlledFlow
            t0, tf, x0 = 0.0, 1.0, 1.0
            # point-eval: no p0, returns the final state
            xf = f(t0, x0, tf)
            Test.@test xf isa Number
            Test.@test xf ≈ x0 * exp(-2 * tf) atol = 1e-6

            # trajectory: StateFlowTrajectory
            sol = f((t0, tf), x0)
            Test.@test sol isa Trajectories.StateFlowTrajectory
            x = Trajectories.state(sol)
            u = Trajectories.control(sol)
            Test.@test x(0.5) ≈ x0 * exp(-2 * 0.5) atol = 1e-6
            Test.@test u(0.5) ≈ -x0 * exp(-2 * 0.5) atol = 1e-6   # u = -x
            # objective ∫0.5u² = ∫0.5 x0² e^{-4t} = 0.5 x0² (1-e^{-4})/4
            Test.@test Trajectories.objective(sol) ≈ 0.5 * (1 - exp(-4)) / 4 atol = 1e-6
            Test.@test Integrators.successful(sol) == true
            Test.@test Integrators.status(sol) == :Success

            # §9: state/control accessors return the projection stored at construction,
            # so they rebuild nothing and allocate nothing. `control(sol)` goes through
            # the `_sft_control` dispatch indirection, which Julia < 1.11 doesn't fully
            # elide (compiler codegen difference, not a logic issue), so the strict
            # zero-alloc check on `control` only holds from 1.11 on.
            Trajectories.state(sol)
            Trajectories.control(sol)   # warm-up
            Test.@test (@allocated Trajectories.state(sol)) == 0
            if VERSION >= v"1.11"
                Test.@test (@allocated Trajectories.control(sol)) == 0
            end
        end

        Test.@testset "1-D scalar convention: vector x0 input → scalar output" begin
            f = Flows.Flow(OCP, Data.ClosedLoop(x -> -x); _opts()...)
            t0, tf, x0 = 0.0, 1.0, 1.0
            xf_scalar = f(t0, x0, tf)
            xf_vec = f(t0, [x0], tf)           # length-1 vector input
            Test.@test xf_vec isa Number        # must collapse to scalar
            Test.@test xf_vec ≈ xf_scalar atol = 1e-12
        end

        Test.@testset "n-D vector convention: 2-D state → vector output" begin
            f = Flows.Flow(OCP_2D, Data.ClosedLoop(x -> -x); _opts()...)
            t0, tf = 0.0, 1.0
            x0 = [1.0, 2.0]
            xf = f(t0, x0, tf)
            Test.@test xf isa AbstractVector && length(xf) == 2
            Test.@test xf ≈ x0 .* exp(-2 * tf) atol = 1e-6
        end

        Test.@testset "n-D vector trajectory: 2-D state → StateFlowTrajectory" begin
            f = Flows.Flow(OCP_2D, Data.ClosedLoop(x -> -x); _opts()...)
            t0, tf = 0.0, 1.0
            x0 = [1.0, 2.0]
            sol = f((t0, tf), x0)
            Test.@test sol isa Trajectories.StateFlowTrajectory
            x = Trajectories.state(sol)
            Test.@test x(0.5) isa AbstractVector && length(x(0.5)) == 2
            Test.@test x(0.5) ≈ x0 .* exp(-2 * 0.5) atol = 1e-6
        end

        # ── OpenLoop from an OCP: g(x) = -x + 1 ⇒ x(t) = 1 + (x0-1)e^{-t} ──────

        Test.@testset "Integration: OpenLoop OCP flow" begin
            f = Flows.Flow(OCP, Data.OpenLoop(t -> 1.0); _opts()...)
            t0, tf, x0 = 0.0, 1.0, 0.0
            xf = f(t0, x0, tf)
            Test.@test xf ≈ 1 + (x0 - 1) * exp(-tf) atol = 1e-6
            sol = f((t0, tf), x0)
            Test.@test Trajectories.control(sol)(0.5) ≈ 1.0   # constant control
        end

        # ── Flow(fc, law) directly (no OCP → no objective) ───────────────────

        Test.@testset "Integration: Flow(fc, law) direct" begin
            fc = Data.ControlledVectorField((x, u) -> -x + u)
            f = Flows.Flow(fc, Data.ClosedLoop(x -> -x); _opts()...)
            sol = f((0.0, 1.0), 1.0)
            Test.@test sol isa Trajectories.StateFlowTrajectory
            Test.@test Trajectories.state(sol)(0.5) ≈ exp(-2 * 0.5) atol = 1e-6
            # no OCP ⇒ objective errors clearly
            Test.@test_throws Exceptions.PreconditionError Trajectories.objective(sol)
        end

        # ── getter error: a controlled trajectory has no costate ─────────────

        Test.@testset "Error: costate on a StateFlowTrajectory" begin
            f = Flows.Flow(OCP, Data.ClosedLoop(x -> -x); _opts()...)
            sol = f((0.0, 1.0), 1.0)
            Test.@test_throws Exceptions.PreconditionError Trajectories.costate(sol)
        end

        # ── feedback / precondition errors ───────────────────────────────────

        Test.@testset "Error: DynClosedLoop into Flow(fc, law)" begin
            fc = Data.ControlledVectorField((x, u) -> -x + u)
            Test.@test_throws Exceptions.PreconditionError Flows.Flow(
                fc, Data.DynClosedLoop((x, p) -> -p); _opts()...
            )
        end

        Test.@testset "Error: control-free OCP with an OpenLoop law" begin
            Test.@test_throws Exceptions.PreconditionError Flows.Flow(
                OCP_CF, Data.OpenLoop(t -> 1.0); _opts()...
            )
        end
    end
end

end # module

test_state_control_flows() = TestStateControlFlows.test_state_control_flows()
