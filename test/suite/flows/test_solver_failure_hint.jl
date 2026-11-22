"""
A `SolverFailure` raised by the integration of a flow call with `unsafe=false` is raised
again with the context of the call and a suggestion that names `unsafe=true` (issue #523);
for a multi-phase flow, the context also names the phase.

Reference problem: x' = x², x(0) = 1, x(t) = 1 / (1 - t), which blows up at t = 1; it is
integrated up to t = 10, so the integration fails.
"""

module TestSolverFailureHint

using Test: Test
using CTBase: Data
using CTBase: Exceptions
using CTFlows: CTFlows
using CTFlows: Configs
using CTFlows: Flows
using CTFlows: Integrators
using CTFlows: MultiPhase
using CTFlows: Trajectories
using SciMLBase: ODEProblem, ODEFunction
using OrdinaryDiffEqTsit5: Tsit5
using ForwardDiff: ForwardDiff  # triggers the DI ForwardDiff extension (AutoForwardDiff)

const CTFlowsSciMLFlows = Base.get_extension(CTFlows, :CTFlowsSciMLFlows)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ── fixtures (module top-level) ─────────────────────────────────────────────

const HINT = "call the flow with `unsafe=true`"
const FAILURE = Exceptions.SolverFailure(
    "ODE integration failed";
    retcode="Unstable",
    suggestion="Try tightening tolerances.",
    context="SciML solve",
)
const POINT = Configs.StateEndPointConfig(0.0, [1.0], 1.0)
const TRAJECTORY = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0])

_tol() = (; alg=Tsit5(), reltol=1e-8, abstol=1e-8)
_blowup() = Flows.Flow(Data.VectorField(x -> x .^ 2); _tol()...)
function _hblowup()
    return Flows.Flow(
        Data.HamiltonianVectorField((x, p) -> (x .^ 2, -2 .* x .* p)); _tol()...
    )
end
_decay() = Flows.Flow(Data.VectorField(x -> -x); _tol()...)
function _problem_flow()
    prob = ODEProblem(ODEFunction((du, u, p, t) -> du .= u .^ 2), [1.0], (0.0, 10.0))
    return CTFlowsSciMLFlows.SciMLProblemFlow(prob, Integrators.SciML())
end

# the exception raised by `f()`, or `nothing`
function _caught(f)
    try
        f()
    catch e
        return e
    end
    return nothing
end

_throw_failure() = throw(FAILURE)
_throw_other() = throw(ArgumentError("not a solver failure"))

