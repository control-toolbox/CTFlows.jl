"""
End-to-end integration test for the double-integrator ENERGY problem with CONTROL
CONSTRAINT (bang-smooth-bang, 3 arcs): `ẋ1 = x2`, `ẋ2 = u`, `x(0) = (-1,0)`,
`x(1) = (0,0)`, `|u| ≤ γ = 5`, minimise `∫ 0.5u² dt`, `tf = 1` fixed.

Multi-arc shooting (fixed tf, 4 equations, 4 unknowns `[p01, p02, t1, t2]`).
Structure "B+SB-": u=+γ on `[0,t1]`, u=p₂ on `[t1,t2]` (smooth interior), u=-γ on `[t2,1]`.
Switching conditions: `p₂(t1) = +γ` (bang+ → smooth), `p₂(t2) = -γ` (smooth → bang-).
Numerical solution `p0 = [12.90994448735837, 6.454972243678883]`.

The control is constant on bang arcs and `u* = p₂` (no x-dependence) on the smooth
arc, so `:total` and `:partial` coincide — asserted for both. Multi-phase
reconstruction validated via `*` composition.
"""
module TestDoubleIntegratorEnergyControlConstraint

using Test: Test
import CTModels: CTModels
import CTFlows.Flows
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

# Numerical solution from CTProblems.jl.
const _P0_SOL = [12.90994448735837, 6.454972243678883]
const _T1_SOL = (_P0_SOL[2] - _GAMMA) / _P0_SOL[1]
const _T2_SOL = (_P0_SOL[2] + _GAMMA) / _P0_SOL[1]

function _build_di_energy_control_constraint()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=_T0, tf=_TF)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r .= [x[2], u[1]]; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u[1]^2)
    CTModels.Building.constraint!(
        pre, :control; rg=1:1, lb=[-_GAMMA], ub=[_GAMMA], label=:u_box,
    )
    return CTModels.Building.build(pre)
end

function test_double_integrator_energy_control_constraint()
    Test.@testset "Double integrator — energy + control constraint B+SB- (:total/:partial)" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = _build_di_energy_control_constraint()

        for ht in (:total, :partial)
            # Bang+ arc: u = +γ; smooth arc: u* = p₂; bang- arc: u = -γ.
            f_plus = Flows.Flow(
                ocp, (x, p) -> _GAMMA;
                hamiltonian_type=ht, alg=Tsit5(), reltol=1e-12, abstol=1e-12,
            )
            f_mid = Flows.Flow(
                ocp, (x, p) -> p[2];
                hamiltonian_type=ht, alg=Tsit5(), reltol=1e-12, abstol=1e-12,
            )
            f_minus = Flows.Flow(
                ocp, (x, p) -> -_GAMMA;
                hamiltonian_type=ht, alg=Tsit5(), reltol=1e-12, abstol=1e-12,
            )

            function shoot!(s, ξ)
                p0 = [ξ[1], ξ[2]]
                t1, t2 = ξ[3], ξ[4]
                x1, p1 = f_plus(_T0, _X0, p0, t1)
                x2, p2 = f_mid(t1, x1, p1, t2)
                xf, _ = f_minus(t2, x2, p2, _TF)
                s[1:2] .= xf .- _XF
                s[3] = p1[2] - _GAMMA    # p₂(t1) = +γ : switch bang+ → smooth
                s[4] = p2[2] + _GAMMA    # p₂(t2) = -γ : switch smooth → bang-
                return nothing
            end

            ξ_exact = [_P0_SOL[1], _P0_SOL[2], _T1_SOL, _T2_SOL]
            ξ_guess = [10.0, 5.0, 0.2, 0.8]
            ξ_opt = test_shooting(shoot!, ξ_exact, ξ_guess; atol=1e-6)

            Test.@test isapprox(ξ_opt[1], _P0_SOL[1]; atol=1e-4)
            Test.@test isapprox(ξ_opt[2], _P0_SOL[2]; atol=1e-4)
            Test.@test isapprox(ξ_opt[3], _T1_SOL; atol=1e-4)
            Test.@test isapprox(ξ_opt[4], _T2_SOL; atol=1e-4)

            # Multi-phase reconstruction (:total only).
            if ht == :total
                φ = f_plus * (_T1_SOL, f_mid) * (_T2_SOL, f_minus)
                sol = φ((_T0, _TF), _X0, _P0_SOL)
                Test.@test sol isa CTModels.Solutions.Solution
            end
        end
    end
end

end # module

test_double_integrator_energy_control_constraint() =
    TestDoubleIntegratorEnergyControlConstraint.test_double_integrator_energy_control_constraint()
