"""
End-to-end tests of the default output grid (issue #446): a top-level trajectory call that
sets no output grid returns an `AdaptiveGrid(250)` when the solver returns fewer than 250
times, for every kind of flow (single- and multi-phase), without changing the integration
(values and objective at solver accuracy). It is not generated with `saveat`, a grid of
times, `grid=`, `dense=false`, `grid=nothing`, a point call, or a `SciMLProblemFlow`.

Problems with an exact solution (double integrator ẋ = (x₂, u), x(0) = (-1, 0)):
u = p₂ with p(0) = (12, 6) ⇒ u = 6 - 12t, x = (-1 + 3t² - 2t³, 6t - 6t²), p = (12, 6 - 12t).
"""

module TestDefaultGridCalls

using Test: Test
using CTBase: Data
using CTBase: Exceptions
using CTModels: CTModels
using CTFlows: CTFlows
using CTFlows: Configs
using CTFlows: Flows
using CTFlows: Integrators
using CTFlows: Trajectories
using OrdinaryDiffEqTsit5: Tsit5
using SciMLBase: SciMLBase, ODEProblem
using ForwardDiff: ForwardDiff  # triggers the DI ForwardDiff extension (AutoForwardDiff)

const CTFlowsSciMLFlows = Base.get_extension(CTFlows, :CTFlowsSciMLFlows)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const TOL = 1e-8
const NDEFAULT = 250   # the grid_size of the solutions of the direct methods

_tol() = (; alg=Tsit5(), reltol=1e-10, abstol=1e-10)
_val(a) = a isa Number ? a : a[1]
_x(t) = [-1 + 3t^2 - 2t^3, 6t - 6t^2]
_p(t) = [12.0, 6 - 12t]
_u(t) = 6 - 12t
const X0, P0 = [-1.0, 0.0], [12.0, 6.0]
const OFF_GRID = (0.013, 0.2718, 0.5, 0.7311, 0.99)

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
const LAW_H = Data.DynClosedLoop((x, p) -> p[2])
const LAW_S = Data.OpenLoop(t -> 6 - 12t)

_flow_h(; kw...) = Flows.Flow(OCP, LAW_H; hamiltonian_type=:partial, _tol()..., kw...)
_flow_s(; kw...) = Flows.Flow(OCP, LAW_S; _tol()..., kw...)
_flow_c(; kw...) = Flows.Flow(OCP, Data.ClosedLoop(x -> 0.0); _tol()..., kw...)
_plain_s(; kw...) = Flows.Flow(Data.VectorField(x -> [x[2], -x[1]]); _tol()..., kw...)
_plain_h(; kw...) =
    Flows.Flow(Data.HamiltonianVectorField((x, p) -> (p, -x)); _tol()..., kw...)

# 250 distinct times, sorted, bounds included once
function _check_default(T, bounds)
    Test.@test length(T) == NDEFAULT
    Test.@test allunique(T)
    Test.@test issorted(last(bounds) > first(bounds) ? T : reverse(T); lt=<)
    Test.@test first(T) == first(bounds) && last(T) == last(bounds)
    for b in bounds
        Test.@test count(==(b), T) == 1
    end
end

_no_warning(f) = Test.@test_logs min_level = Base.CoreLogging.Warn f()

