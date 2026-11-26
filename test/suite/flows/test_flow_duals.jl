"""
Constraint duals of the `Solution` of `Flow(ocp, law; multipliers=:label => y)`
(issue #472, control-toolbox/CTModels.jl#536).

The multiplier `y` given to the flow is the dual of the solution, in the convention of the
direct solvers (control-toolbox/CTSolvers.jl#288): a row with a single finite bound has a
dual `y ≥ 0`, whatever the way it is written; an equality, or a row with two finite
bounds, has a signed dual, `y < 0` on its lower bound and `y > 0` on its upper bound. The
trajectory call places `y` in the solution, by label: path constraints, state boxes and
control boxes.
"""
module TestFlowDuals

using Test: Test
using CTBase: Exceptions
using CTModels: CTModels
using CTFlows: Flows
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5  # SciML integrator for Flow(...)
using ForwardDiff: ForwardDiff  # triggers the DI ForwardDiff extension (AutoForwardDiff)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const OPTS = (; reltol=1e-10, abstol=1e-10)
const LB = 0.1

# ── models ───────────────────────────────────────────────────────────────────

"""
`ẋ = u`, `x(0) = -1`, `∫(-u) → min` on `[0, 1]`, with `x + u ≤ 0` (label `:mixed`) and,
declared first, a 2-row constraint `:dummy` never active. Closed form: `p(t) = e^{t-1} - 1`,
`u = -x`, and on the arc `μ = p + 1 = e^{t-1}` for `g = -(x + u) ≥ 0`.
"""
function _mixed()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=u; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> -u)
    CTModels.Building.constraint!(pre, :control; rg=1:1, lb=[0.0], ub=[Inf], label=:u_box)
    CTModels.Building.constraint!(
        pre,
        :path;
        f=(r, t, x, u, v) -> (r[1]=x - 10; r[2]=u - 10; nothing),
        lb=[-Inf, -Inf],
        ub=[0.0, 0.0],
        label=:dummy,
    )
    CTModels.Building.constraint!(
        pre,
        :path;
        f=(r, t, x, u, v) -> (r[1]=x + u; nothing),
        lb=(-Inf),
        ub=0.0,
        label=:mixed,
    )
    return CTModels.Building.build(pre)
end
const P0_MIXED = exp(-1.0) - 1.0

"""Issue #440: `ẋ = u`, `∫ x² → min` on `[0, 2]`, with the path constraint `cons`."""
function _issue440(f!, lb, ub)
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=2.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=u; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> x^2)
    CTModels.Building.constraint!(pre, :path; f=f!, lb=lb, ub=ub, label=:xcon)
    return CTModels.Building.build(pre)
end

# x ≥ lb, written three ways: the same constraint, so the same dual
const SPELLINGS = (
    ("x - lb ≥ 0", (r, t, x, u, v) -> (r[1]=x - LB; nothing), 0.0, Inf),
    ("x ≥ lb", (r, t, x, u, v) -> (r[1]=x; nothing), LB, Inf),
    ("lb - x ≤ 0", (r, t, x, u, v) -> (r[1]=LB - x; nothing), -Inf, 0.0),
)
# The exact initial costate: p vanishes at the entry t₁ = 0.9, and ṗ = 2x = 2(1 - t) before it,
# so p(0) = -∫₀^0.9 2(1 - t) dt = -0.99 (the former -0.982237546583301 was the costate of a
# direct solve on a coarse grid).
const P0_440 = -0.99

"""Issue #440 with `x ≥ lb` written as a state box `:xbox`."""
function _issue440_box()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=2.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=u; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> x^2)
    CTModels.Building.constraint!(pre, :state; rg=1:1, lb=[LB], ub=[Inf], label=:xbox)
    CTModels.Building.constraint!(pre, :control; rg=1:1, lb=[-1.0], ub=[1.0], label=:ubox)
    return CTModels.Building.build(pre)
end

"""Issue #440 with the three arcs `u = -1`, boundary (`μ = 2x`), `u = +1`."""
function _three_arcs(ocp; constraint=:xcon)
    f_minus = Flows.Flow(ocp, (x, p) -> -1; label="u = -1", OPTS...)
    f_bound = Flows.Flow(
        ocp,
        (x, p) -> 0;
        multipliers=constraint => ((x, p) -> 2x),
        label="boundary",
        OPTS...,
    )
    f_plus = Flows.Flow(ocp, (x, p) -> 1; label="u = +1", OPTS...)
    return f_minus * (0.9, f_bound) * (1.6, f_plus)
end

