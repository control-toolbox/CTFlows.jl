"""
The names of the accessors of a flow (issue #544): no `get_` prefix, and one function per
notion for a flow, its trajectory and a `CTModels.Solution` — `switching_times`,
`phase_labels`, `has_switching`, `left_limit` and `right_limit` are the functions of
`CTModels.Solutions`. The removed names throw a `PreconditionError` naming their replacement.
"""
module TestAccessorNames

using Test: Test
using CTBase: Data
using CTBase: Exceptions
using CTModels: CTModels
using CTFlows: Flows
using CTFlows: MultiPhase
using CTFlows: Systems
using CTFlows: Trajectories
using OrdinaryDiffEqTsit5: Tsit5
using ForwardDiff: ForwardDiff  # triggers the DI ForwardDiff extension (AutoForwardDiff)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

_opts() = (; alg=Tsit5(), reltol=1e-12, abstol=1e-12)

# ẋ = -x + u, ℓ = u²/2 (1-D, for Hamiltonian flows with a law u = ±p).
function _lqr()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=(-x + u); nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    return CTModels.Building.build(pre)
end

# ẋ = u, ℓ = u²/2 (1-D, for controlled state flows with open-loop laws).
function _integrator()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=u; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    return CTModels.Building.build(pre)
end

const LQR = _lqr()
const INT = _integrator()

_plus(; label="") = Flows.Flow(LQR, (x, p) -> p; label=label, _opts()...)
_minus(; label="") = Flows.Flow(LQR, (x, p) -> -p; label=label, _opts()...)
_bang(u; label="") = Flows.Flow(INT, Data.OpenLoop(t -> u); label=label, _opts()...)

function _message(f)
    try
        f()
    catch e
        return e
    end
    return nothing
end

function test_accessor_names()
    Test.@testset "Accessor names" verbose = VERBOSE showtiming = SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - one function per notion
        # ====================================================================

        Test.@testset "Unit: the switching functions are those of CTModels.Solutions" begin
            S = CTModels.Solutions
            Test.@test Trajectories.switching_times === S.switching_times
            Test.@test Trajectories.phase_labels === S.phase_labels
            Test.@test Trajectories.has_switching === S.has_switching
            Test.@test Trajectories.left_limit === S.left_limit
            Test.@test Trajectories.right_limit === S.right_limit
            Test.@test MultiPhase.switching_times === S.switching_times
            Test.@test MultiPhase.phase_labels === S.phase_labels
        end

        # ====================================================================
        # INTEGRATION - flows, trajectories, solutions
        # ====================================================================

        Test.@testset "Integration: a single flow" begin
            f = _plus(; label="plus")
            Test.@test MultiPhase.n_phases(f) == 1
            Test.@test MultiPhase.phase_flows(f) == (f,)
            Test.@test isempty(MultiPhase.switching_times(f))
            Test.@test isempty(MultiPhase.jumps(f))
            Test.@test MultiPhase.phase_labels(f) == ["plus"]
        end

        Test.@testset "Integration: a multi-phase flow and its solution" begin
            f1, f2 = _plus(; label="plus"), _minus(; label="minus")
            f = f1 * (0.5, [1.0], f2)
            Test.@test MultiPhase.n_phases(f) == 2
            Test.@test MultiPhase.phase_flows(f)[1] === f1
            Test.@test MultiPhase.phase_flows(f)[2] === f2
            Test.@test MultiPhase.switching_times(f) == [0.5]
            Test.@test MultiPhase.jumps(f)[1] == [1.0]
            Test.@test MultiPhase.phase_labels(f) == ["plus", "minus"]
            # the same functions read the solution of the flow
            sol = f((0.0, 1.0), 1.0, 0.5)
            Test.@test sol isa CTModels.Solutions.Solution
            Test.@test MultiPhase.switching_times(sol) == [0.5]
            Test.@test MultiPhase.phase_labels(sol) == ["plus", "minus"]
            Test.@test CTModels.Solutions.has_switching(sol)
        end

        Test.@testset "Integration: the trajectory of a state flow" begin
            # a state flow returns its own trajectory type, not a Solution: the functions of
            # CTModels.Solutions read it all the same (a MethodError before #544)
            f = _bang(1.0; label="up") * (0.5, _bang(-1.0; label="down"))
            traj = f((0.0, 1.0), 0.0)
            Test.@test traj isa Trajectories.StateFlowTrajectory
            S = CTModels.Solutions
            Test.@test S.switching_times(traj) == [0.5]
            Test.@test S.phase_labels(traj) == ["up", "down"]
            Test.@test S.has_switching(traj)
            Test.@test S.left_limit(traj, :control, 1) ≈ 1.0
            Test.@test S.right_limit(traj, :control, 1) ≈ -1.0
            Test.@test S.left_limit(traj, :state, 1) ≈ 0.5
            # a single phase has none
            single = _bang(1.0)((0.0, 1.0), 0.0)
            Test.@test !S.has_switching(single)
            Test.@test isempty(S.switching_times(single))
        end

        Test.@testset "Integration: the gradients of a flow" begin
            f = _plus()
            x, p = 1.0, 0.5
            ∇H = Systems.hamiltonian_gradient(f)
            ∇Hp = Systems.pseudo_hamiltonian_gradient(f)
            # H(x, p) = p(-x + p) - p²/2 = -px + p²/2: ∇ₓH = -p, ∇ₚH = -x + p
            Test.@test all(∇H(x, p) .≈ (-p, -x + p))
            # H(x, p, u) = p(-x + u) - u²/2 at u = p: the same partial derivatives
            Test.@test all(∇Hp(x, p, p) .≈ (-p, -x + p))
        end

        # ====================================================================
        # ERROR paths - the removed names
        # ====================================================================

        Test.@testset "Error: the removed multi-phase accessors name their replacement" begin
            f = _plus() * (0.5, _minus())
            for (old, call, new) in (
                (:get_flow, () -> MultiPhase.get_flow(f, 1), "phase_flows(f)[i]"),
                (
                    :get_switching_time,
                    () -> MultiPhase.get_switching_time(f, 1),
                    "switching_times(f)[i]",
                ),
                (:get_jump, () -> MultiPhase.get_jump(f, 1), "jumps(f)[i]"),
                (:get_flows, () -> MultiPhase.get_flows(f), "phase_flows(f)"),
                (
                    :get_switching_times,
                    () -> MultiPhase.get_switching_times(f),
                    "switching_times(f)",
                ),
                (:get_jumps, () -> MultiPhase.get_jumps(f), "jumps(f)"),
                (:get_labels, () -> MultiPhase.get_labels(f), "phase_labels(f)"),
            )
                err = _message(call)
                Test.@test err isa Exceptions.PreconditionError
                Test.@test occursin(string(old), err.msg)
                Test.@test occursin(new, err.suggestion)
            end
        end

        Test.@testset "Error: the removed gradient accessors name their replacement" begin
            f = _plus()
            for (old, new) in (
                (Systems.get_hamiltonian_gradient, "hamiltonian_gradient"),
                (Systems.get_variable_gradient, "variable_gradient"),
                (Systems.get_pseudo_hamiltonian_gradient, "pseudo_hamiltonian_gradient"),
                (Systems.get_pseudo_variable_gradient, "pseudo_variable_gradient"),
            )
                err = _message(() -> old(f))
                Test.@test err isa Exceptions.PreconditionError
                Test.@test occursin("use $new(f)", err.suggestion)
            end
        end
    end
end

end # module

test_accessor_names() = TestAccessorNames.test_accessor_names()
