"""
Tests for the arity-checking guard on the OCP convenience constructors:
`Flow(ocp, u::Function)` and the raw-`Function` `constraint`/`multiplier` specs.
"""

module TestConvenienceArity

using Test: Test
import CTBase.Data: Data
import CTBase.Exceptions: Exceptions
import CTModels: CTModels
import CTFlows.Flows: Flows
using OrdinaryDiffEqTsit5: Tsit5
using ForwardDiff: ForwardDiff  # triggers the DI ForwardDiff extension (AutoForwardDiff)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

_opts() = (; alg=Tsit5(), reltol=1e-10, abstol=1e-10)

# =============================================================================
# OCP fixtures at module top-level
# =============================================================================

# scalar LQR: ẋ = -x + u, ℓ = 0.5u², :min  (autonomous, fixed) — expected natural arity 2
function _build_lqr()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=(-x + u); nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    return CTModels.Building.build(pre)
end

# non-autonomous: ẋ = u(1 + tan t), ℓ = 0.5u², :min  (non-autonomous, fixed) — expected arity 3
function _build_nonauton()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=false)
    CTModels.Building.time!(pre; t0=0.0, tf=π / 4)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=u * (1 + tan(t)); nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    return CTModels.Building.build(pre)
end

# variable (NonFixed): ẋ = v·(-x) + u, ℓ = 0.5u², :min  (autonomous, non-fixed) — expected arity 3
function _build_variable()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.variable!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=v * (-x) + u; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    return CTModels.Building.build(pre)
end

const OCP_LQR = _build_lqr()
const OCP_NA = _build_nonauton()
const OCP_VAR = _build_variable()

# Fake function with 2 methods (arity 2 and arity 3): ambiguous, the arity check must skip
# it entirely (return no issue) even though the extra method would mismatch OCP_LQR.
_ambiguous_u(x, p) = p
_ambiguous_u(x, p, v) = p

