"""
`Flow(ocp, law; constraint=:label, multiplier=y)` adjoins the constraint from its bounds,
with `y` the dual of the solution (issue #440, control-toolbox/CTModels.jl#536).

The model stores `lb ≤ c(t,x,u,v) ≤ ub`; the term adjoined to the pseudo-Hamiltonian is, in
the dual convention (ct-conventions `SGN2`, `SGN3`): `y (c - lb)` for a lower bound only,
`y (ub - c)` for an upper bound only, `-y (c - b)` for two bounds or an equality, with
`b = ub` if `y > 0` and `b = lb` otherwise. The sign of `y` carries the active side; the
former `:label => :side` is rejected. A state box gives the same term as the equivalent
path constraint (`SGN5`).

Issue example (Bonnard, Faubourg, Launay & Trélat 2003): ẋ = u, |u| ≤ 1, x ≥ lb = 0.1,
∫₀² x² → min, x(0) = 1, x(2) = 1/2. On the boundary arc [0.9, 1.6], u = 0 and μ = 2x, so
ṗ = 2x - (2g + 2x) = 0 at x = lb: p stays 0.
"""

module TestConstraintLabelBounds

using Test: Test
using CTBase: Data
using CTBase: Exceptions
using CTModels: CTModels
using CTFlows: Flows
using CTFlows: Systems
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5  # SciML integrator for Flow(...)
using ForwardDiff: ForwardDiff  # triggers the DI ForwardDiff extension (AutoForwardDiff)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const LB = 0.1
const ATOL = 1e-8
_opts() = (; reltol=1e-10, abstol=1e-10)

# ── models ───────────────────────────────────────────────────────────────────

"""Issue model: ẋ = u, ∫ x² → min, with the path constraints `cons = [(f!, lb, ub, label)]`."""
function _ocp(cons...)
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=2.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=u; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> x^2)
    for (f!, lb, ub, label) in cons
        CTModels.Building.constraint!(pre, :path; f=f!, lb=lb, ub=ub, label=label)
    end
    return CTModels.Building.build(pre)
end

# x ≥ lb, written three ways (the issue's table)
const SPELLINGS = (
    ("x - lb ≥ 0", (r, t, x, u, v) -> (r[1]=x - LB; nothing), 0.0, Inf),
    ("x + 0 ≥ lb", (r, t, x, u, v) -> (r[1]=x; nothing), LB, Inf),
    ("lb - x ≤ 0", (r, t, x, u, v) -> (r[1]=LB - x; nothing), -Inf, 0.0),
)

"""Issue model with the state constraint `x ≥ lb` written as a state box `:xbox`."""
function _ocp_box()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=2.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=u; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> x^2)
    CTModels.Building.constraint!(pre, :state; rg=1:1, lb=[LB], ub=[Inf], label=:xbox)
    return CTModels.Building.build(pre)
end

"""Two-dimensional state, one 2-D path constraint `:c` = (x₁, x₂) with bounds `lb`, `ub`."""
function _ocp2(lb, ub)
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=x[2]; r[2]=u; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    CTModels.Building.constraint!(
        pre, :path; f=(r, t, x, u, v) -> (r.=x; nothing), lb=lb, ub=ub, label=:c
    )
    return CTModels.Building.build(pre)
end

# The term adjoined for the labels `spec` with the dual `y`, at the state `x`: the
# constrained pseudo-Hamiltonian of the flow at p = 0, u = 0, minus its value at y = 0.
function _term(ocp, spec, x, y)
    f = Flows.Flow(ocp, (x, p) -> 0.0; constraint=spec, multiplier=_y0(spec), _opts()...)
    H = Systems.pseudo_hamiltonian(f)
    p0 = zero(x)
    return H(x, p0, 0.0, y) - H(x, p0, 0.0, zero(y))
end
_y0(::Symbol) = (x, p) -> 0.0
_y0(spec::Tuple) = map(_ -> (x, p) -> 0.0, spec)

const μ = (x, p) -> 2x