"""`ẋ = u` on `[0, 1]` with one scalar constraint `lb ≤ x ≤ ub` labelled `:c`."""
function _scalar(lb, ub)
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=u; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    CTModels.Building.constraint!(
        pre, :path; f=(r, t, x, u, v) -> (r[1]=x; nothing), lb=lb, ub=ub, label=:c
    )
    return CTModels.Building.build(pre)
end

"""`ẋ = u` in dimension 2, with the 2-D constraint `:c` = `x` and the scalar `:s` = `u`."""
function _vector(lb, ub)
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=u; r[2]=0; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    CTModels.Building.constraint!(
        pre, :path; f=(r, t, x, u, v) -> (r.=x; nothing), lb=lb, ub=ub, label=:c
    )
    CTModels.Building.constraint!(
        pre, :path; f=(r, t, x, u, v) -> (r[1]=u; nothing), lb=-1.0, ub=Inf, label=:s
    )
    return CTModels.Building.build(pre)
end

_const(c) = (x, p) -> c                     # a constant multiplier
function _dual(ocp, flow, label; x0=0.5, p0=0.0)
    return CTModels.dual(flow((0.0, 1.0), x0, p0), ocp, label)
end

function test_flow_duals()
    Test.@testset "Flow duals (issue #472)" verbose = VERBOSE showtiming = SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - the labels with a known dual
        # ====================================================================

        Test.@testset "_flow_duals: adjoined labels, then the other path labels" begin
            ocp = _mixed()
            d = Flows._flow_duals(ocp, nothing, nothing)
            Test.@test Flows._dual_labels(d) == [:dummy, :mixed]       # zero duals
            Test.@test Flows._dual_value(d, :dummy, 0.0, 1.0, 1.0, Float64[]) == [0.0, 0.0]
            d = Flows._flow_duals(ocp, :mixed, _const(0.7))
            Test.@test Flows._dual_labels(d) == [:mixed, :dummy]
            Test.@test Flows._dual_value(d, :mixed, 0.0, 1.0, 1.0, Float64[]) == 0.7
            d = Flows._flow_duals(ocp, (:u_box, :mixed), (_const(0.2), _const(0.7)))
            Test.@test Flows._dual_labels(d) == [:u_box, :mixed, :dummy]  # :u_box adjoined
            Test.@test Flows._flow_duals(ocp, (x, u) -> x + u, (x, p) -> 1.0) isa
                Flows._UnlabelledPathDuals
        end

        # ====================================================================
        # INTEGRATION TESTS - closed form, single arc
        # ====================================================================

        Test.@testset "single arc: dual = e^{t-1} [$ht]" for ht in (:total, :partial)
            ocp = _mixed()
            f = Flows.Flow(
                ocp,
                (x, p) -> -x;
                multipliers=:mixed => ((x, p) -> p + 1),
                hamiltonian_type=ht,
                OPTS...,
            )
            sol = f((0.0, 1.0), -1.0, P0_MIXED)
            Test.@test CTModels.Solutions.has_duals(sol)
            d = CTModels.dual(sol, ocp, :mixed)
            for t in (0.0, 0.25, 0.5, 1.0)
                Test.@test d(t) ≈ exp(t - 1) atol = 1e-8
            end
            Test.@test d(0.5) isa Real                          # 1-D is a scalar
            Test.@test CTModels.dual(sol, ocp, :dummy)(0.5) == [0.0, 0.0]
            Test.@test CTModels.path_constraints_dual(sol)(1.0) ≈ [0.0, 0.0, 1.0] atol =
                1e-8
            # a box label not given to the flow: not rebuilt, and the error says so
            err = try
                CTModels.dual(sol, ocp, :u_box)
            catch e
                e
            end
            Test.@test err isa Exceptions.PreconditionError
            Test.@test occursin("boxes not given to the flow", err.suggestion)
            Test.@test occursin("CTFlows.jl#495", err.suggestion)
            # an unknown label
            Test.@test_throws Exceptions.IncorrectArgument CTModels.dual(sol, ocp, :nope)
        end

        # ====================================================================
        # INTEGRATION TESTS - a constraint written three ways, three arcs
        # ====================================================================

        Test.@testset "three arcs: the same dual for $name" for (name, f!, lb, ub) in
                                                                SPELLINGS

            ocp = _issue440(f!, lb, ub)
            sol = _three_arcs(ocp)((0.0, 2.0), 1.0, P0_440)
            d = CTModels.dual(sol, ocp, :xcon)
            Test.@test d(0.5) == 0.0                             # interior arc
            Test.@test d(1.2) ≈ 2LB atol = 1e-8                  # μ = 2x on the boundary
            Test.@test d(1.8) == 0.0
            Test.@test d(0.9) == 0.0                             # left-continuous
            Test.@test d(1.6) ≈ 2LB atol = 1e-8
            # limits at the switching times, for the plots
            sw = CTModels.Solutions.switching_model(sol)
            left, right = CTModels.Solutions.limits(sw, :path_dual)
            Test.@test left ≈ [0.0; 2LB;;] atol = 1e-8
            Test.@test right ≈ [2LB; 0.0;;] atol = 1e-8
            Test.@test CTModels.left_limit(sol, :path_dual, 1) == 0.0
            Test.@test CTModels.right_limit(sol, :path_dual, 1) ≈ 2LB atol = 1e-8
            Test.@test CTModels.phase_labels(sol) == ["u = -1", "boundary", "u = +1"]
        end

        # ====================================================================
        # INTEGRATION TESTS - box labels: the state box of issue #440
        # ====================================================================

        Test.@testset "three arcs with the state box: its dual in the solution" begin
            ocp = _issue440_box()
            sol = _three_arcs(ocp; constraint=:xbox)((0.0, 2.0), 1.0, P0_440)
            d = CTModels.dual(sol, ocp, :xbox)
            Test.@test d(0.5) == 0.0                             # not adjoined: 0
            Test.@test d(1.2) ≈ 2LB atol = 1e-8                  # y = 2x on the boundary
            Test.@test d(1.8) == 0.0
            # the same dual as the path constraint x - lb ≥ 0 (SGN5)
            o = _issue440(SPELLINGS[1][2:4]...)
            dp = CTModels.dual(_three_arcs(o)((0.0, 2.0), 1.0, P0_440), o, :xcon)
            for t in (0.5, 1.2, 1.8)
                Test.@test d(t) ≈ dp(t) atol = 1e-10
            end
            # the control box, adjoined in no phase, stays unknown
            Test.@test_throws Exceptions.PreconditionError CTModels.dual(sol, ocp, :ubox)
        end

        Test.@testset "a control box given to a single flow: its dual" begin
            ocp = _issue440_box()
            f = Flows.Flow(ocp, (x, p) -> 1; multipliers=:ubox => _const(0.4), OPTS...)
            sol = f((0.0, 1.0), 1.0, 0.0)
            Test.@test CTModels.dual(sol, ocp, :ubox)(0.5) ≈ 0.4
            Test.@test_throws Exceptions.PreconditionError CTModels.dual(sol, ocp, :xbox)
        end

        # ====================================================================
        # INTEGRATION TESTS - sign of the dual on each kind of row
        # ====================================================================

        Test.@testset "the dual is the multiplier, with its sign" begin
            f(ocp, y) = Flows.Flow(ocp, (x, p) -> 0; multipliers=:c => _const(y), OPTS...)
            # one finite bound: y ≥ 0, either way
            o = _scalar(0.1, Inf)
            Test.@test _dual(o, f(o, 0.7), :c)(0.5) ≈ 0.7
            o = _scalar(-Inf, 0.9)
            Test.@test _dual(o, f(o, 0.7), :c)(0.5) ≈ 0.7
            # equality and two finite bounds: y < 0 on the lower bound, y > 0 on the upper
            for (lb, ub) in ((0.5, 0.5), (0.0, 1.0))
                o = _scalar(lb, ub)
                Test.@test _dual(o, f(o, -0.7), :c)(0.5) ≈ -0.7
                Test.@test _dual(o, f(o, 0.7), :c)(0.5) ≈ 0.7
            end
        end

        Test.@testset "vector constraint and tuple of constraints" begin
            ocp = _vector([0.0, -Inf], [1.0, 2.0])
            x0, p0 = [0.5, 0.5], [0.0, 0.0]
            # :c, one dual per component; the rows of :s stay 0
            f = Flows.Flow(ocp, (x, p) -> 0; multipliers=:c => _const([0.3, 0.4]), OPTS...)
            sol = f((0.0, 1.0), x0, p0)
            Test.@test CTModels.dual(sol, ocp, :c)(0.5) ≈ [0.3, 0.4]   # two-sided, then one-sided
            Test.@test CTModels.dual(sol, ocp, :s)(0.5) == 0.0
            f = Flows.Flow(ocp, (x, p) -> 0; multipliers=:c => _const([-0.3, 0.4]), OPTS...)
            Test.@test CTModels.dual(f((0.0, 1.0), x0, p0), ocp, :c)(0.5) ≈ [-0.3, 0.4]
            # a tuple of labelled constraints
            f = Flows.Flow(
                ocp,
                (x, p) -> -1;
                multipliers=(:s => _const(0.2), :c => _const([0.3, 0.4])),
                OPTS...,
            )
            sol = f((0.0, 1.0), x0, p0)
            Test.@test CTModels.dual(sol, ocp, :s)(0.5) ≈ 0.2
            Test.@test CTModels.dual(sol, ocp, :c)(0.5) ≈ [0.3, 0.4]
        end

        Test.@testset "two phases, one constraint active on each" begin
            ocp = _vector([0.0, -Inf], [1.0, 2.0])
            # phase 1: u ≥ -1 active (:s); phase 2: x₁ ≤ 1 active (:c, first row)
            f1 = Flows.Flow(ocp, (x, p) -> -1; multipliers=:s => _const(0.2), OPTS...)
            f2 = Flows.Flow(ocp, (x, p) -> 0; multipliers=:c => _const([0.3, 0.0]), OPTS...)
            sol = (f1 * (0.5, f2))((0.0, 1.0), [1.5, 0.5], [0.0, 0.0])
            ds, dc = CTModels.dual(sol, ocp, :s), CTModels.dual(sol, ocp, :c)
            Test.@test ds(0.25) ≈ 0.2
            Test.@test dc(0.25) == [0.0, 0.0]
            Test.@test ds(0.75) == 0.0
            Test.@test dc(0.75) ≈ [0.3, 0.0]
            # at the switching time: the left limit (first phase), and both limits stored
            Test.@test ds(0.5) ≈ 0.2
            Test.@test CTModels.left_limit(sol, :path_dual, 1) ≈ [0.0, 0.0, 0.2]
            Test.@test CTModels.right_limit(sol, :path_dual, 1) ≈ [0.3, 0.0, 0.0]
        end

        # ====================================================================
        # INTEGRATION TESTS - no constraint, or no label
        # ====================================================================

        Test.@testset "no constraint: the duals are 0 on the arc" begin
            ocp = _mixed()
            sol = Flows.Flow(ocp, (x, p) -> 0.0; OPTS...)((0.0, 1.0), -1.0, 0.0)
            Test.@test CTModels.Solutions.has_duals(sol)
            Test.@test CTModels.dual(sol, ocp, :mixed)(0.5) == 0.0
        end

        Test.@testset "a constraint without label: no dual" begin
            ocp = _mixed()
            f = Flows.Flow(
                ocp,
                (x, p) -> -x;
                multipliers=((x, u) -> x + u) => ((x, p) -> -1 - p),
                OPTS...,
            )
            sol = f((0.0, 1.0), -1.0, P0_MIXED)
            Test.@test !CTModels.Solutions.has_duals(sol)
            Test.@test_throws Exceptions.PreconditionError CTModels.dual(sol, ocp, :mixed)
            err = try
                CTModels.dual(sol, ocp, :mixed)
            catch e
                e
            end
            Test.@test occursin("has no label", err.suggestion)
            Test.@test occursin("multipliers=:label => y", err.suggestion)
            # the flow warns when it is built, and names the labels of the problem
            Test.@test_logs (:warn, r"multipliers=:dummy => y.*:dummy, :mixed") Flows.Flow(
                ocp,
                (x, p) -> -x;
                multipliers=((x, u) -> x + u) => ((x, p) -> -1 - p),
                OPTS...,
            )
            # no warning for a labelled constraint, nor for a problem with no path constraint
            Test.@test_logs Flows.Flow(
                ocp, (x, p) -> -x; multipliers=:mixed => ((x, p) -> p + 1), OPTS...
            )
            # a tuple mixing a label and a function is rejected
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(
                ocp,
                (x, p) -> -x;
                multipliers=(:mixed => ((x, p) -> p + 1), ((x, u) -> x) => _const(0.0)),
                OPTS...,
            )
            # one unlabelled phase in a multi-phase flow: no dual for the whole solution
            o = _issue440(SPELLINGS[1][2:4]...)
            sol = _three_arcs(o; constraint=(x, u) -> x - LB)((0.0, 2.0), 1.0, P0_440)
            Test.@test !CTModels.Solutions.has_duals(sol)
        end

        Test.@testset "the flow keeps its duals through with_label" begin
            ocp = _mixed()
            f = Flows.Flow(
                ocp, (x, p) -> -x; multipliers=:mixed => ((x, p) -> p + 1), OPTS...
            )
            g = Flows.with_label(f, "boundary")
            Test.@test g.duals === f.duals
            Test.@test Flows._flow_duals(ocp, nothing, nothing) isa Flows._FlowDuals
        end
    end
end

end # module TestFlowDuals

test_flow_duals() = TestFlowDuals.test_flow_duals()
