"""
End-to-end integration test for the double-integrator ENERGY/DISTANCE problem (smooth
single arc, Bolza): `ẋ1 = x2`, `ẋ2 = u`, `x(0) = (0,0)`, free final state, minimise
`-0.5 x₁(tf) + ∫ 0.5u² dt`, `tf = 1` fixed.

Single-arc shooting (fixed tf, 2 equations, 2 unknowns `p0`). Closed-form solution
`p0 = [0.5, 0.5]` from PMP: u* = p₂, ṗ₁ = 0, ṗ₂ = -p₁; transversality p(tf) = -∂M/∂x
with M = -0.5x₁(tf) gives p₁(tf) = 0.5, p₂(tf) = 0.

The smooth optimal control satisfies ∂H̃/∂u = 0 on the entire arc, so `:total` and
`:partial` coincide — asserted strictly for both.
"""
module TestDoubleIntegratorEnergyDistance

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
const _X0 = [0.0, 0.0]

# Closed form: p0 = [0.5, 0.5]; p(t) = [0.5, -0.5t+0.5]; u*(t) = p₂(t).
const _P0_SOL = [0.5, 0.5]

function _build_di_energy_distance()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=_T0, tf=_TF)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r.=[x[2], u[1]]; nothing))
    CTModels.Building.objective!(
        pre, :min; mayer=(x0, xf, v) -> -0.5 * xf[1], lagrange=(t, x, u, v) -> 0.5 * u[1]^2
    )
    return CTModels.Building.build(pre)
end

function test_double_integrator_energy_distance()
    Test.@testset "Double integrator — energy/distance Bolza (:total/:partial)" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = _build_di_energy_distance()

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
                _, pf = f(_T0, _X0, ξ, _TF)
                s[1] = pf[1] - 0.5   # transversality: p₁(tf) = -∂M/∂x₁ = 0.5
                s[2] = pf[2] - 0.0   # transversality: p₂(tf) = -∂M/∂x₂ = 0
                return nothing
            end

            ξ_opt = test_shooting(shoot!, _P0_SOL, [0.4, 0.3])

            Test.@test isapprox(ξ_opt, _P0_SOL; atol=1e-6)

            # Reconstruction: single-arc flow call returns a CTModels.Solution.
            sol = f((_T0, _TF), _X0, ξ_opt)
            Test.@test sol isa CTModels.Solutions.Solution
            Test.@test CTModels.objective(sol) < 0   # -0.5x₁(tf) + ∫0.5u² < 0
            # ANALYTIC. CTProblems.jl `DoubleIntegratorEnergyDistance` gives the closed form
            #   J* = -0.5·x₁(tf) + tf³/24  with  x₁(tf) = tf²/12·(3tf - tf) = 1/6  at tf = 1,
            # hence J* = -1/12 + 1/24 = -1/24. Matches the integrated value to ~1e-15.
            Test.@test CTModels.objective(sol) ≈ -1 / 24 rtol = 1e-6
        end
    end
end

end # module

function test_double_integrator_energy_distance()
    return TestDoubleIntegratorEnergyDistance.test_double_integrator_energy_distance()
end
