"""
Precision regression tests for output grids (issue #434).

`saveat` (at construction) and a grid given at the call only shape the OUTPUT grid: the
integration and its dense interpolant are unchanged, so the state, the costate, the
reconstructed control and the objective stay accurate to the solver tolerances BETWEEN the
grid points — for every kind of flow, single- or multi-phase. With `dense=false` the
trajectory is linear between the saved points, and rebuilding an OCP objective from it
warns.

Problems with an exact solution:

- double integrator ẋ = (x₂, u), x(0) = (-1, 0), on [0, 1], with u = p₂ (Hamiltonian flow,
  p(0) = (12, 6)) or the open-loop u(t) = 6 - 12t (state flow): u = 6 - 12t,
  x(t) = (-1 + 3t² - 2t³, 6t - 6t²), p(t) = (12, 6 - 12t);
- harmonic oscillator (plain flows): x(t) = cos t, ẋ = -sin t.
"""

module TestSaveatPrecision

using Test: Test
using CTBase: Data
using CTBase: Exceptions
using CTModels: CTModels
using CTFlows: CTFlows
using CTFlows: Flows
using CTFlows: Integrators
using CTFlows: Trajectories
using OrdinaryDiffEqTsit5: Tsit5
using SciMLBase: SciMLBase, ODEProblem
using ForwardDiff: ForwardDiff  # triggers the DI ForwardDiff extension (AutoForwardDiff)

const CTFlowsSciMLFlows = Base.get_extension(CTFlows, :CTFlowsSciMLFlows)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const TOL = 1e-8                      # solver-accurate (reltol = abstol = 1e-10)
const OFF_GRID = (0.033, 0.257, 0.5, 0.777, 0.951)
const SAVEAT = range(0, 1, 11)        # constructor `saveat`
const CALL_GRID = [0.0, 0.05, 0.3, 0.31, 0.9, 1.0]   # grid given at the call (uneven)
const WARN = r"without dense output"

_tol() = (; alg=Tsit5(), reltol=1e-10, abstol=1e-10)
_val(a) = a isa Number ? a : a[1]

# ── exact solutions ──────────────────────────────────────────────────────────

_x(t) = [-1 + 3t^2 - 2t^3, 6t - 6t^2]
_p(t) = [12.0, 6 - 12t]
_u(t) = 6 - 12t
const X0, P0 = [-1.0, 0.0], [12.0, 6.0]

# ── double-integrator OCPs ───────────────────────────────────────────────────

function _di_ocp(; lagrange=nothing, mayer=nothing)
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=x[2]; r[2]=u; nothing))
    kw = (;
        (isnothing(lagrange) ? () : (; lagrange))..., (isnothing(mayer) ? () : (; mayer))...
    )
    CTModels.Building.objective!(pre, :min; kw...)
    return CTModels.Building.build(pre)
end

const MAYER = (x0, xf, v) -> xf[1] - x0[1]           # = 1
const LAG_U = (t, x, u, v) -> 0.5 * u^2               # ∫ = 6
const LAG_UX = (t, x, u, v) -> 0.5 * u^2 + 0.5 * x[2]^2   # ∫ = 6 + 0.6

# Hamiltonian OCPs (the Lagrange cost must not depend on x: the law u = p₂ keeps p exact)
const OCPS_H = (
    ("Lagrange", _di_ocp(; lagrange=LAG_U), 6.0),
    ("Mayer", _di_ocp(; mayer=MAYER), 1.0),
    ("Bolza", _di_ocp(; lagrange=LAG_U, mayer=MAYER), 7.0),
)
# state-flow OCPs (no costate: the Lagrange cost may depend on x)
const OCPS_S = (
    ("Lagrange", _di_ocp(; lagrange=LAG_UX), 6.6),
    ("Mayer", _di_ocp(; mayer=MAYER), 1.0),
    ("Bolza", _di_ocp(; lagrange=LAG_UX, mayer=MAYER), 7.6),
)

const LAW_H = Data.DynClosedLoop((x, p) -> p[2])
const LAW_S = Data.OpenLoop(t -> 6 - 12t)