function test_default_grid_calls()
    Test.@testset "default output grid (issue #446)" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ── every kind of flow gets the default grid ─────────────────────────
        Test.@testset "Flow(ocp, DynClosedLoop) → Solution" begin
            f = _flow_h()
            sol = _no_warning(() -> f((0.0, 1.0), X0, P0))
            T = CTModels.time_grid(sol)
            _check_default(T, [0.0, 1.0])
            x, p, u = CTModels.state(sol), CTModels.costate(sol), CTModels.control(sol)
            for t in T
                Test.@test x(t) ≈ _x(t) atol = TOL
                Test.@test p(t) ≈ _p(t) atol = TOL
                Test.@test _val(u(t)) ≈ _u(t) atol = TOL
            end
            Test.@test CTModels.objective(sol) ≈ 6.0 atol = TOL
        end

        Test.@testset "Flow(ocp, OpenLoop) → StateFlowTrajectory" begin
            f = _flow_s()
            sol = _no_warning(() -> f((0.0, 1.0), X0))
            _check_default(CTModels.time_grid(sol), [0.0, 1.0])
            x, u = Trajectories.state(sol), Trajectories.control(sol)
            for t in CTModels.time_grid(sol)
                Test.@test x(t) ≈ _x(t) atol = TOL
                Test.@test _val(u(t)) ≈ _u(t) atol = TOL
            end
            Test.@test Trajectories.objective(sol) ≈ 6.0 atol = TOL
        end

        Test.@testset "ControlledFlow (ClosedLoop)" begin
            sol = _flow_c()((0.0, 1.0), X0)
            _check_default(CTModels.time_grid(sol), [0.0, 1.0])
        end

        Test.@testset "plain state flow" begin
            traj = _plain_s()((0.0, 1.0), [1.0, 0.0])
            T = Integrators.times(traj)
            _check_default(T, [0.0, 1.0])
            for t in T
                Test.@test traj(t) ≈ [cos(t), -sin(t)] atol = TOL
            end
        end

        Test.@testset "plain Hamiltonian flow" begin
            traj = _plain_h()((0.0, 1.0), 1.0, 0.0)
            T = Integrators.times(traj)
            _check_default(T, [0.0, 1.0])
            for t in T
                Test.@test _val(Trajectories.state(traj)(t)) ≈ cos(t) atol = TOL
                Test.@test _val(Trajectories.costate(traj)(t)) ≈ -sin(t) atol = TOL
            end
        end

        Test.@testset "backward integration" begin
            traj = _plain_s()((1.0, 0.0), [cos(1.0), -sin(1.0)])
            _check_default(Integrators.times(traj), [1.0, 0.0])
            Test.@test traj(0.0) ≈ [1.0, 0.0] atol = TOL
        end

        Test.@testset "a Solution of a flow has the size of a direct one" begin
            sol = _flow_h()((0.0, 1.0), X0, P0)
            Test.@test length(CTModels.time_grid(sol)) == NDEFAULT
        end

        # ── multi-phase: grid generated once, switching times once ───────────
        Test.@testset "multi-phase OCP (one switch)" begin
            f = _flow_h()
            sol = _no_warning(() -> (f * (0.5, f))((0.0, 1.0), X0, P0))
            _check_default(CTModels.time_grid(sol), [0.0, 0.5, 1.0])
            x, u = CTModels.state(sol), CTModels.control(sol)
            for t in CTModels.time_grid(sol)
                Test.@test x(t) ≈ _x(t) atol = TOL
                Test.@test _val(u(t)) ≈ _u(t) atol = TOL
            end
            Test.@test CTModels.objective(sol) ≈ 6.0 atol = TOL
        end

        Test.@testset "multi-phase OCP (two switches)" begin
            f = _flow_h()
            sol = (f * (0.3, f) * (0.6, f))((0.0, 1.0), X0, P0)
            _check_default(CTModels.time_grid(sol), [0.0, 0.3, 0.6, 1.0])
        end

        Test.@testset "multi-phase state OCP" begin
            f = _flow_s()
            sol = (f * (0.3, f))((0.0, 1.0), X0)
            _check_default(CTModels.time_grid(sol), [0.0, 0.3, 1.0])
            Test.@test Trajectories.objective(sol) ≈ 6.0 atol = TOL
        end

        Test.@testset "multi-phase controlled flows" begin
            f = _flow_c()
            sol = (f * (0.4, f))((0.0, 1.0), X0)
            _check_default(CTModels.time_grid(sol), [0.0, 0.4, 1.0])
        end

        Test.@testset "multi-phase plain flows" begin
            g = _plain_s()
            traj = (g * (0.4, g))((0.0, 1.0), [1.0, 0.0])
            _check_default(Integrators.times(traj), [0.0, 0.4, 1.0])
            h = _plain_h()
            htraj = (h * (0.4, h))((0.0, 1.0), 1.0, 0.0)
            _check_default(Integrators.times(htraj), [0.0, 0.4, 1.0])
        end

        Test.@testset "multi-phase with a jump: right limit read after the switch" begin
            f = _flow_h()
            sol = (f * (0.5, [0.0, -9.0], f))((0.0, 1.0), X0, P0)
            _check_default(CTModels.time_grid(sol), [0.0, 0.5, 1.0])
            Test.@test _val(CTModels.control(sol)(0.5)) ≈ _u(0.5) atol = TOL   # left value
        end

        # ── no loss of accuracy: same values and objective as the solver steps ──
        Test.@testset "values and objective unchanged (Hamiltonian OCP)" begin
            f = _flow_h()
            auto, raw = f((0.0, 1.0), X0, P0), f((0.0, 1.0), X0, P0; grid=nothing)
            Test.@test CTModels.objective(auto) ≈ CTModels.objective(raw) atol = 1e-12
            for t in OFF_GRID
                Test.@test CTModels.state(auto)(t) ≈ CTModels.state(raw)(t) atol = 1e-12
                Test.@test CTModels.costate(auto)(t) ≈ CTModels.costate(raw)(t) atol = 1e-12
                Test.@test _val(CTModels.control(auto)(t)) ≈ _val(CTModels.control(raw)(t)) atol =
                    1e-12
            end
        end

        Test.@testset "values and objective unchanged (state OCP)" begin
            f = _flow_s()
            auto, raw = f((0.0, 1.0), X0), f((0.0, 1.0), X0; grid=nothing)
            Test.@test Trajectories.objective(auto) ≈ Trajectories.objective(raw) atol = 1e-12
            for t in OFF_GRID
                Test.@test Trajectories.state(auto)(t) ≈ Trajectories.state(raw)(t) atol = 1e-12
            end
        end

        Test.@testset "values unchanged (plain state flow)" begin
            f = _plain_s()
            auto, raw = f((0.0, 1.0), [1.0, 0.0]), f((0.0, 1.0), [1.0, 0.0]; grid=nothing)
            for t in OFF_GRID
                Test.@test auto(t) ≈ raw(t) atol = 1e-12
            end
        end

        # ── the opt-out and the solver steps ─────────────────────────────────
        Test.@testset "grid=nothing keeps the solver steps [$kind]" for (kind, call, T) in (
            ("plain state", () -> _plain_s()((0.0, 1.0), [1.0, 0.0]; grid=nothing),
                Integrators.times),
            ("plain Hamiltonian", () -> _plain_h()((0.0, 1.0), 1.0, 0.0; grid=nothing),
                Integrators.times),
            ("OCP", () -> _flow_h()((0.0, 1.0), X0, P0; grid=nothing), CTModels.time_grid),
            ("OCP state", () -> _flow_s()((0.0, 1.0), X0; grid=nothing), CTModels.time_grid),
            ("multi-phase", () -> (_flow_h() * (0.5, _flow_h()))((0.0, 1.0), X0, P0; grid=nothing),
                CTModels.time_grid),
        )
            ts = T(call())
            Test.@test length(ts) < NDEFAULT
            Test.@test length(ts) < 100   # the coarse polyline of the issue
        end

        Test.@testset "multi-phase grid=nothing: the switching time appears twice" begin
            f = _flow_h()
            T = CTModels.time_grid((f * (0.5, f))((0.0, 1.0), X0, P0; grid=nothing))
            Test.@test count(==(0.5), T) == 2
        end

        # ── no generated grid when the output is already shaped ──────────────
        Test.@testset "saveat: returned as is [$kind]" for (kind, call, T) in (
            ("plain state", () -> _plain_s(; saveat=0.1)((0.0, 1.0), [1.0, 0.0]),
                Integrators.times),
            ("OCP", () -> _flow_h(; saveat=0.1)((0.0, 1.0), X0, P0), CTModels.time_grid),
            ("OCP state", () -> _flow_s(; saveat=0.1)((0.0, 1.0), X0), CTModels.time_grid),
            ("multi-phase", () -> (_flow_h(; saveat=0.1) * (0.5, _flow_h(; saveat=0.1)))(
                (0.0, 1.0), X0, P0), CTModels.time_grid),
        )
            ts = T(call())
            Test.@test length(ts) < NDEFAULT
            Test.@test length(ts) in (11, 12)   # the saveat grid (+ the switching time twice)
        end

        Test.@testset "grid of times: returned exactly [$kind]" for (kind, times) in (
            ("vector", [0.0, 0.25, 0.5, 1.0]),
            ("tuple", (0.0, 0.25, 0.5, 1.0)),
        )
            traj = _plain_s()(times, [1.0, 0.0])
            Test.@test Integrators.times(traj) == collect(Float64, times)
            sol = _flow_h()(times, X0, P0)
            Test.@test CTModels.time_grid(sol) == collect(Float64, times)
            sol = _flow_s()(times, X0)
            Test.@test CTModels.time_grid(sol) == collect(Float64, times)
        end

        Test.@testset "explicit grid=N is not replaced by the default" begin
            Test.@test length(Integrators.times(_plain_s()((0.0, 1.0), [1.0, 0.0]; grid=15))) == 15
            Test.@test length(
                Integrators.times(
                    _plain_s()((0.0, 1.0), [1.0, 0.0]; grid=Configs.UniformGrid(40))
                ),
            ) == 40
            Test.@test length(
                CTModels.time_grid(_flow_h()((0.0, 1.0), X0, P0; grid=Configs.AdaptiveGrid(60)))
            ) == 60
            # an explicit AdaptiveGrid(250) is applied whatever the solver returned
            Test.@test length(
                Integrators.times(
                    _plain_s()((0.0, 1.0), [1.0, 0.0]; grid=Configs.AdaptiveGrid(250))
                ),
            ) == 250
        end

        Test.@testset "dense=false: solver steps, no grid generated" begin
            traj = _plain_s(; dense=false)((0.0, 1.0), [1.0, 0.0])
            Test.@test length(Integrators.times(traj)) < 100
            thtraj = _plain_h(; dense=false)((0.0, 1.0), 1.0, 0.0)
            Test.@test length(Integrators.times(thtraj)) < 100
            # the OCP objective is recomputed from a non-dense trajectory and warns as before
            sol = Test.@test_logs (:warn, r"without dense output") _flow_h(; dense=false)(
                (0.0, 1.0), X0, P0
            )
            Test.@test length(CTModels.time_grid(sol)) < 100
        end

        Test.@testset "at least 250 solver times: left as the solver returned" begin
            f = Flows.Flow(
                Data.VectorField(x -> [x[2], -x[1]]); alg=Tsit5(), reltol=1e-12, abstol=1e-12
            )
            auto = f((0.0, 200.0), [1.0, 0.0])
            raw = f((0.0, 200.0), [1.0, 0.0]; grid=nothing)
            Test.@test length(Integrators.times(raw)) >= NDEFAULT
            Test.@test Integrators.times(auto) == Integrators.times(raw)
        end

        Test.@testset "point calls are not trajectories" begin
            Test.@test _plain_s()(0.0, [1.0, 0.0], 1.0) ≈ [cos(1.0), -sin(1.0)] atol = TOL
            xf, pf = _plain_h()(0.0, 1.0, 0.0, 1.0)
            Test.@test _val(xf) ≈ cos(1.0) atol = TOL
            Test.@test _val(pf) ≈ -sin(1.0) atol = TOL
        end

        Test.@testset "SciMLProblemFlow keeps the raw SciML behaviour" begin
            prob = ODEProblem((u, p, t) -> [u[2], -u[1]], [1.0, 0.0], (0.0, 1.0))
            f = CTFlowsSciMLFlows.SciMLProblemFlow(prob, Integrators.SciML(; _tol()...))
            r = f((0.0, 1.0), [1.0, 0.0])
            Test.@test length(Integrators.times(r)) < 100
            Test.@test Integrators.times(r) == Integrators.times(f((0.0, 1.0), [1.0, 0.0]; grid=nothing))
            # its own saveat is the user's escape hatch
            g = CTFlowsSciMLFlows.SciMLProblemFlow(
                ODEProblem((u, p, t) -> [u[2], -u[1]], [1.0, 0.0], (0.0, 1.0); saveat=0.1),
                Integrators.SciML(; _tol()...),
            )
            Test.@test length(Integrators.times(g((0.0, 1.0), [1.0, 0.0]))) == 11
        end

        # ── differentiation through a trajectory call with the default grid ──
        Test.@testset "ForwardDiff through the default grid" begin
            f = Flows.Flow(Data.VectorField(x -> -x); _tol()...)
            d = ForwardDiff.derivative(a -> _val(f((0.0, 1.0), [a])(1.0)), 1.0)
            Test.@test d ≈ exp(-1) atol = TOL
        end

        # ── complex states: the grid is built on real and imaginary parts ────
        Test.@testset "complex state" begin
            f = Flows.Flow(Data.VectorField(z -> -im .* z); _tol()...)
            traj = f((0.0, 1.0), ComplexF64[1.0 + 0im])
            _check_default(Integrators.times(traj), [0.0, 1.0])
            Test.@test only(traj(1.0)) ≈ exp(-im) atol = TOL
        end

        # ── errors are unchanged by the default ──────────────────────────────
        Test.@testset "Error: explicit conflicting grids still rejected" begin
            Test.@test_throws Exceptions.IncorrectArgument _plain_s()(
                [0.0, 0.5, 1.0], [1.0, 0.0]; grid=5
            )
            Test.@test_throws Exceptions.IncorrectArgument _plain_s(; saveat=0.1)(
                (0.0, 1.0), [1.0, 0.0]; grid=5
            )
            Test.@test_throws Exceptions.IncorrectArgument _plain_s()(
                (0.0, 1.0), [1.0, 0.0]; grid=:fine
            )
        end
    end
end

end # module

test_default_grid_calls() = TestDefaultGridCalls.test_default_grid_calls()
