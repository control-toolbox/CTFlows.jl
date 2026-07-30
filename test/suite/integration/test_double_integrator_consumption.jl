"""
End-to-end integration test for the double-integrator CONSUMPTION problem
(bang–off–bang, 3 arcs): `ẋ1 = x2`, `ẋ2 = u`, `x(0) = (-1, 0)`, `x(1) = (0, 0)`,
minimise `∫ |u|` under `|u| ≤ γ = 5`, `tf = 1` fixed. Ported from CTProblems.jl
`DoubleIntegratorConsumption`.

Multi-arc shooting (fixed tf, 4 equations, 4 unknowns `[p10, p20, t1, t2]`).
Closed-form solution `p0 = [2√5, √5]`, `t1 = 0.5 - 0.5/√5`, `t2 = 0.5 + 0.5/√5`.
Switching conditions: `p2(t1) = +1` (bang+ → off), `p2(t2) = -1` (off → bang-).

The control is constant on each arc (bang/off), so `:total` and `:partial` coincide
trivially — asserted for both. Multi-phase reconstruction validated via `*` composition.
"""
module TestDoubleIntegratorConsumption

using Test: Test
using CTModels: CTModels
using CTFlows: Flows
using OrdinaryDiffEqTsit5
using ForwardDiff: ForwardDiff
using NonlinearSolve: NonlinearProblem, SimpleNewtonRaphson, solve

include(joinpath(@__DIR__, "utils.jl"))

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const _T0 = 0.0
const _TF = 1.0
const _X0 = [-1.0, 0.0]
const _XF = [0.0, 0.0]
const _GAMMA = 5.0

# Closed form: p0 = [2√5, √5], t1 = 0.5 - 0.5/√5, t2 = 0.5 + 0.5/√5.
const _SQRT5 = sqrt(5.0)
const _P0_SOL = [2.0 * _SQRT5, _SQRT5]
const _T1_SOL = 0.5 - 0.5 / _SQRT5
const _T2_SOL = 0.5 + 0.5 / _SQRT5

function _build_di_consumption()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=_T0, tf=_TF)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r.=[x[2], u[1]]; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> abs(u[1]))
    return CTModels.Building.build(pre)
end

function test_double_integrator_consumption()
    Test.@testset "Double integrator — consumption bang-off-bang (:total/:partial)" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = _build_di_consumption()

        for ht in (:total, :partial)
            # Bang+ arc: u = +γ; off arc: u = 0; bang- arc: u = -γ.
            # Autonomous + fixed ⇒ arity (x, p).
            f_plus = Flows.Flow(
                ocp,
                (x, p) -> _GAMMA;
                hamiltonian_type=ht,
                alg=Tsit5(),
                reltol=1e-12,
                abstol=1e-12,
            )
            f_off = Flows.Flow(
                ocp,
                (x, p) -> 0.0;
                hamiltonian_type=ht,
                alg=Tsit5(),
                reltol=1e-12,
                abstol=1e-12,
            )
            f_minus = Flows.Flow(
                ocp,
                (x, p) -> -_GAMMA;
                hamiltonian_type=ht,
                alg=Tsit5(),
                reltol=1e-12,
                abstol=1e-12,
            )

            function shoot!(s, ξ)
                p0 = [ξ[1], ξ[2]]
                t1, t2 = ξ[3], ξ[4]
                x1, p1 = f_plus(_T0, _X0, p0, t1)
                x2, p2 = f_off(t1, x1, p1, t2)
                xf, _ = f_minus(t2, x2, p2, _TF)
                s[1:2] .= xf .- _XF
                s[3] = p1[2] - 1.0    # p2(t1) = +1 : switch bang+ → off
                s[4] = p2[2] + 1.0    # p2(t2) = -1 : switch off → bang-
                return nothing
            end

            ξ_exact = [_P0_SOL[1], _P0_SOL[2], _T1_SOL, _T2_SOL]
            ξ_guess = [4.0, 2.0, 0.25, 0.75]
            ξ_opt = test_shooting(shoot!, ξ_exact, ξ_guess; atol=1e-8)

            # Quantitative checks on p0 and switching times.
            Test.@test isapprox(ξ_opt[1], _P0_SOL[1]; atol=1e-5)
            Test.@test isapprox(ξ_opt[2], _P0_SOL[2]; atol=1e-5)
            Test.@test isapprox(ξ_opt[3], _T1_SOL; atol=1e-5)
            Test.@test isapprox(ξ_opt[4], _T2_SOL; atol=1e-5)

            # Multi-phase reconstruction (:total only — avoid redundant 3-arc check).
            if ht == :total
                φ = f_plus * (_T1_SOL, f_off) * (_T2_SOL, f_minus)
                sol = φ((_T0, _TF), _X0, _P0_SOL)
                Test.@test sol isa CTModels.Solutions.Solution

                # Off-arc: u=0 ⇒ x2 constant at x2(t1) = γ*t1.
                t_mid_off = 0.5 * (_T1_SOL + _T2_SOL)
                x1_at_t1, p1_at_t1 = f_plus(_T0, _X0, _P0_SOL, _T1_SOL)
                x_mid, _ = f_off(_T1_SOL, x1_at_t1, p1_at_t1, t_mid_off)
                x2_off_const = _GAMMA * _T1_SOL  # x2(t1) = 0 + γ*t1
                Test.@test isapprox(x_mid[2], x2_off_const; atol=1e-6)  # x2 constant on off-arc
            end
        end
    end
end

end # module

function test_double_integrator_consumption()
    return TestDoubleIntegratorConsumption.test_double_integrator_consumption()
end
