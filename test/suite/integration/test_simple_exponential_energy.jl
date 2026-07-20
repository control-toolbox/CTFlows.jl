"""
End-to-end integration test for the simple-exponential ENERGY-OPTIMAL problem (smooth
single arc, 1D): `ẋ = -x + u`, `x(0) = -1`, `x(1) = 0`, minimise `∫ 0.5u²`. Ported
from CTProblems.jl `SimpleExponentialEnergy`.

Single-arc shooting (fixed `tf = 1`, 1 equation, 1 unknown `p0`). Closed-form solution
`p0 = exp(-1) / sinh(1)` derived from PMP: u* = p, ṗ = p ⇒ p(t) = p0 exp(t),
x(t) = p0 sinh(t) + x0 exp(-t), x(1) = 0 ⇒ p0 = exp(-1)/sinh(1).

The smooth optimal control satisfies ∂H̃/∂u = 0 on the entire arc, so `:total` and
`:partial` coincide — asserted strictly for both.
"""
module TestSimpleExponentialEnergy

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
const _X0 = -1.0
const _XF = 0.0

# Closed form: p0 = exp(-tf) / sinh(tf) with tf = 1.
const _P0_SOL = exp(-1.0) / sinh(1.0)   # ≈ 0.4372

function _build_simple_exp_energy()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=_T0, tf=_TF)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1] = -x + u; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    return CTModels.Building.build(pre)
end

function test_simple_exponential_energy()
    Test.@testset "Simple exponential — energy-optimal smooth (:total/:partial)" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = _build_simple_exp_energy()

        for ht in (:total, :partial)
            # u*(x,p) = p — smooth interior optimum; autonomous + no variable ⇒ arity (x,p).
            f = Flows.Flow(
                ocp,
                (x, p) -> p;
                hamiltonian_type=ht,
                alg=Tsit5(),
                reltol=1e-12,
                abstol=1e-12,
            )

            function shoot!(s, ξ)
                xf, _ = f(_T0, _X0, ξ[1], _TF)
                s[1] = xf - _XF
                return nothing
            end

            ξ_opt = test_shooting(shoot!, [_P0_SOL], [0.3])

            # Smooth energy-optimal: ∂H̃/∂u = 0 on-arc ⇒ :total ≡ :partial.
            Test.@test isapprox(ξ_opt[1], _P0_SOL; atol=1e-6)

            # Reconstruction: single-arc flow call returns a CTModels.Solution.
            sol = f((_T0, _TF), _X0, ξ_opt[1])
            Test.@test sol isa CTModels.Solutions.Solution
            Test.@test CTModels.objective(sol) > 0   # ∫0.5u² > 0
        end
    end
end

end # module

test_simple_exponential_energy() = TestSimpleExponentialEnergy.test_simple_exponential_energy()