function test_solver_failure_hint()
    Test.@testset "SolverFailure from a flow call (issue #523)" verbose = VERBOSE showtiming =
        SHOWTIMING begin

        # ── UNIT: _unsafe_failure ───────────────────────────────────────────
        Test.@testset "_unsafe_failure: point call" begin
            e = Flows._unsafe_failure(FAILURE, POINT)
            Test.@test e isa Exceptions.SolverFailure
            Test.@test e.msg == FAILURE.msg
            Test.@test e.retcode == "Unstable"
            Test.@test e.context == "point call of the flow (SciML solve)"
            Test.@test startswith(e.suggestion, "Try tightening tolerances. ")
            Test.@test occursin("the state reached at the failure", e.suggestion)
            Test.@test occursin(HINT, e.suggestion)
        end

        Test.@testset "_unsafe_failure: trajectory call" begin
            e = Flows._unsafe_failure(FAILURE, TRAJECTORY)
            Test.@test e.context == "trajectory call of the flow (SciML solve)"
            Test.@test occursin("the trajectory computed up to the failure", e.suggestion)
        end

        Test.@testset "_unsafe_failure: call without configuration" begin
            e = Flows._unsafe_failure(FAILURE, nothing)
            Test.@test e.context == "call of the flow (SciML solve)"
            Test.@test occursin("the trajectory computed up to the failure", e.suggestion)
        end

        Test.@testset "_unsafe_failure: no suggestion and no context" begin
            e = Flows._unsafe_failure(Exceptions.SolverFailure("failed"), POINT)
            Test.@test e.retcode === nothing
            Test.@test e.context == "point call of the flow"
            Test.@test startswith(e.suggestion, "To get the state reached")
        end

        # ── UNIT: _with_unsafe_hint ─────────────────────────────────────────
        Test.@testset "_with_unsafe_hint: returns the value of a successful solve" begin
            Test.@test Flows._with_unsafe_hint(() -> 42, POINT, false) == 42
            Test.@test Flows._with_unsafe_hint(() -> 42, POINT, true) == 42
        end

        Test.@testset "_with_unsafe_hint: a SolverFailure names unsafe=true" begin
            e = _caught(() -> Flows._with_unsafe_hint(_throw_failure, POINT, false))
            Test.@test e isa Exceptions.SolverFailure
            Test.@test occursin(HINT, e.suggestion)
        end

        Test.@testset "_with_unsafe_hint: unchanged with unsafe=true" begin
            e = _caught(() -> Flows._with_unsafe_hint(_throw_failure, POINT, true))
            Test.@test e === FAILURE
        end

        Test.@testset "_with_unsafe_hint: any other exception is rethrown unchanged" begin
            Test.@test_throws ArgumentError Flows._with_unsafe_hint(
                _throw_other, POINT, false
            )
        end

        # ── UNIT: _in_phase ─────────────────────────────────────────────────
        Test.@testset "_in_phase: the phase is added to the context" begin
            e = _caught(() -> MultiPhase._in_phase(_throw_failure, 2, 3, false))
            Test.@test e isa Exceptions.SolverFailure
            Test.@test e.context == "phase 2 of 3, SciML solve"
            Test.@test e.msg == FAILURE.msg
            Test.@test e.retcode == FAILURE.retcode
            Test.@test e.suggestion == FAILURE.suggestion
        end

        Test.@testset "_in_phase: no context" begin
            failure() = throw(Exceptions.SolverFailure("failed"))
            e = _caught(() -> MultiPhase._in_phase(failure, 1, 2, false))
            Test.@test e.context == "phase 1 of 2"
        end

        Test.@testset "_in_phase: unchanged with unsafe=true, other exceptions rethrown" begin
            Test.@test MultiPhase._in_phase(() -> 42, 1, 2, false) == 42
            Test.@test _caught(() -> MultiPhase._in_phase(_throw_failure, 1, 2, true)) ===
                FAILURE
            Test.@test_throws ArgumentError MultiPhase._in_phase(_throw_other, 1, 2, false)
        end

        # ── INTEGRATION: single-phase calls ─────────────────────────────────
        Test.@testset "StateFlow point call" begin
            f = _blowup()
            Test.@test_throws Exceptions.SolverFailure f(0.0, [1.0], 10.0)
            e = _caught(() -> f(0.0, [1.0], 10.0))
            Test.@test e.retcode !== nothing
            Test.@test startswith(e.context, "point call of the flow")
            Test.@test occursin(HINT, e.suggestion)
            xf = f(0.0, [1.0], 10.0; unsafe=true)
            Test.@test only(xf) > 1e3
        end

        Test.@testset "StateFlow trajectory call" begin
            f = _blowup()
            Test.@test_throws Exceptions.SolverFailure f((0.0, 10.0), [1.0])
            e = _caught(() -> f((0.0, 10.0), [1.0]))
            Test.@test startswith(e.context, "trajectory call of the flow")
            Test.@test occursin("the trajectory computed up to the failure", e.suggestion)
            traj = f((0.0, 10.0), [1.0]; unsafe=true)
            Test.@test Trajectories.time_grid(traj)[end] ≈ 1.0 atol = 1e-3  # the blow-up time
        end

        Test.@testset "HamiltonianFlow point and trajectory calls" begin
            h = _hblowup()
            e = _caught(() -> h(0.0, [1.0], [1.0], 10.0))
            Test.@test e isa Exceptions.SolverFailure
            Test.@test startswith(e.context, "point call of the flow")
            Test.@test occursin(HINT, e.suggestion)
            e = _caught(() -> h((0.0, 10.0), [1.0], [1.0]))
            Test.@test e isa Exceptions.SolverFailure
            Test.@test startswith(e.context, "trajectory call of the flow")
        end

        Test.@testset "SciMLProblemFlow calls" begin
            f = _problem_flow()
            e = _caught(() -> f())
            Test.@test e isa Exceptions.SolverFailure
            Test.@test startswith(e.context, "call of the flow")
            Test.@test occursin(HINT, e.suggestion)
            e = _caught(() -> f(0.0, [1.0], 10.0))
            Test.@test startswith(e.context, "point call of the flow")
            e = _caught(() -> f((0.0, 10.0), [1.0]))
            Test.@test startswith(e.context, "trajectory call of the flow")
            Test.@test f(0.0, [1.0], 10.0; unsafe=true) isa Vector
        end

        # ── INTEGRATION: multi-phase calls ──────────────────────────────────
        Test.@testset "multi-phase point call: the failing phase is named" begin
            mpf = _decay() * (0.5, _blowup())
            e = _caught(() -> mpf(0.0, [1.0], 10.0))
            Test.@test e isa Exceptions.SolverFailure
            Test.@test startswith(e.context, "phase 2 of 2, point call of the flow")
            Test.@test count(HINT, e.suggestion) == 1
            Test.@test only(mpf(0.0, [1.0], 10.0; unsafe=true)) > 1e3
        end

        Test.@testset "multi-phase trajectory call: the failing phase is named" begin
            mpf = _blowup() * (5.0, _decay()) * (8.0, _decay())
            e = _caught(() -> mpf((0.0, 10.0), [1.0]))
            Test.@test e isa Exceptions.SolverFailure
            Test.@test startswith(e.context, "phase 1 of 3, trajectory call of the flow")
            Test.@test count(HINT, e.suggestion) == 1
            traj = mpf((0.0, 10.0), [1.0]; unsafe=true)
            Test.@test Trajectories.time_grid(traj)[end] ≈ 1.0 atol = 1e-3  # the blow-up time
        end
    end
end

end # module

test_solver_failure_hint() = TestSolverFailureHint.test_solver_failure_hint()
