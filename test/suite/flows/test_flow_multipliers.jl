"""
The keyword `multipliers` of `Flow(ocp, law)` (issue #543): the constraints active on an arc,
each with its multiplier in feedback form, as `constraint => multiplier` pairs, the shape
`CTModels.Models.hamiltonian(ocp, u; multipliers)` takes. The former keywords `constraint`
and `multiplier` are rejected with the rewrite.
"""
module TestFlowMultipliers

using Test: Test
using CTBase: Data
using CTBase: Exceptions
using CTModels: CTModels
using CTFlows: Flows
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5  # SciML integrator for Flow(...)
using ForwardDiff: ForwardDiff  # triggers the DI ForwardDiff extension (AutoForwardDiff)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const OPTS = (; reltol=1e-10, abstol=1e-10)

# ── models ───────────────────────────────────────────────────────────────────

"""`ẋ = u`, `∫ x² → min` on `[0, 2]`, with `x - 0.1 ≥ 0` (label `:xcon`) and `|u| ≤ 1` (`:ubox`)."""
function _ocp()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=2.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=u; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> x^2)
    CTModels.Building.constraint!(
        pre, :path; f=(r, t, x, u, v) -> (r[1]=x - 0.1; nothing), lb=0.0, ub=Inf, label=:xcon
    )
    CTModels.Building.constraint!(pre, :control; rg=1:1, lb=[-1.0], ub=[1.0], label=:ubox)
    return CTModels.Building.build(pre)
end

# A law that is not stationary, and multipliers that depend on the state and the costate,
# so that every term of the Hamiltonian shows in the extremal.
const LAW = (x, p) -> 0.5 * p
const MU_X = (x, p) -> 2x
const MU_U = (x, p) -> 0.3 + p

_point(f) = f(0.0, 1.0, -0.4, 1.0)

# ── tests ────────────────────────────────────────────────────────────────────

