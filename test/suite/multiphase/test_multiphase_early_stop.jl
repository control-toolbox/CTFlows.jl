"""
A phase of a multi-phase flow that stops before its switching time (a `terminate!` callback,
issue #526) ends the flow: the following phases are not integrated, no jump is applied, the
trajectory stops at the stop time and the point call returns the state there.

Reference problems (x' = -x, x(0) = 1, x(t) = e⁻ᵗ), with a callback that stops at x = c, that
is at t = log(1/c); (x, p)' = (p, -x), (x, p)(0) = (1, 0), (x, p) = (cos t, -sin t), stopped
at x = c, that is at t = acos(c).
"""

module TestMultiphaseEarlyStop

using Test: Test
using CTBase: Data
using CTModels: CTModels
using CTFlows: Configs
using CTFlows: Flows
using CTFlows: Integrators
using CTFlows: MultiPhase
using CTFlows: Trajectories
using OrdinaryDiffEqTsit5: Tsit5
using SciMLBase: ContinuousCallback, terminate!
using ForwardDiff: ForwardDiff  # triggers the DI ForwardDiff extension (AutoForwardDiff)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const TOL = 1e-8
const NDEFAULT = 250

_tol() = (; alg=Tsit5(), reltol=1e-10, abstol=1e-10)
_val(a) = a isa Number ? a : a[1]
_stop_at(c) = ContinuousCallback((u, t, int) -> u[1] - c, terminate!)

# plain flows
_decay(; kw...) = Flows.Flow(Data.VectorField(x -> -x); _tol()..., kw...)
_decay_stopping(c) = _decay(; callback=_stop_at(c))
_osc(; kw...) = Flows.Flow(Data.HamiltonianVectorField((x, p) -> (p, -x)); _tol()..., kw...)
_osc_stopping(c) = _osc(; callback=_stop_at(c))

# double integrator ẋ = (x₂, u) with u = 6 - 12t: x₁(t) = -1 + 3t² - 2t³, increasing from -1 to 0
function _di_ocp()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=x[2]; r[2]=u; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    return CTModels.Building.build(pre)
end
const OCP = _di_ocp()
const X0, P0 = [-1.0, 0.0], [12.0, 6.0]
const LAW_S = Data.OpenLoop(t -> 6 - 12t)
const LAW_H = Data.DynClosedLoop((x, p) -> p[2])
_x1(t) = -1 + 3t^2 - 2t^3
_ocp_s(; kw...) = Flows.Flow(OCP, LAW_S; _tol()..., kw...)
_ocp_h(; kw...) = Flows.Flow(OCP, LAW_H; hamiltonian_type=:partial, _tol()..., kw...)

# time at which x₁ reaches c, by bisection on the increasing part of x₁ over [0, 1]
function _t_of_x1(c)
    lo, hi = 0.0, 1.0
    for _ in 1:80
        mid = (lo + hi) / 2
        _x1(mid) < c ? (lo = mid) : (hi = mid)
    end
    return (lo + hi) / 2
end

