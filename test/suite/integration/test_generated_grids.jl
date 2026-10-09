"""
End-to-end tests of the generated output grids (issue #435): `f((t0, tf), …; grid=spec)`
returns the trajectory on exactly `spec.n` distinct times, for every kind of flow, without
changing the integration (values and objective at solver accuracy); invalid or conflicting
grids are rejected.

Problems with an exact solution (double integrator ẋ = (x₂, u), x(0) = (-1, 0)):
u = p₂ with p(0) = (12, 6) ⇒ u = 6 - 12t, x = (-1 + 3t² - 2t³, 6t - 6t²), p = (12, 6 - 12t).
"""

module TestGeneratedGrids

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
const N = 15
const SPECS = (
    ("grid=N", N),
    ("UniformGrid", Configs.UniformGrid(N)),
    ("AdaptiveGrid", Configs.AdaptiveGrid(N)),
    ("AdaptiveGrid uniform=0", Configs.AdaptiveGrid(N; uniform=0.0)),
)

_tol() = (; alg=Tsit5(), reltol=1e-10, abstol=1e-10)
_val(a) = a isa Number ? a : a[1]
_x(t) = [-1 + 3t^2 - 2t^3, 6t - 6t^2]
_p(t) = [12.0, 6 - 12t]
_u(t) = 6 - 12t
const X0, P0 = [-1.0, 0.0], [12.0, 6.0]

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

# generic properties of a generated grid
function _check_grid(T, n, bounds)
    Test.@test length(T) == n
    Test.@test allunique(T)
    Test.@test issorted(last(bounds) > first(bounds) ? T : reverse(T); lt=<)
    Test.@test first(T) == first(bounds) && last(T) == last(bounds)
    for b in bounds
        Test.@test count(==(b), T) == 1
    end
end

_no_warning(f) = Test.@test_logs min_level = Base.CoreLogging.Warn f()

# polyline error of `f` drawn through the times `T`, against `f` itself
function _polyline_error(f, T)
    err = 0.0
    for t in range(first(T), last(T), 2001)
        j = clamp(searchsortedlast(T, t), 1, length(T) - 1)
        w = (t - T[j]) / (T[j + 1] - T[j])
        err = max(err, abs((1 - w) * f(T[j]) + w * f(T[j + 1]) - f(t)))
    end
    return err
end