function test_flow_multipliers()
    Test.@testset "Flow multipliers" verbose = VERBOSE showtiming = SHOWTIMING begin
        ocp = _ocp()
        g(x, u) = x - 0.1
        μ(x, p) = 2x

        # ====================================================================
        # UNIT TESTS - _multiplier_specs
        # ====================================================================

        Test.@testset "Unit: no constraint" begin
            Test.@test Flows._multiplier_specs(nothing) == (nothing, nothing)
            Test.@test Flows._multiplier_specs(()) == (nothing, nothing)
            Test.@test Flows._multiplier_specs(Pair[]) == (nothing, nothing)
            Test.@test Flows._multiplier_specs((;)) == (nothing, nothing)
            Test.@test Flows._multiplier_specs(Dict{Symbol,Any}()) == (nothing, nothing)
        end

        Test.@testset "Unit: one pair, in every container" begin
            Test.@test Flows._multiplier_specs(:a => μ) == (:a, μ)
            Test.@test Flows._multiplier_specs((:a => μ,)) == (:a, μ)
            Test.@test Flows._multiplier_specs([:a => μ]) == (:a, μ)
            Test.@test Flows._multiplier_specs((; a=μ)) == (:a, μ)
            Test.@test Flows._multiplier_specs(Dict(:a => μ)) == (:a, μ)
            Test.@test Flows._multiplier_specs(g => μ) == (g, μ)
        end

        Test.@testset "Unit: several pairs, element-wise" begin
            Test.@test Flows._multiplier_specs((:a => MU_X, :b => MU_U)) ==
                ((:a, :b), (MU_X, MU_U))
            Test.@test Flows._multiplier_specs([:a => MU_X, :b => MU_U]) ==
                ((:a, :b), (MU_X, MU_U))
            Test.@test Flows._multiplier_specs((; a=MU_X, b=MU_U)) == ((:a, :b), (MU_X, MU_U))
            cs, ms = Flows._multiplier_specs(Dict(:a => MU_X, :b => MU_U))
            Test.@test Set(zip(cs, ms)) == Set([(:a, MU_X), (:b, MU_U)])
        end

        Test.@testset "Unit: not pairs, or a constraint twice" begin
            Test.@test_throws Exceptions.IncorrectArgument Flows._multiplier_specs(:a)
            Test.@test_throws Exceptions.IncorrectArgument Flows._multiplier_specs(μ)
            Test.@test_throws Exceptions.IncorrectArgument Flows._multiplier_specs(
                (:a => μ, :b)
            )
            Test.@test_throws Exceptions.IncorrectArgument Flows._multiplier_specs(
                (:a => μ, :a => μ)
            )
            err = try
                Flows._multiplier_specs((:a => μ, :b))
            catch e
                e
            end
            Test.@test occursin("element 2", err.got)
            Test.@test occursin("multipliers=", err.suggestion)
            err = try
                Flows._multiplier_specs((g => μ, g => MU_U))
            catch e
                e
            end
            Test.@test occursin("twice", err.msg)
        end

        # ====================================================================
        # INTEGRATION - the containers give the same flow
        # ====================================================================

        Test.@testset "Integration: one label, every container" begin
            ref = _point(Flows.Flow(ocp, LAW; multipliers=:xcon => MU_X, OPTS...))
            for m in ((:xcon => MU_X,), [:xcon => MU_X], (; xcon=MU_X), Dict(:xcon => MU_X))
                Test.@test all(_point(Flows.Flow(ocp, LAW; multipliers=m, OPTS...)) .≈ ref)
            end
            # an explicit law takes the same keyword
            fl = Flows.Flow(ocp, Data.DynClosedLoop(LAW); multipliers=:xcon => MU_X, OPTS...)
            Test.@test all(_point(fl) .≈ ref)
        end

        Test.@testset "Integration: two labels, in any order" begin
            ref = _point(
                Flows.Flow(ocp, LAW; multipliers=(:xcon => MU_X, :ubox => MU_U), OPTS...)
            )
            for m in (
                (:ubox => MU_U, :xcon => MU_X),
                (; xcon=MU_X, ubox=MU_U),
                Dict(:xcon => MU_X, :ubox => MU_U),
            )
                Test.@test all(_point(Flows.Flow(ocp, LAW; multipliers=m, OPTS...)) .≈ ref)
            end
        end

        Test.@testset "Integration: the Hamiltonian is the one of CTModels" begin
            # the same value of `multipliers` given to the flow and to the Hamiltonian of
            # the problem gives the same Hamiltonian
            x, p = 0.7, -0.4
            for m in (:xcon => MU_X, (:xcon => MU_X, :ubox => MU_U), (; xcon=MU_X, ubox=MU_U))
                f = Flows.Flow(ocp, LAW; multipliers=m, OPTS...)
                h = CTModels.Models.hamiltonian(ocp, LAW; multipliers=m)
                Test.@test Data.hamiltonian(f)(x, p) ≈ h(x, p)
            end
        end

        Test.@testset "Integration: a function and a typed constraint" begin
            ref = _point(Flows.Flow(ocp, LAW; multipliers=:xcon => MU_X, OPTS...))
            ff = Flows.Flow(ocp, LAW; multipliers=g => MU_X, OPTS...)
            ft = Flows.Flow(
                ocp, LAW; multipliers=Data.StateConstraint(x -> x - 0.1) => MU_X, OPTS...
            )
            Test.@test all(_point(ff) .≈ ref)
            Test.@test all(_point(ft) .≈ ref)
        end

        # ====================================================================
        # ERROR paths
        # ====================================================================

        Test.@testset "Error: the removed keywords give the rewrite" begin
            for kw in ((; constraint=:xcon, multiplier=MU_X), (; constraint=:xcon), (; multiplier=MU_X))
                err = try
                    Flows.Flow(ocp, LAW; kw..., OPTS...)
                catch e
                    e
                end
                Test.@test err isa Exceptions.IncorrectArgument
                Test.@test occursin("multipliers", err.msg)
                Test.@test occursin("multipliers=", err.suggestion)
            end
            err = try
                Flows.Flow(ocp, LAW; constraint=:xcon, multiplier=MU_X, OPTS...)
            catch e
                e
            end
            Test.@test occursin("multipliers=:xcon => μ", err.suggestion)
            Test.@test occursin("`constraint` and `multiplier`", err.got)
            # with an explicit law too
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(
                ocp, Data.DynClosedLoop(LAW); constraint=:xcon, multiplier=MU_X, OPTS...
            )
        end

        Test.@testset "Error: malformed multipliers" begin
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(
                ocp, LAW; multipliers=:xcon, OPTS...
            )
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(
                ocp, LAW; multipliers=(:xcon => MU_X, :xcon => MU_X), OPTS...
            )
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(
                ocp, LAW; multipliers=:nope => MU_X, OPTS...
            )
        end
    end
end

end # module

test_flow_multipliers() = TestFlowMultipliers.test_flow_multipliers()
