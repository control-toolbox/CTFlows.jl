"""
End-to-end integration test for the double-integrator ENERGY-OPTIMAL problem (smooth
single arc): `ẋ1 = x2`, `ẋ2 = u`, `x(0) = (-1,0)`, `x(1) = (0,0)`, minimise `∫ 0.5u²`.
Ported from CTProblems.jl `DoubleIntegratorEnergy`.

Single-arc shooting (fixed `tf = 1`, 2 equations, 2 unknowns `p0`). Closed-form solution
`p0 = [12, 6]` derived from the linear ODE: u* = p2, ṗ1 = 0, ṗ2 = -p1, BCs x1(1)=x2(1)=0.

The smooth optimal control satisfies ∂H̃/∂u = 0 on the entire arc, so `:total` and
`:partial` coincide — asserted strictly for both.
"""
module TestDoubleIntegratorEnergy

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

# Closed form: u*(t) = p2(t) = p20 - p10*t; BCs x1(1)=x2(1)=0 ⇒ p0 = [12, 6].
const _P0_SOL = [12.0, 6.0]

function _build_di_energy()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=_T0, tf=_TF)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r .= [x[2], u[1]]; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u[1]^2)
    return CTModels.Building.build(pre)
end

function test_double_integrator_energy()
    Test.@testset "Double integrator — energy-optimal smooth (:total/:partial)" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = _build_di_energy()

        for ht in (:total, :partial)
            # u*(x,p) = p2 — smooth interior optimum; autonomous + no variable ⇒ arity (x,p).
            f = Flows.Flow(
                ocp,
                (x, p) -> p[2];
                hamiltonian_type=ht,
                alg=Tsit5(),
                reltol=1e-12,
                abstol=1e-12,
            )

            function shoot!(s, ξ)
                xf, _ = f(_T0, _X0, ξ, _TF)
                s .= xf .- _XF
                return nothing
            end

            # test_shooting: (1) residual at known solution, (2) Newton from guess,
            # (3) residual at converged solution.
            ξ_opt = test_shooting(shoot!, _P0_SOL, [11.0, 5.5])

            # Smooth energy-optimal: ∂H̃/∂u = 0 on-arc ⇒ :total ≡ :partial.
            Test.@test isapprox(ξ_opt, _P0_SOL; atol=1e-6)

            # Reconstruction: single-arc flow call returns a CTModels.Solution.
            sol = f((_T0, _TF), _X0, ξ_opt)
            Test.@test sol isa CTModels.Solutions.Solution
            Test.@test CTModels.objective(sol) > 0   # ∫0.5u² > 0
        end
    end
end

end # module

test_double_integrator_energy() = TestDoubleIntegratorEnergy.test_double_integrator_energy()