function test_multiphase_early_stop()
    Test.@testset "Multi-phase early stop (issue #526)" verbose = VERBOSE showtiming =
        SHOWTIMING begin

        # ── UNIT: _reached_end ──────────────────────────────────────────────
        Test.@testset "_reached_end: forward" begin
            Test.@test MultiPhase._reached_end(1.0, 0.0, 1.0)
            Test.@test MultiPhase._reached_end(1.0 + 1e-12, 0.0, 1.0)
            Test.@test !MultiPhase._reached_end(0.999, 0.0, 1.0)
            Test.@test !MultiPhase._reached_end(0.0, 0.0, 1.0)
        end

        Test.@testset "_reached_end: backward" begin
            Test.@test MultiPhase._reached_end(0.0, 1.0, 0.0)
            Test.@test MultiPhase._reached_end(-1e-12, 1.0, 0.0)
            Test.@test !MultiPhase._reached_end(0.001, 1.0, 0.0)
        end

        Test.@testset "_reached_end: an empty phase has reached its end" begin
            Test.@test MultiPhase._reached_end(0.5, 0.5, 0.5)
        end

        Test.@testset "_reached_end: a dual time is read as its primal value" begin
            d = ForwardDiff.Dual(0.4, 1.0)
            Test.@test !MultiPhase._reached_end(d, 0.0, 1.0)
            Test.@test MultiPhase._reached_end(ForwardDiff.Dual(1.0, 1.0), 0.0, 1.0)
        end

        # ── UNIT: _truncate ─────────────────────────────────────────────────
        Test.@testset "_truncate: the first phases, switching times and jumps" begin
            f = _decay()
            mpf = f * (0.3, [1.0], f) * (0.6, [2.0], f)
            Test.@test MultiPhase.n_phases(mpf) == 3
            Test.@test MultiPhase._truncate(mpf, 3) === mpf
            t2 = MultiPhase._truncate(mpf, 2)
            Test.@test MultiPhase.n_phases(t2) == 2
            Test.@test MultiPhase.get_switching_times(t2) == [0.3]
            Test.@test MultiPhase.get_jump(t2, 1) == [1.0]
            t1 = MultiPhase._truncate(mpf, 1)
            Test.@test MultiPhase.n_phases(t1) == 1
            Test.@test isempty(MultiPhase.get_switching_times(t1))
        end

        Test.@testset "_truncate keeps the kind of the flow" begin
            h = _osc()
            hmpf = h * (0.3, h) * (0.6, h)
            Test.@test MultiPhase._truncate(hmpf, 2) isa
                MultiPhase.MultiPhaseHamiltonianFlow
            f = _decay()
            Test.@test MultiPhase._truncate(f * (0.3, f) * (0.6, f), 2) isa
                MultiPhase.MultiPhaseStateFlow
        end

        # ── INTEGRATION: trajectory call, plain state flow ──────────────────
        Test.@testset "stop in the first of two phases" begin
            mpf = _decay_stopping(0.8) * (0.5, _decay())
            traj = mpf((0.0, 1.0), [1.0]; grid=nothing)
            T = Integrators.times(traj)
            Test.@test first(T) == 0.0
            Test.@test last(T) ≈ log(1 / 0.8) atol = TOL
            Test.@test all(<(0.5), T)                         # no time of the second phase
            Test.@test Trajectories.switching_times(traj) == []
            Test.@test only(traj(last(T))) ≈ 0.8 atol = TOL
            Test.@test only(traj(0.1)) ≈ exp(-0.1) atol = TOL
        end

        Test.@testset "stop in the first of two phases: default grid ends at the stop" begin
            mpf = _decay_stopping(0.8) * (0.5, _decay())
            T = Integrators.times(mpf((0.0, 1.0), [1.0]))
            Test.@test length(T) == NDEFAULT
            Test.@test first(T) == 0.0
            Test.@test last(T) ≈ log(1 / 0.8) atol = TOL
            Test.@test allunique(T) && issorted(T)
        end

        Test.@testset "stop in the first of two phases: explicit grid" begin
            mpf = _decay_stopping(0.8) * (0.5, _decay())
            T = Integrators.times(mpf((0.0, 1.0), [1.0]; grid=20))
            Test.@test length(T) == 20
            Test.@test last(T) ≈ log(1 / 0.8) atol = TOL
        end

        Test.@testset "stop in the second of three phases: the first switching time is kept" begin
            f = _decay()
            mpf = f * (0.3, _decay_stopping(0.6)) * (0.8, f)   # stops at log(1/0.6) ≈ 0.511
            traj = mpf((0.0, 1.0), [1.0]; grid=nothing)
            T = Integrators.times(traj)
            Test.@test last(T) ≈ log(1 / 0.6) atol = TOL
            Test.@test 0.3 in T
            Test.@test Trajectories.switching_times(traj) == [0.3]
            Test.@test only(traj(last(T))) ≈ 0.6 atol = TOL
        end

        Test.@testset "stop in the last phase" begin
            f = _decay()
            mpf = f * (0.3, _decay_stopping(0.6))
            traj = mpf((0.0, 1.0), [1.0]; grid=nothing)
            T = Integrators.times(traj)
            Test.@test last(T) ≈ log(1 / 0.6) atol = TOL
            Test.@test Trajectories.switching_times(traj) == [0.3]
            Test.@test only(traj(last(T))) ≈ 0.6 atol = TOL
        end

        Test.@testset "no stop: the flow is unchanged" begin
            f = _decay()
            mpf = _decay_stopping(1e-3) * (0.5, f)    # the callback is never reached on [0, 0.5]
            traj = mpf((0.0, 1.0), [1.0]; grid=nothing)
            T = Integrators.times(traj)
            Test.@test last(T) == 1.0
            Test.@test 0.5 in T
            Test.@test only(traj(1.0)) ≈ exp(-1) atol = TOL
            Test.@test only(traj(0.5)) ≈ exp(-0.5) atol = TOL
        end

        Test.@testset "a stop exactly at the end of the phase is not an early stop" begin
            # x' = -x reaches e⁻⁰·⁵ at the switching time: the callback is on its boundary
            mpf = _decay_stopping(exp(-0.5)) * (0.5, _decay())
            traj = mpf((0.0, 1.0), [1.0]; grid=nothing)
            Test.@test last(Integrators.times(traj)) ≥ 0.5 - 1e-6
        end

        Test.@testset "no jump is applied after an early stop" begin
            mpf = _decay_stopping(0.8) * (0.5, [10.0], _decay())
            traj = mpf((0.0, 1.0), [1.0]; grid=nothing)
            Test.@test only(traj(last(Integrators.times(traj)))) ≈ 0.8 atol = TOL
            Test.@test maximum(only.(traj.(Integrators.times(traj)))) ≤ 1.0 + TOL
            # without the stop the jump is applied
            full = (_decay() * (0.5, [10.0], _decay()))((0.0, 1.0), [1.0]; grid=nothing)
            Test.@test only(full(1.0)) ≈ (exp(-0.5) + 10) * exp(-0.5) atol = TOL
        end

        Test.@testset "backward integration" begin
            # x(1) = 1, backward: x(t) = e^{1-t}, reaching 1.5 at t = 1 - log(1.5) ≈ 0.595 > 0.5
            mpf = _decay_stopping(1.5) * (0.5, _decay())
            traj = mpf((1.0, 0.0), [1.0]; grid=nothing)
            T = Integrators.times(traj)
            Test.@test first(T) == 1.0
            Test.@test last(T) ≈ 1 - log(1.5) atol = TOL
            Test.@test all(>(0.5), T)
            Test.@test only(traj(last(T))) ≈ 1.5 atol = TOL
        end

        Test.@testset "backward integration: default grid ends at the stop" begin
            mpf = _decay_stopping(1.5) * (0.5, _decay())
            T = Integrators.times(mpf((1.0, 0.0), [1.0]))
            Test.@test length(T) == NDEFAULT
            Test.@test first(T) == 1.0
            Test.@test last(T) ≈ 1 - log(1.5) atol = TOL
            Test.@test issorted(T; rev=true)
        end

        Test.@testset "phase labels follow the phases that were integrated" begin
            f = _decay()
            a = Flows.Flow(
                Data.VectorField(x -> -x); callback=_stop_at(0.8), _tol()..., label="a"
            )
            b = Flows.Flow(Data.VectorField(x -> -x); _tol()..., label="b")
            traj = (a * (0.5, b))((0.0, 1.0), [1.0]; grid=nothing)
            Test.@test Trajectories.phase_labels(traj) == ["a"]
            traj = (f * (0.2, a) * (0.8, b))((0.0, 1.0), [1.0]; grid=nothing)
            Test.@test length(Trajectories.phase_labels(traj)) == 2
        end

        # ── INTEGRATION: trajectory call, plain Hamiltonian flow ────────────
        Test.@testset "Hamiltonian: stop in the first of two phases" begin
            mpf = _osc_stopping(0.5) * (1.2, _osc())      # stops at acos(0.5) = π/3 < 1.2
            traj = mpf((0.0, 2.0), 1.0, 0.0; grid=nothing)
            T = Integrators.times(traj)
            Test.@test last(T) ≈ acos(0.5) atol = TOL
            Test.@test all(<(1.2), T)
            Test.@test _val(Trajectories.state(traj)(last(T))) ≈ 0.5 atol = TOL
            Test.@test _val(Trajectories.costate(traj)(last(T))) ≈ -sin(acos(0.5)) atol =
                TOL
            default = Integrators.times(mpf((0.0, 2.0), 1.0, 0.0))
            Test.@test length(default) == NDEFAULT
            Test.@test last(default) ≈ acos(0.5) atol = TOL
        end

        # ── INTEGRATION: trajectory call, flows with a control law ──────────
        Test.@testset "Flow(ocp, OpenLoop): stop in the first of two phases" begin
            t_stop = _t_of_x1(-0.8)                       # < 0.5
            Test.@test t_stop < 0.5
            mpf = _ocp_s(; callback=_stop_at(-0.8)) * (0.5, _ocp_s())
            sol = mpf((0.0, 1.0), X0)
            T = CTModels.time_grid(sol)
            Test.@test length(T) == NDEFAULT
            Test.@test first(T) == 0.0
            Test.@test last(T) ≈ t_stop atol = 1e-6
            Test.@test _val(Trajectories.state(sol)(last(T))[1]) ≈ -0.8 atol = 1e-6
        end

        Test.@testset "Flow(ocp, DynClosedLoop): stop in the first of two phases" begin
            t_stop = _t_of_x1(-0.8)
            mpf = _ocp_h(; callback=_stop_at(-0.8)) * (0.5, _ocp_h())
            sol = mpf((0.0, 1.0), X0, P0)
            T = CTModels.time_grid(sol)
            Test.@test length(T) == NDEFAULT
            Test.@test last(T) ≈ t_stop atol = 1e-6
            Test.@test CTModels.state(sol)(last(T))[1] ≈ -0.8 atol = 1e-6
        end

        Test.@testset "Flow(ocp, DynClosedLoop): stop in the second of three phases" begin
            f = _ocp_h()
            t_stop = _t_of_x1(-0.3)                       # > 0.5
            Test.@test 0.5 < t_stop < 0.8
            mpf = f * (0.5, _ocp_h(; callback=_stop_at(-0.3))) * (0.8, f)
            sol = mpf((0.0, 1.0), X0, P0)
            T = CTModels.time_grid(sol)
            Test.@test last(T) ≈ t_stop atol = 1e-6
            Test.@test 0.5 in T
            Test.@test CTModels.state(sol)(last(T))[1] ≈ -0.3 atol = 1e-6
        end

        # ── INTEGRATION: point call ─────────────────────────────────────────
        Test.@testset "point call: stop in the first of two phases" begin
            mpf = _decay_stopping(0.8) * (0.5, _decay())
            Test.@test only(mpf(0.0, [1.0], 1.0)) ≈ 0.8 atol = TOL
        end

        Test.@testset "point call: stop in the second of three phases" begin
            f = _decay()
            mpf = f * (0.3, _decay_stopping(0.6)) * (0.8, f)
            Test.@test only(mpf(0.0, [1.0], 1.0)) ≈ 0.6 atol = TOL
        end

        Test.@testset "point call: no jump after an early stop" begin
            mpf = _decay_stopping(0.8) * (0.5, [10.0], _decay())
            Test.@test only(mpf(0.0, [1.0], 1.0)) ≈ 0.8 atol = TOL
        end

        Test.@testset "point call: backward" begin
            mpf = _decay_stopping(1.5) * (0.5, _decay())
            Test.@test only(mpf(1.0, [1.0], 0.0)) ≈ 1.5 atol = TOL
        end

        Test.@testset "point call: no stop" begin
            f = _decay()
            mpf = f * (0.5, [10.0], f)
            Test.@test only(mpf(0.0, [1.0], 1.0)) ≈ (exp(-0.5) + 10) * exp(-0.5) atol = TOL
        end

        Test.@testset "point call: Hamiltonian flow" begin
            mpf = _osc_stopping(0.5) * (1.2, _osc())
            xf, pf = mpf(0.0, 1.0, 0.0, 2.0)
            Test.@test _val(xf) ≈ 0.5 atol = TOL
            Test.@test _val(pf) ≈ -sin(acos(0.5)) atol = TOL
            xf, pf = (_osc() * (1.2, _osc()))(0.0, 1.0, 0.0, 2.0)
            Test.@test _val(xf) ≈ cos(2.0) atol = TOL
            Test.@test _val(pf) ≈ -sin(2.0) atol = TOL
        end

        Test.@testset "point call: agrees with the end of the trajectory" begin
            mpf = _decay_stopping(0.8) * (0.5, _decay())
            traj = mpf((0.0, 1.0), [1.0]; grid=nothing)
            Test.@test only(mpf(0.0, [1.0], 1.0)) ≈
                only(traj(last(Integrators.times(traj)))) atol = TOL
        end

        Test.@testset "point call: ForwardDiff through the phases" begin
            f = _decay()
            mpf = _decay_stopping(1e-3) * (0.5, f)
            d = ForwardDiff.derivative(a -> only(mpf(0.0, [a], 1.0)), 1.0)
            Test.@test d ≈ exp(-1) atol = TOL
        end

        Test.@testset "point call: variable-dependent flows keep the variable check" begin
            g = Flows.Flow(
                Data.VectorField((x, v) -> -v .* x; is_autonomous=true, is_variable=true);
                _tol()...,
            )
            mpf = g * (0.5, g)
            Test.@test only(mpf(0.0, [1.0], 1.0; variable=2.0)) ≈ exp(-2.0) atol = TOL
        end
    end
end

end # module

test_multiphase_early_stop() = TestMultiphaseEarlyStop.test_multiphase_early_stop()
