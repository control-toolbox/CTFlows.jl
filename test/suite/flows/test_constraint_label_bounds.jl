"""
`Flow(ocp, law; constraint=:label, …)` normalises the path constraint from its bounds
(issue #440).

The model stores `lb ≤ c(t,x,u,v) ≤ ub`; the flow needs `g ≥ 0`, adjoined as `+μ g` with
`μ ≥ 0`: `g = c - lb` for a lower bound, `g = ub - c` for an upper bound, `g = c - lb` for
an equality. A two-sided constraint needs its active side, `:label => :lower` / `:upper`.

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
        pre, :path; f=(r, t, x, u, v) -> (r .= x; nothing), lb=lb, ub=ub, label=:c
    )
    return CTModels.Building.build(pre)
end

# the resolved g, called uniformly as g(t, x, u, v)
_g(ocp, spec) = Flows._resolve_constraint(ocp, spec)
_ev(g, x) = g(0.0, x, 0.0, Float64[])

const μ = (x, p) -> 2x

function test_constraint_label_bounds()
    Test.@testset "constraint=:label bounds (issue #440)" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # the normalised g
        # ====================================================================

        Test.@testset "g ≥ 0 from the bounds [$name]" for (name, f!, lb, ub) in SPELLINGS
            g = _g(_ocp((f!, lb, ub, :xcon)), :xcon)
            Test.@test _ev(g, LB) ≈ 0 atol = 1e-15     # on the boundary
            Test.@test _ev(g, 0.5) ≈ 0.4                # inside: g > 0
            Test.@test _ev(g, 0.0) ≈ -0.1               # outside: g < 0
        end

        Test.@testset "upper bound: g = ub - c" begin
            ocp = _ocp(((r, t, x, u, v) -> (r[1]=2x; nothing), -Inf, 1.0, :up))
            g = _g(ocp, :up)
            Test.@test _ev(g, 0.25) ≈ 0.5
            Test.@test _ev(g, 0.5) ≈ 0.0 atol = 1e-15
        end

        Test.@testset "equality: g = c - lb" begin
            ocp = _ocp(((r, t, x, u, v) -> (r[1]=x; nothing), 0.3, 0.3, :eq))
            Test.@test _ev(_g(ocp, :eq), 0.5) ≈ 0.2
            Test.@test _ev(_g(ocp, :eq => :upper), 0.5) ≈ -0.2
        end

        Test.@testset "two-sided: the side is required" begin
            ocp = _ocp(((r, t, x, u, v) -> (r[1]=x; nothing), 0.1, 0.9, :box))
            Test.@test_throws Exceptions.IncorrectArgument _g(ocp, :box)
            err = try
                _g(ocp, :box)
            catch e
                e
            end
            Test.@test occursin(":box => :lower", err.suggestion)
            Test.@test _ev(_g(ocp, :box => :lower), 0.5) ≈ 0.4
            Test.@test _ev(_g(ocp, :box => :upper), 0.5) ≈ 0.4
            Test.@test _ev(_g(ocp, :box => :upper), 0.8) ≈ 0.1
        end

        Test.@testset "Error: invalid side" begin
            ocp = _ocp(((r, t, x, u, v) -> (r[1]=x; nothing), LB, Inf, :xcon))
            Test.@test_throws Exceptions.IncorrectArgument _g(ocp, :xcon => :upper)  # ub = Inf
            Test.@test_throws Exceptions.IncorrectArgument _g(ocp, :xcon => :left)
            Test.@test_throws Exceptions.IncorrectArgument _g(ocp, :xcon => 1)
            Test.@test_throws Exceptions.IncorrectArgument _g(
                ocp, :xcon => (:lower, :lower)
            )
            Test.@test _ev(_g(ocp, :xcon => :lower), 0.5) ≈ 0.4
            Test.@test _ev(_g(ocp, :xcon => (:lower,)), 0.5) ≈ 0.4
        end

        Test.@testset "vector constraint: one side per component" begin
            x = [0.5, 0.2]
            # x₁ ≥ 0.1 and x₂ ≤ 0.6: inferred
            g = _g(_ocp2([0.1, -Inf], [Inf, 0.6]), :c)
            Test.@test _ev(g, x) ≈ [0.4, 0.4]
            # both two-sided: sides required, one per component
            ocp = _ocp2([0.1, 0.0], [0.9, 0.6])
            Test.@test_throws Exceptions.IncorrectArgument _g(ocp, :c)
            Test.@test _ev(_g(ocp, :c => (:lower, :upper)), x) ≈ [0.4, 0.4]
            Test.@test _ev(_g(ocp, :c => [:upper, :lower]), x) ≈ [0.4, 0.2]
            Test.@test _ev(_g(ocp, :c => :lower), x) ≈ [0.4, 0.2]
            Test.@test_throws Exceptions.IncorrectArgument _g(ocp, :c => (:lower,))
        end

        Test.@testset "tuple of labels and sides" begin
            ocp = _ocp(
                ((r, t, x, u, v) -> (r[1]=x; nothing), LB, Inf, :lo),
                ((r, t, x, u, v) -> (r[1]=x; nothing), 0.0, 0.9, :box),
            )
            g = _g(ocp, (:lo, :box => :upper))
            Test.@test _ev(g, 0.5) ≈ [0.4, 0.4]
        end

        # ====================================================================
        # the issue: the boundary arc, and the three arcs
        # ====================================================================

        Test.@testset "boundary arc [$name, $ht]" for (name, f!, lb, ub) in SPELLINGS,
            ht in (:total, :partial)

            ocp = _ocp((f!, lb, ub, :xcon))
            f_sym = Flows.Flow(
                ocp, (x, p) -> 0; constraint=:xcon, multiplier=μ, hamiltonian_type=ht, _opts()...
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
            Test.@test all(isapprox.(f_sym(0.9, LB, 0.0, 1.6), f_fun(0.9, LB, 0.0, 1.6); atol=ATOL))
        end

        Test.@testset "three arcs [$name]" for (name, f!, lb, ub) in SPELLINGS
            ocp = _ocp((f!, lb, ub, :xcon))
            f_minus = Flows.Flow(ocp, (x, p) -> -1; _opts()...)
            f_bound = Flows.Flow(ocp, (x, p) -> 0; constraint=:xcon, multiplier=μ, _opts()...)
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
