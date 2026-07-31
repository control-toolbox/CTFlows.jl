"""
End-to-end integration test for the simple-integrator ENERGY-OPTIMAL problem with FREE
FINAL TIME and a MIXED BOUNDARY CONSTRAINT (smooth single arc, 1D): `ẋ = u`, `x(0) = 0`,
`x(tf) - tf - 10 = 0`, minimise `∫ 0.5u²`, `tf` free (variable `v[1] = tf`). Ported
from CTProblems.jl `SimpleIntegratorEnergyFreeTf`.

Single-arc shooting (free tf, 2 equations, 2 unknowns `[p0, tf]`). Closed-form solution
`tf = 10`, `p0 = 2` derived from PMP: ṗ = 0 ⇒ p = const = p0, u* = p0,
x(t) = p0 t; boundary constraint x(tf) = tf+10 ⇒ p0*tf = tf+10 ⇒ p0 = (tf+10)/tf;
free-tf transversality H̃*(tf) = pf (boundary-constraint contribution to variable adjoint)
⇒ 0.5*pf² = pf ⇒ pf = 2, tf = 10.

The smooth optimal control satisfies ∂H̃/∂u = 0 on-arc, so `:total` and `:partial`
coincide — asserted strictly for both.
"""
module TestSimpleIntegratorEnergyFreeTf

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
const _X0 = 0.0

# Closed form: p0 = 2, tf = 10.
const _P0_SOL = 2.0
const _TF_SOL = 10.0

function _build_simple_integrator_energy_free_tf()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.variable!(pre, 1)
    CTModels.Building.time!(pre; t0=_T0, indf=1)   # free final time = variable[1]
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=u; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    CTModels.Building.constraint!(
        pre,
        :boundary;
        f=(r, x0, xf, v) -> (r[1]=xf - v[1] - 10.0; nothing),
        lb=[0.0],
        ub=[0.0],
        label=:bc,
    )
    return CTModels.Building.build(pre)
end

function test_simple_integrator_energy_free_tf()
    Test.@testset "Simple integrator — energy-optimal free tf + boundary constraint (:total/:partial)" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = _build_simple_integrator_energy_free_tf()

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
                s[1] = xf - tf - 10.0      # boundary constraint x(tf) - tf - 10 = 0
                s[2] = 0.5 * pf^2 - pf     # free-tf transversality: H̃*(tf) = pf
                return nothing
            end

            ξ_opt = test_shooting(shoot!, [_P0_SOL, _TF_SOL], [1.8, 9.5])

            # Smooth energy-optimal: ∂H̃/∂u = 0 on-arc ⇒ :total ≡ :partial.
            Test.@test isapprox(ξ_opt[1], _P0_SOL; atol=1e-6)
            Test.@test isapprox(ξ_opt[2], _TF_SOL; atol=1e-6)

            # Reconstruction: single-arc flow call returns a CTModels.Solution.
            sol = f((_T0, ξ_opt[2]), _X0, ξ_opt[1]; variable=ξ_opt[2])
            Test.@test sol isa CTModels.Solutions.Solution
            Test.@test CTModels.objective(sol) > 0   # ∫0.5u² > 0
            # ANALYTIC. CTProblems.jl `SimpleIntegratorEnergyFreeTf` gives J* = (tf+10)²/(2tf),
            # which at the closed-form tf = 10 is 400/20 = 20.
            Test.@test CTModels.objective(sol) ≈ (_TF_SOL + 10)^2 / (2 * _TF_SOL) rtol =
                1e-6
        end
    end
end

end # module

function test_simple_integrator_energy_free_tf()
    return TestSimpleIntegratorEnergyFreeTf.test_simple_integrator_energy_free_tf()
end