function test_constraint_label_bounds()
    Test.@testset "constraint=:label bounds (issue #440)" verbose = VERBOSE showtiming =
        SHOWTIMING begin

        # ====================================================================
        # the term of each kind of constraint, in the dual convention
        # ====================================================================

        Test.@testset "x ≥ lb written three ways, and as a state box: one term" begin
            for (name, f!, lb, ub) in SPELLINGS
                ocp = _ocp((f!, lb, ub, :xcon))
                Test.@test _term(ocp, :xcon, 0.5, 2.0) ≈ 2.0 * (0.5 - LB)   # y (x - lb)
            end
            Test.@test _term(_ocp_box(), :xbox, 0.5, 2.0) ≈ 2.0 * (0.5 - LB)
        end

        Test.@testset "upper bound only: y (ub - c)" begin
            ocp = _ocp(((r, t, x, u, v) -> (r[1]=2x; nothing), -Inf, 1.0, :up))
            Test.@test _term(ocp, :up, 0.25, 3.0) ≈ 3.0 * (1.0 - 0.5)
        end

        Test.@testset "equality: -y (c - b), either sign of y" begin
            ocp = _ocp(((r, t, x, u, v) -> (r[1]=x; nothing), 0.3, 0.3, :eq))
            Test.@test _term(ocp, :eq, 0.5, 2.0) ≈ -2.0 * 0.2
            Test.@test _term(ocp, :eq, 0.5, -2.0) ≈ 2.0 * 0.2
        end

        Test.@testset "two-sided: the sign of y gives the active bound" begin
            ocp = _ocp(((r, t, x, u, v) -> (r[1]=x; nothing), 0.1, 0.9, :box))
            Test.@test _term(ocp, :box, 0.5, -2.0) ≈ 2.0 * (0.5 - 0.1)   # lower: y < 0
            Test.@test _term(ocp, :box, 0.5, 2.0) ≈ 2.0 * (0.9 - 0.5)    # upper: y > 0
            Test.@test _term(ocp, :box, 0.5, 0.0) == 0.0
        end

        Test.@testset "vector constraint: one dual per component" begin
            x = [0.5, 0.2]
            ocp = _ocp2([0.1, -Inf], [Inf, 0.6])
            Test.@test _term(ocp, :c, x, [2.0, 3.0]) ≈ 2.0 * 0.4 + 3.0 * 0.4
            ocp = _ocp2([0.1, 0.0], [0.9, 0.6])
            Test.@test _term(ocp, :c, x, [-2.0, 3.0]) ≈ 2.0 * 0.4 + 3.0 * 0.4
        end

        Test.@testset "tuple of labels: the duals stacked in their order" begin
            ocp = _ocp(
                ((r, t, x, u, v) -> (r[1]=x; nothing), LB, Inf, :lo),
                ((r, t, x, u, v) -> (r[1]=x; nothing), 0.0, 0.9, :box),
            )
            Test.@test _term(ocp, (:lo, :box), 0.5, [2.0, 3.0]) ≈ 2.0 * 0.4 + 3.0 * 0.4
        end

        Test.@testset "Error: the former label => side" begin
            ocp = _ocp(((r, t, x, u, v) -> (r[1]=x; nothing), 0.1, 0.9, :box))
            spec = :box => :lower
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(
                ocp, (x, p) -> 0.0; constraint=spec, multiplier=μ, _opts()...
            )
            err = try
                Flows.Flow(ocp, (x, p) -> 0.0; constraint=spec, multiplier=μ, _opts()...)
            catch e
                e
            end
            Test.@test occursin("y = -μ", err.suggestion)
        end

        Test.@testset "Error: a tuple mixing labels and functions" begin
            ocp = _ocp(((r, t, x, u, v) -> (r[1]=x; nothing), LB, Inf, :xcon))
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(
                ocp,
                (x, p) -> 0.0;
                constraint=(:xcon, (x, u) -> x),
                multiplier=(μ, μ),
                _opts()...,
            )
        end

        # ====================================================================
        # the issue: the boundary arc, and the three arcs
        # ====================================================================

        Test.@testset "boundary arc [$name, $ht]" for (name, f!, lb, ub) in SPELLINGS,
            ht in (:total, :partial)

            ocp = _ocp((f!, lb, ub, :xcon))
            f_sym = Flows.Flow(
                ocp,
                (x, p) -> 0;
                constraint=:xcon,
                multiplier=μ,
                hamiltonian_type=ht,
                _opts()...,
            )
            f_fun = Flows.Flow(
                ocp,
                (x, p) -> 0;
                constraint=(x, u) -> x - LB,
                multiplier=μ,
                hamiltonian_type=ht,
                _opts()...,
            )
            x2, p2 = f_sym(0.9, LB, 0.0, 1.6)
            Test.@test x2 ≈ LB atol = ATOL
            Test.@test p2 ≈ 0.0 atol = ATOL
            Test.@test all(
                isapprox.(f_sym(0.9, LB, 0.0, 1.6), f_fun(0.9, LB, 0.0, 1.6); atol=ATOL)
            )
        end

        Test.@testset "boundary arc with the state box [$ht]" for ht in (:total, :partial)
            f = Flows.Flow(
                _ocp_box(),
                (x, p) -> 0;
                constraint=:xbox,
                multiplier=μ,
                hamiltonian_type=ht,
                _opts()...,
            )
            x2, p2 = f(0.9, LB, 0.0, 1.6)
            Test.@test x2 ≈ LB atol = ATOL
            Test.@test p2 ≈ 0.0 atol = ATOL
        end

        Test.@testset "three arcs [$name]" for (name, f!, lb, ub) in SPELLINGS
            ocp = _ocp((f!, lb, ub, :xcon))
            f_minus = Flows.Flow(ocp, (x, p) -> -1; _opts()...)
            f_bound = Flows.Flow(
                ocp, (x, p) -> 0; constraint=:xcon, multiplier=μ, _opts()...
            )
            f_plus = Flows.Flow(ocp, (x, p) -> 1; _opts()...)
            φ = f_minus * (0.9, f_bound) * (1.6, f_plus)
            xf, pf = φ(0.0, 1.0, -0.982237546583301, 2.0)
            Test.@test xf ≈ 0.5 atol = 1e-8
            Test.@test pf ≈ 0.2478 atol = 1e-4
        end
    end
end

end # module

test_constraint_label_bounds() = TestConstraintLabelBounds.test_constraint_label_bounds()
