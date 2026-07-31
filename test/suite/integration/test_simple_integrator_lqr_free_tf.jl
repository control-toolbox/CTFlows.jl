"""
End-to-end integration test for the simple-integrator LQR problem with FREE FINAL TIME
(smooth single arc, 1D): `ẋ = u`, `x(0) = 0`, `x(tf) = 1`, minimise the Bolza cost
`tf + ∫ 0.5(u² + x²)`, `tf` free (variable `v[1] = tf`). Ported from CTProblems.jl
`SimpleIntegratorLqrFreeTf`.

Single-arc shooting (free tf, 2 equations, 2 unknowns `[p0, tf]`). Closed-form solution
`tf = atanh(1/√3)`, `p0 = √2` derived from PMP: u* = p, ṗ = p ⇒ p(t) = p0 cosh(t),
x(t) = p0 sinh(t); x(tf) = 1 ⇒ p0 = 1/sinh(tf); free-tf Bolza transversality
H̃*(tf) = 1 ⇒ 0.5 p(tf)² - 0.5 x(tf)² = 1 ⇒ p(tf) = √3 ⇒ p0 = √3/cosh(tf) = √2.

The smooth optimal control satisfies ∂H̃/∂u = 0 on the entire arc, so `:total` and
`:partial` coincide — asserted strictly for both.
"""
module TestSimpleIntegratorLqrFreeTf

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
const _X0 = 0.0
const _XF = 1.0

# Closed form: tf = atanh(1/√3), p0 = √2.
const _TF_SOL = atanh(1.0 / sqrt(3.0))   # ≈ 0.6585
const _P0_SOL = sqrt(2.0)                 # ≈ 1.4142

function _build_simple_integrator_lqr_free_tf()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.variable!(pre, 1)
    CTModels.Building.time!(pre; t0=_T0, indf=1)   # free final time = variable[1]
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=u; nothing))
    CTModels.Building.objective!(
        pre, :min; mayer=(x0, xf, v) -> v[1], lagrange=(t, x, u, v) -> 0.5 * (u^2 + x^2)
    )
    return CTModels.Building.build(pre)
end

function test_simple_integrator_lqr_free_tf()
    Test.@testset "Simple integrator — LQR Bolza free tf (:total/:partial)" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = _build_simple_integrator_lqr_free_tf()

        for ht in (:total, :partial)
            # u*(x,p,v) = p — smooth interior optimum; autonomous + variable ⇒ arity (x,p,v).
            f = Flows.Flow(
                ocp,
                (x, p, v) -> p;
                hamiltonian_type=ht,
                alg=Tsit5(),
                reltol=1e-12,
                abstol=1e-12,
            )

            function shoot!(s, ξ)
                p0, tf = ξ[1], ξ[2]
                xf, pf = f(_T0, _X0, p0, tf; variable=tf)
                s[1] = xf - _XF                       # terminal target x(tf) = 1
                s[2] = 0.5 * pf^2 - 0.5 * xf^2 - 1.0  # Bolza free-tf: H̃*(tf) = 1
                return nothing
            end

            ξ_opt = test_shooting(shoot!, [_P0_SOL, _TF_SOL], [1.2, 0.7])

            # Smooth energy-optimal: ∂H̃/∂u = 0 on-arc ⇒ :total ≡ :partial.
            Test.@test isapprox(ξ_opt[1], _P0_SOL; atol=1e-6)
            Test.@test isapprox(ξ_opt[2], _TF_SOL; atol=1e-6)

            # Reconstruction: single-arc flow call returns a CTModels.Solution.
            sol = f((_T0, ξ_opt[2]), _X0, ξ_opt[1]; variable=ξ_opt[2])
            Test.@test sol isa CTModels.Solutions.Solution
            Test.@test CTModels.objective(sol) > 0   # tf + ∫0.5(u²+x²) > 0
            # ANALYTIC. CTProblems.jl `SimpleIntegratorLqrFreeTf` gives the Bolza value
            # J* = tf + 0.5·xf²/tanh(tf), evaluated at the closed-form tf = atanh(1/√3).
            Test.@test CTModels.objective(sol) ≈ _TF_SOL + 0.5 * _XF^2 / tanh(_TF_SOL) rtol =
                1e-6
        end
    end
end

end # module

function test_simple_integrator_lqr_free_tf()
    return TestSimpleIntegratorLqrFreeTf.test_simple_integrator_lqr_free_tf()
end