function test_convenience_arity()
    Test.@testset "Convenience-constructor arity checking" verbose = VERBOSE showtiming = SHOWTIMING begin

        # ====================================================================
        # single-issue mismatches
        # ====================================================================

        Test.@testset "control law arity mismatch alone" begin
            bad_u = (t, x, p) -> p  # arity 3, OCP_LQR expects 2
            try
                Flows.Flow(OCP_LQR, bad_u; _opts()...)
                Test.@test false  # should not reach here
            catch err
                Test.@test err isa Exceptions.IncorrectArgument
                msg = sprint(showerror, err)
                Test.@test occursin("control law `u`", msg)
                Test.@test occursin("u(x, p)", msg)
            end
        end

        Test.@testset "constraint arity mismatch alone" begin
            u = (x, p) -> p
            bad_g = (x, u, v) -> x  # arity 3, OCP_LQR expects 2
            μ = (x, p) -> 0.7
            try
                Flows.Flow(OCP_LQR, u; constraint=bad_g, multiplier=μ, _opts()...)
                Test.@test false
            catch err
                Test.@test err isa Exceptions.IncorrectArgument
                # `got` carries only the collected issues — the full showerror message
                # also includes the "use explicit constructors" hint, which necessarily
                # names all three roles regardless of which ones actually mismatched.
                Test.@test occursin("constraint `g`", err.got)
                Test.@test occursin("g(x, u)", err.got)
                Test.@test !occursin("control law", err.got)
                Test.@test !occursin("multiplier", err.got)
            end
        end

        Test.@testset "multiplier arity mismatch alone" begin
            u = (x, p) -> p
            g = (x, u) -> x
            bad_μ = (t, x, p) -> 0.7  # arity 3, OCP_LQR expects 2
            try
                Flows.Flow(OCP_LQR, u; constraint=g, multiplier=bad_μ, _opts()...)
                Test.@test false
            catch err
                Test.@test err isa Exceptions.IncorrectArgument
                Test.@test occursin("multiplier `μ`", err.got)
                Test.@test occursin("μ(x, p)", err.got)
                Test.@test !occursin("control law", err.got)
                Test.@test !occursin("constraint `g`", err.got)
            end
        end

        # ====================================================================
        # combined mismatches — one exception, all issues listed
        # ====================================================================

        Test.@testset "all three mismatched at once — one combined exception" begin
            bad_u = (x, p, v) -> p    # arity 3, expected 2
            bad_g = (t, x, u) -> x    # arity 3, expected 2
            bad_μ = (x, p, v) -> 0.7  # arity 3, expected 2
            try
                Flows.Flow(OCP_LQR, bad_u; constraint=bad_g, multiplier=bad_μ, _opts()...)
                Test.@test false
            catch err
                Test.@test err isa Exceptions.IncorrectArgument
                msg = sprint(showerror, err)
                Test.@test occursin("control law `u`", msg)
                Test.@test occursin("constraint `g`", msg)
                Test.@test occursin("multiplier `μ`", msg)
                Test.@test occursin("3 issue(s)", msg)
            end
        end

        Test.@testset "Tuple constraint spec: only the bad element is named" begin
            u = (x, p) -> p
            g1 = (x, u) -> x        # correct arity 2
            g2 = (x, u, v) -> x     # wrong arity 3
            μ1 = (x, p) -> 0.5
            μ2 = (x, p) -> 0.5
            try
                Flows.Flow(
                    OCP_LQR, u; constraint=(g1, g2), multiplier=(μ1, μ2), _opts()...
                )
                Test.@test false
            catch err
                Test.@test err isa Exceptions.IncorrectArgument
                # label includes the tuple index, e.g. "constraint #2 `g2` has arity ..."
                Test.@test occursin("`g2`", err.got)
                Test.@test !occursin("`g1`", err.got)
            end
        end

        # ====================================================================
        # positive controls — matching arity never throws
        # ====================================================================

        Test.@testset "correct arity — no throw, integrates normally" begin
            u = (x, p) -> p
            g = (x, u) -> x
            μ = (x, p) -> 0.7
            f = Flows.Flow(OCP_LQR, u; constraint=g, multiplier=μ, _opts()...)
            xf, pf = f(0.0, 1.0, 0.5, 1.0)
            Test.@test xf isa Number
            Test.@test pf isa Number
        end

        Test.@testset "non-autonomous / variable OCPs: matching arity does not throw" begin
            un = (t, x, p) -> p * (1 + tan(t))
            fn = Flows.Flow(OCP_NA, un; _opts()...)
            Test.@test fn isa Flows.OptimalControlFlow

            uv = (x, p, v) -> p
            fv = Flows.Flow(OCP_VAR, uv; _opts()...)
            xv, pv = fv(0.0, 1.0, 0.5, 1.0; variable=0.5)
            Test.@test xv isa Number
        end

        Test.@testset "ambiguous function (2+ methods) — silently skipped" begin
            # _ambiguous_u has 2 methods; the check cannot tell which arity the user
            # means, so it is skipped — Julia's own dispatch picks the (x, p) method at
            # call time, and the flow integrates normally with no throw.
            f = Flows.Flow(OCP_LQR, _ambiguous_u; _opts()...)
            xf, pf = f(0.0, 1.0, 0.5, 1.0)
            fref = Flows.Flow(OCP_LQR, Data.DynClosedLoop((x, p) -> p); _opts()...)
            xr, pr = fref(0.0, 1.0, 0.5, 1.0)
            Test.@test xf ≈ xr atol = 1e-10
            Test.@test pf ≈ pr atol = 1e-10
        end

        # ====================================================================
        # explicit law: only constraint/multiplier are checked, never the law itself
        # ====================================================================

        Test.@testset "explicit law with divergent traits: law arity itself is not checked" begin
            # An explicit DynClosedLoop built with is_autonomous=false on an autonomous OCP
            # is a deliberate trait override — the check only applies to the raw `u` passed
            # to the Flow(ocp, u::Function) convenience, not to an already-built law.
            law = Data.DynClosedLoop((t, x, p) -> p; is_autonomous=false)
            f = Flows.Flow(OCP_LQR, law; _opts()...)
            Test.@test f isa Flows.OptimalControlFlow

            # but a convenience constraint mismatch alongside it is still caught
            bad_g = (t, x, u, v) -> x  # arity 4, OCP_LQR expects 2
            μ = (x, p) -> 0.7
            try
                Flows.Flow(OCP_LQR, law; constraint=bad_g, multiplier=μ, _opts()...)
                Test.@test false
            catch err
                Test.@test err isa Exceptions.IncorrectArgument
                Test.@test occursin("constraint `g`", sprint(showerror, err))
            end
        end
    end
end

end # module

test_convenience_arity() = TestConvenienceArity.test_convenience_arity()