# ── variants: (label, constructor kwargs, call times, expected grid or nothing) ─

const VARIANTS = (
    ("span", (;), (0.0, 1.0), nothing),
    ("saveat", (; saveat=SAVEAT), (0.0, 1.0), collect(SAVEAT)),
    ("saveat step", (; saveat=0.1), (0.0, 1.0), collect(0:0.1:1)),
    ("call grid", (;), CALL_GRID, CALL_GRID),
    ("call grid as tuple", (;), Tuple(CALL_GRID), CALL_GRID),
)

_check_grid(T, ::Nothing) = (Test.@test first(T) == 0.0; Test.@test last(T) == 1.0)
_check_grid(T, expected) = Test.@test T ≈ expected

# no warning at all while evaluating `f()`
_no_warning(f) = Test.@test_logs min_level = Base.CoreLogging.Warn f()

function test_saveat_precision()
    Test.@testset "saveat precision (issue #434)" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # Flow(ocp, law) — Hamiltonian (costate) path → CTModels.Solution
        # ====================================================================

        Test.@testset "Flow(ocp, DynClosedLoop) [$cost, $label]" for (cost, ocp, J) in
                                                                     OCPS_H,
            (label, kw, times, grid) in VARIANTS

            f = Flows.Flow(ocp, LAW_H; hamiltonian_type=:partial, _tol()..., kw...)
            sol = _no_warning(() -> f(times, X0, P0))
            x, p, u = CTModels.state(sol), CTModels.costate(sol), CTModels.control(sol)
            _check_grid(CTModels.time_grid(sol), grid)
            for t in OFF_GRID
                Test.@test x(t) ≈ _x(t) atol = TOL
                Test.@test p(t) ≈ _p(t) atol = TOL
                Test.@test _val(u(t)) ≈ _u(t) atol = TOL
            end
            Test.@test CTModels.objective(sol) ≈ J atol = TOL
        end

        # ====================================================================
        # Flow(ocp, law) — state path (no costate) → StateFlowTrajectory
        # ====================================================================

        Test.@testset "Flow(ocp, OpenLoop) [$cost, $label]" for (cost, ocp, J) in OCPS_S,
            (label, kw, times, grid) in VARIANTS

            f = Flows.Flow(ocp, LAW_S; _tol()..., kw...)
            sol = _no_warning(() -> f(times, X0))
            x, u = Trajectories.state(sol), Trajectories.control(sol)
            _check_grid(CTModels.time_grid(sol), grid)
            for t in OFF_GRID
                Test.@test x(t) ≈ _x(t) atol = TOL
                Test.@test _val(u(t)) ≈ _u(t) atol = TOL
            end
            Test.@test Trajectories.objective(sol) ≈ J atol = TOL
        end

        # ====================================================================
        # the issue's reproducer: saveat on Flow(ocp, law), Lagrange and Mayer
        # ====================================================================

        Test.@testset "issue #434 reproducer [$cost]" for (cost, ocp, J) in OCPS_H
            f = Flows.Flow(ocp, LAW_H; hamiltonian_type=:partial, saveat=range(0, 1, 11))
            Test.@test f(0, [-1, 0], [12, 6], 1)[1] ≈ _x(1.0) atol = 1e-6
            sol = f((0, 1), [-1, 0], [12, 6])
            Test.@test CTModels.objective(sol) ≈ J atol = 1e-6
        end

        # ====================================================================
        # dense=false: linear between saved points, warning on the objective
        # ====================================================================

        Test.@testset "dense=false [OCP, Hamiltonian]" begin
            f = Flows.Flow(OCPS_H[1][2], LAW_H; _tol()..., saveat=SAVEAT, dense=false)
            sol = Test.@test_logs (:warn, WARN) f((0.0, 1.0), X0, P0)
            Test.@test CTModels.time_grid(sol) ≈ collect(SAVEAT)
            Test.@test CTModels.state(sol)(0.5) ≈ _x(0.5) atol = TOL   # a saved point
            Test.@test CTModels.objective(sol) ≈ 6.0 atol = 1e-1
        end

        Test.@testset "dense=false [OCP, state]" begin
            f = Flows.Flow(OCPS_S[1][2], LAW_S; _tol()..., saveat=SAVEAT, dense=false)
            sol = Test.@test_logs (:warn, WARN) f((0.0, 1.0), X0)
            x = Trajectories.state(sol)
            Test.@test x(0.5) ≈ _x(0.5) atol = TOL                      # a saved point
            Test.@test maximum(abs.(x(0.257) - _x(0.257))) > 1e-5      # linear in between
            J = Trajectories.objective(sol)
            Test.@test abs(J - 6.6) > 1e-6                             # grid-limited
            Test.@test J ≈ 6.6 atol = 1e-1
        end

        # ====================================================================
        # plain flows (no OCP): no objective, no warning
        # ====================================================================

        Test.@testset "plain state flow [$label]" for (label, kw, times, grid) in VARIANTS
            f = Flows.Flow(Data.VectorField(x -> [x[2], -x[1]]); _tol()..., kw...)
            traj = _no_warning(() -> f(times, [1.0, 0.0]))
            _check_grid(Integrators.times(traj), grid)
            for t in OFF_GRID
                Test.@test traj(t) ≈ [cos(t), -sin(t)] atol = TOL
            end
        end

        Test.@testset "plain Hamiltonian flow [$label]" for (label, kw, times, grid) in
                                                            VARIANTS

            f = Flows.Flow(Data.HamiltonianVectorField((x, p) -> (p, -x)); _tol()..., kw...)
            traj = _no_warning(() -> f(times, 1.0, 0.0))
            x, p = Trajectories.state(traj), Trajectories.costate(traj)
            _check_grid(Integrators.times(traj), grid)
            for t in OFF_GRID
                Test.@test _val(x(t)) ≈ cos(t) atol = TOL
                Test.@test _val(p(t)) ≈ -sin(t) atol = TOL
            end
        end

        Test.@testset "plain state flow, dense=false" begin
            f = Flows.Flow(
                Data.VectorField(x -> [x[2], -x[1]]); _tol()..., saveat=SAVEAT, dense=false
            )
            traj = _no_warning(() -> f((0.0, 1.0), [1.0, 0.0]))
            Test.@test !Integrators.is_dense(traj)
            Test.@test traj(0.5) ≈ [cos(0.5), -sin(0.5)] atol = TOL
        end

        # ====================================================================
        # SciML problem flow (saveat in the problem, or given at the call)
        # ====================================================================

        Test.@testset "SciML problem flow" begin
            osc(u, p, t) = [u[2], -u[1]]
            for (label, prob, times, grid) in (
                (
                    "saveat in the problem",
                    ODEProblem(osc, [1.0, 0.0], (0.0, 1.0); saveat=0.1),
                    (0.0, 1.0),
                    collect(0:0.1:1),
                ),
                (
                    "call grid",
                    ODEProblem(osc, [1.0, 0.0], (0.0, 1.0)),
                    CALL_GRID,
                    CALL_GRID,
                ),
            )
                Test.@testset "$label" begin
                    f = CTFlowsSciMLFlows.SciMLProblemFlow(
                        prob, Integrators.SciML(; _tol()...)
                    )
                    r = f(times, [1.0, 0.0])
                    Test.@test Integrators.times(r) ≈ grid
                    for t in OFF_GRID
                        Test.@test Integrators.evaluate_at(r, t) ≈ [cos(t), -sin(t)] atol =
                            TOL
                    end
                end
            end
        end

        # ====================================================================
        # multi-phase flows: split invariance at the solver accuracy
        # ====================================================================

        Test.@testset "multi-phase OCP [$cost, $label]" for (cost, ocp, J) in OCPS_H,
            (label, kw, times, _) in VARIANTS

            f = Flows.Flow(ocp, LAW_H; hamiltonian_type=:partial, _tol()..., kw...)
            φ = f * (0.5, f)
            sol = _no_warning(() -> φ(times, X0, P0))
            x, p, u = CTModels.state(sol), CTModels.costate(sol), CTModels.control(sol)
            T = CTModels.time_grid(sol)
            if times isa Tuple{Real,Real} && !haskey(kw, :saveat)
                # default grid (issue #446): adaptive, the switching time appears once
                Test.@test count(==(0.5), T) == 1
                Test.@test length(T) == 250
            elseif times isa Tuple{Real,Real}
                Test.@test count(==(0.5), T) == 2   # the switching time closes and opens a phase
            else
                Test.@test T == collect(Float64, times)   # a grid of times is returned exactly
            end
            Test.@test first(T) == 0.0 && last(T) == 1.0
            for t in OFF_GRID
                Test.@test x(t) ≈ _x(t) atol = TOL
                Test.@test p(t) ≈ _p(t) atol = TOL
                Test.@test _val(u(t)) ≈ _u(t) atol = TOL
            end
            Test.@test CTModels.objective(sol) ≈ J atol = TOL
        end

        Test.@testset "multi-phase state OCP [$cost, $label]" for (cost, ocp, J) in OCPS_S,
            (label, kw, times, _) in VARIANTS

            f = Flows.Flow(ocp, LAW_S; _tol()..., kw...)
            φ = f * (0.5, f)
            sol = _no_warning(() -> φ(times, X0))
            x, u = Trajectories.state(sol), Trajectories.control(sol)
            for t in OFF_GRID
                Test.@test x(t) ≈ _x(t) atol = TOL
                Test.@test _val(u(t)) ≈ _u(t) atol = TOL
            end
            Test.@test Trajectories.objective(sol) ≈ J atol = TOL
        end

        Test.@testset "multi-phase grid at the call" begin
            f = Flows.Flow(OCPS_H[1][2], LAW_H; hamiltonian_type=:partial, _tol()...)
            sol = (f * (0.5, f))(CALL_GRID, X0, P0)
            Test.@test CTModels.time_grid(sol) == CALL_GRID   # exactly the given times
        end

        Test.@testset "multi-phase dense=false warns" begin
            f = Flows.Flow(OCPS_H[1][2], LAW_H; _tol()..., saveat=SAVEAT, dense=false)
            Test.@test_logs (:warn, WARN) (f * (0.5, f))((0.0, 1.0), X0, P0)
        end

        # ====================================================================
        # invalid grids at the call
        # ====================================================================

        Test.@testset "Error: invalid call grid" begin
            f = Flows.Flow(Data.VectorField(x -> -x); _tol()...)
            Test.@test_throws Exceptions.IncorrectArgument f([0.0], 1.0)
            Test.@test_throws Exceptions.IncorrectArgument f([0.0, 0.5, 0.5, 1.0], 1.0)
            Test.@test_throws Exceptions.IncorrectArgument f([0.0, 0.7, 0.5, 1.0], 1.0)
            Test.@test_throws Exceptions.IncorrectArgument f((0.0,), 1.0)
        end

        Test.@testset "Error: saveat and a grid at the call" begin
            f = Flows.Flow(Data.VectorField(x -> -x); _tol()..., saveat=SAVEAT)
            Test.@test_throws Exceptions.IncorrectArgument f(CALL_GRID, 1.0)
            g = Flows.Flow(OCPS_H[1][2], LAW_H; _tol()..., saveat=SAVEAT)
            Test.@test_throws Exceptions.IncorrectArgument g(CALL_GRID, X0, P0)
            Test.@test_throws Exceptions.IncorrectArgument (g * (0.5, g))(CALL_GRID, X0, P0)
        end

        Test.@testset "backward call grid" begin
            f = Flows.Flow(Data.VectorField(x -> [x[2], -x[1]]); _tol()...)
            x1 = [cos(1.0), -sin(1.0)]
            traj = f([1.0, 0.6, 0.2, 0.0], x1)
            Test.@test Integrators.times(traj) == [1.0, 0.6, 0.2, 0.0]
            Test.@test traj(0.0) ≈ [1.0, 0.0] atol = TOL
            Test.@test traj(0.4) ≈ [cos(0.4), -sin(0.4)] atol = TOL
        end
    end
end

end # module

test_saveat_precision() = TestSaveatPrecision.test_saveat_precision()
