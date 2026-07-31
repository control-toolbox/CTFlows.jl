"""
End-to-end integration test for the simple-exponential CONSUMPTION problem
(bang-off-bang, 2 arcs): `ẋ = -x + u`, `x(0) = -1`, `x(1) = 0`, `|u| ≤ 1`,
minimise `∫ |u| dt`, `tf = 1` fixed.

Multi-arc shooting (fixed tf, 2 equations, 2 unknowns `[p0, t1]`).
Structure "0B+": u=0 on `[0, t1]`, u=+1 on `[t1, 1]`.
Closed-form: `p0 = 1/(e-1)`, `t1 = log(e-1)`.
Switching condition: `p(t1) = 1` (p crosses +1 ⇒ u switches 0 → +1).

The control is constant on each arc (0, +1), so `:total` and `:partial` coincide
— asserted for both. Multi-phase reconstruction validated via `*` composition.
"""
module TestSimpleExponentialConsumption

using Test: Test
using CTModels: CTModels
using CTFlows: Flows
using OrdinaryDiffEqTsit5
using ForwardDiff: ForwardDiff
using NonlinearSolve: NonlinearProblem, SimpleNewtonRaphson, solve

include(joinpath(@__DIR__, "..", "..", "suite", "integration", "utils.jl"))

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const _T0 = 0.0
const _TF = 1.0
const _X0 = -1.0
const _XF = 0.0

# Closed form: p0 = 1/(e-1), t1 = log(e-1).
const _P0_SOL = 1.0 / (ℯ - 1.0)
const _T1_SOL = log(ℯ - 1.0)

function _build_simple_exponential_consumption()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=_T0, tf=_TF)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=(-x[1] + u[1]); nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> abs(u[1]))
    return CTModels.Building.build(pre)
end

function test_simple_exponential_consumption()
    Test.@testset "Simple exponential — consumption 0B+ (:total/:partial)" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = _build_simple_exponential_consumption()

        for ht in (:total, :partial)
            # Off arc: u=0; bang+ arc: u=+1.
            # Autonomous + fixed ⇒ arity (x, p).
            f_off = Flows.Flow(
                ocp,
                (x, p) -> 0.0;
                hamiltonian_type=ht,
                alg=Tsit5(),
                reltol=1e-12,
                abstol=1e-12,
            )
            f_plus = Flows.Flow(
                ocp,
                (x, p) -> 1.0;
                hamiltonian_type=ht,
                alg=Tsit5(),
                reltol=1e-12,
                abstol=1e-12,
            )

            function shoot!(s, ξ)
                p0, t1 = ξ[1], ξ[2]
                x1, p1 = f_off(_T0, _X0, p0, t1)
                xf, _ = f_plus(t1, x1, p1, _TF)
                s[1] = xf - _XF          # x(tf) = 0
                s[2] = p1 - 1.0          # switching: p(t1) = 1
                return nothing
            end

            ξ_exact = [_P0_SOL, _T1_SOL]
            ξ_guess = [0.5, 0.6]
            ξ_opt = test_shooting(shoot!, ξ_exact, ξ_guess; atol=1e-8)

            Test.@test isapprox(ξ_opt[1], _P0_SOL; atol=1e-6)
            Test.@test isapprox(ξ_opt[2], _T1_SOL; atol=1e-6)

            # Multi-phase reconstruction (:total only).
            if ht == :total
                φ = f_off * (_T1_SOL, f_plus)
                sol = φ((_T0, _TF), _X0, _P0_SOL)
                Test.@test sol isa CTModels.Solutions.Solution
            end
        end
    end
end

end # module

function test_simple_exponential_consumption()
    return TestSimpleExponentialConsumption.test_simple_exponential_consumption()
end