function test_generated_grids()
    Test.@testset "generated output grids (issue #435)" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ── Flow(ocp, law), Hamiltonian path → Solution ──────────────────────
        Test.@testset "Flow(ocp, DynClosedLoop) [$label]" for (label, spec) in SPECS
            f = _flow_h()
            sol = _no_warning(() -> f((0.0, 1.0), X0, P0; grid=spec))
            T = CTModels.time_grid(sol)
            _check_grid(T, N, [0.0, 1.0])
            x, p, u = CTModels.state(sol), CTModels.costate(sol), CTModels.control(sol)
            for t in T
                Test.@test x(t) ≈ _x(t) atol = TOL
                Test.@test p(t) ≈ _p(t) atol = TOL
                Test.@test _val(u(t)) ≈ _u(t) atol = TOL
            end
            Test.@test CTModels.objective(sol) ≈ CTModels.objective(f((0.0, 1.0), X0, P0)) atol =
                1e-12
        end

        # ── Flow(ocp, law), state path → StateFlowTrajectory ─────────────────
        Test.@testset "Flow(ocp, OpenLoop) [$label]" for (label, spec) in SPECS
            f = _flow_s()
            sol = _no_warning(() -> f((0.0, 1.0), X0; grid=spec))
            T = CTModels.time_grid(sol)
            _check_grid(T, N, [0.0, 1.0])
            x, u = Trajectories.state(sol), Trajectories.control(sol)
            for t in T
                Test.@test x(t) ≈ _x(t) atol = TOL
                Test.@test _val(u(t)) ≈ _u(t) atol = TOL
            end
            Test.@test Trajectories.objective(sol) ≈ 6.0 atol = TOL
        end

        # ── plain flows ──────────────────────────────────────────────────────
        Test.@testset "plain state flow [$label]" for (label, spec) in SPECS
            f = Flows.Flow(Data.VectorField(x -> [x[2], -x[1]]); _tol()...)
            traj = _no_warning(() -> f((0.0, 1.0), [1.0, 0.0]; grid=spec))
            T = Integrators.times(traj)
            _check_grid(T, N, [0.0, 1.0])
            for t in T
                Test.@test traj(t) ≈ [cos(t), -sin(t)] atol = TOL
            end
        end

        Test.@testset "plain Hamiltonian flow [$label]" for (label, spec) in SPECS
            f = Flows.Flow(Data.HamiltonianVectorField((x, p) -> (p, -x)); _tol()...)
            traj = _no_warning(() -> f((0.0, 1.0), 1.0, 0.0; grid=spec))
            T = Integrators.times(traj)
            _check_grid(T, N, [0.0, 1.0])
            for t in T
                Test.@test _val(Trajectories.state(traj)(t)) ≈ cos(t) atol = TOL
                Test.@test _val(Trajectories.costate(traj)(t)) ≈ -sin(t) atol = TOL
            end
        end

        Test.@testset "SciML problem flow [$label]" for (label, spec) in SPECS
            prob = ODEProblem((u, p, t) -> [u[2], -u[1]], [1.0, 0.0], (0.0, 1.0))
            f = CTFlowsSciMLFlows.SciMLProblemFlow(prob, Integrators.SciML(; _tol()...))
            r = f((0.0, 1.0), [1.0, 0.0]; grid=spec)
            T = Integrators.times(r)
            _check_grid(T, N, [0.0, 1.0])
            for t in T
                Test.@test Integrators.evaluate_at(r, t) ≈ [cos(t), -sin(t)] atol = TOL
            end
        end

        Test.@testset "backward [$label]" for (label, spec) in SPECS
            f = Flows.Flow(Data.VectorField(x -> [x[2], -x[1]]); _tol()...)
            traj = f((1.0, 0.0), [cos(1.0), -sin(1.0)]; grid=spec)
            _check_grid(Integrators.times(traj), N, [1.0, 0.0])
            Test.@test traj(0.0) ≈ [1.0, 0.0] atol = TOL
        end

        # ── multi-phase ──────────────────────────────────────────────────────
        Test.@testset "multi-phase OCP [$label]" for (label, spec) in SPECS
            f = _flow_h()
            φ = f * (0.5, f)
            sol = _no_warning(() -> φ((0.0, 1.0), X0, P0; grid=spec))
            T = CTModels.time_grid(sol)
            _check_grid(T, N, [0.0, 0.5, 1.0])   # the switching time once
            x, u = CTModels.state(sol), CTModels.control(sol)
            for t in T
                Test.@test x(t) ≈ _x(t) atol = TOL
                Test.@test _val(u(t)) ≈ _u(t) atol = TOL
            end
            Test.@test CTModels.objective(sol) ≈ 6.0 atol = TOL
        end

        Test.@testset "multi-phase state OCP [$label]" for (label, spec) in SPECS
            f = _flow_s()
            sol = (f * (0.3, f))((0.0, 1.0), X0; grid=spec)
            _check_grid(CTModels.time_grid(sol), N, [0.0, 0.3, 1.0])
            Test.@test Trajectories.objective(sol) ≈ 6.0 atol = TOL
        end

        Test.@testset "multi-phase plain flows" begin
            g = Flows.Flow(Data.VectorField(x -> [x[2], -x[1]]); _tol()...)
            traj = (g * (0.4, g))((0.0, 1.0), [1.0, 0.0]; grid=Configs.AdaptiveGrid(N))
            _check_grid(Integrators.times(traj), N, [0.0, 0.4, 1.0])
            h = Flows.Flow(Data.HamiltonianVectorField((x, p) -> (p, -x)); _tol()...)
            htraj = (h * (0.4, h))((0.0, 1.0), 1.0, 0.0; grid=N)
            _check_grid(Integrators.times(htraj), N, [0.0, 0.4, 1.0])
        end

        Test.@testset "multi-phase with a costate jump: right limit read after the switch" begin
            f = _flow_h()
            sol = (f * (0.5, [0.0, -9.0], f))((0.0, 1.0), X0, P0; grid=Configs.AdaptiveGrid(N))
            T = CTModels.time_grid(sol)
            _check_grid(T, N, [0.0, 0.5, 1.0])
            Test.@test _val(CTModels.control(sol)(0.5)) ≈ _u(0.5) atol = TOL   # left value
        end

        # ── adaptivity ───────────────────────────────────────────────────────
        Test.@testset "adaptive grid follows a sharp control" begin
            sharp = Flows.Flow(OCP, Data.OpenLoop(t -> tanh(40 * (t - 0.6))); _tol()...)
            n = 30
            su = sharp((0.0, 1.0), X0; grid=Configs.UniformGrid(n))
            sa = sharp((0.0, 1.0), X0; grid=Configs.AdaptiveGrid(n))
            uf = t -> _val(Trajectories.control(sa)(t))
            eu = _polyline_error(uf, CTModels.time_grid(su))
            ea = _polyline_error(uf, CTModels.time_grid(sa))
            Test.@test ea < eu / 3
        end

        # ── dense=false: works, the OCP objective warns as before ────────────
        Test.@testset "dense=false" begin
            f = _flow_h(; dense=false)
            sol = Test.@test_logs (:warn, r"without dense output") f((0.0, 1.0), X0, P0; grid=N)
            _check_grid(CTModels.time_grid(sol), N, [0.0, 1.0])
        end

        # ── security: invalid or conflicting grids ───────────────────────────
        Test.@testset "Error: invalid grid keyword" begin
            f = Flows.Flow(Data.VectorField(x -> -x); _tol()...)
            for bad in (1, 0, -3, 2.5, [0.0, 1.0], :fine, "10")
                Test.@test_throws Exceptions.IncorrectArgument f((0.0, 1.0), 1.0; grid=bad)
            end
            Test.@test_throws Exceptions.IncorrectArgument f(
                (0.0, 1.0), 1.0; grid=Configs.AdaptiveGrid(10; uniform=2.0)
            )
        end

        Test.@testset "Error: grid of times and grid= [$kind]" for (kind, call) in (
            ("state", () -> Flows.Flow(Data.VectorField(x -> -x); _tol()...)([0.0, 0.5, 1.0], 1.0; grid=5)),
            ("OCP", () -> _flow_h()([0.0, 0.5, 1.0], X0, P0; grid=5)),
            ("OCP state", () -> _flow_s()((0.0, 0.5, 1.0), X0; grid=5)),
            ("multi-phase", () -> (_flow_h() * (0.5, _flow_h()))([0.0, 0.7, 1.0], X0, P0; grid=5)),
        )
            Test.@test_throws Exceptions.IncorrectArgument call()
        end

        Test.@testset "Error: saveat and grid= [$kind]" for (kind, call) in (
            ("state", () -> Flows.Flow(Data.VectorField(x -> -x); _tol()..., saveat=0.1)((0.0, 1.0), 1.0; grid=5)),
            ("Hamiltonian", () -> Flows.Flow(Data.HamiltonianVectorField((x, p) -> (p, -x)); saveat=0.1)((0.0, 1.0), 1.0, 0.0; grid=5)),
            ("OCP", () -> _flow_h(; saveat=0.1)((0.0, 1.0), X0, P0; grid=5)),
            ("OCP state", () -> _flow_s(; saveat=0.1)((0.0, 1.0), X0; grid=5)),
            ("multi-phase", () -> (_flow_h(; saveat=0.1) * (0.5, _flow_h()))((0.0, 1.0), X0, P0; grid=5)),
            ("SciML problem (integrator)", () -> CTFlowsSciMLFlows.SciMLProblemFlow(
                ODEProblem((u, p, t) -> -u, [1.0], (0.0, 1.0)), Integrators.SciML(; saveat=0.1)
            )((0.0, 1.0), [1.0]; grid=5)),
            ("SciML problem (problem)", () -> CTFlowsSciMLFlows.SciMLProblemFlow(
                ODEProblem((u, p, t) -> -u, [1.0], (0.0, 1.0); saveat=0.1), Integrators.SciML()
            )((0.0, 1.0), [1.0]; grid=5)),
        )
            Test.@test_throws Exceptions.IncorrectArgument call()
        end

        Test.@testset "Error: too few times for the phases" begin
            f = _flow_h()
            Test.@test_throws Exceptions.IncorrectArgument (f * (0.3, f) * (0.6, f))(
                (0.0, 1.0), X0, P0; grid=3
            )
        end
    end
end

end # module

test_generated_grids() = TestGeneratedGrids.test_generated_grids()
