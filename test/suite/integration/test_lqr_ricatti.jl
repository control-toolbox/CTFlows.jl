"""
End-to-end integration test for the LQR Riccati problem (smooth single arc, 2D):
`ẋ = Ax + Bu`, `A = [0 1; -1 0]`, `B = [0; 1]`, `x(0) = [0, 1]`, `tf = 5` (fixed),
minimise `∫ 0.5(x₁² + x₂² + u²)`. Free terminal state (no `x(tf)` constraint).
Ported from CTProblems.jl `LqrRicatti`.

Single-arc shooting (fixed tf, 2 equations, 2 unknowns `p0`). Transversality for
unconstrained free final state: `p(tf) = 0`. The solution is numerical (Riccati ODE);
`_P0_SOL` is pre-computed by Newton and hardcoded.

The smooth optimal control `u* = B'p = p[2]` satisfies ∂H̃/∂u = 0 on the entire arc,
so `:total` and `:partial` coincide — asserted strictly for both.
"""
module TestLqrRicatti

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
const _TF = 5.0
const _X0 = [0.0, 1.0]
const _A = [0.0 1.0; -1.0 0.0]
const _B = [0.0; 1.0]

# Pre-computed by Newton (Riccati ODE, numerical).
const _P0_SOL = [-0.41112814725869323, -1.3479980918292327]

function _build_lqr_ricatti()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=_T0, tf=_TF)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r .= _A * x + _B * u; nothing))
    CTModels.Building.objective!(
        pre, :min; lagrange=(t, x, u, v) -> 0.5 * (x[1]^2 + x[2]^2 + u[1]^2)
    )
    return CTModels.Building.build(pre)
end

function test_lqr_ricatti()
    Test.@testset "LQR Riccati 2D — smooth free terminal state (:total/:partial)" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = _build_lqr_ricatti()

        for ht in (:total, :partial)
            # u*(x,p) = p[2] — smooth interior optimum; autonomous + fixed ⇒ arity (x,p).
            f = Flows.Flow(
                ocp,
                (x, p) -> p[2];
                hamiltonian_type=ht,
                alg=Tsit5(),
                reltol=1e-12,
                abstol=1e-12,
            )

            function shoot!(s, ξ)
                xf, pf = f(_T0, _X0, ξ, _TF)
                s .= pf          # p(tf) = 0 : transversality for free final state
                return nothing
            end

            ξ_opt = test_shooting(shoot!, _P0_SOL, [-0.1, 0.3])

            # Smooth LQR: ∂H̃/∂u = 0 on-arc ⇒ :total ≡ :partial.
            Test.@test length(ξ_opt) == 2

            # Reconstruction: single-arc flow call returns a CTModels.Solution.
            sol = f((_T0, _TF), _X0, ξ_opt)
            Test.@test sol isa CTModels.Solutions.Solution
            Test.@test CTModels.objective(sol) > 0
        end
    end
end

end # module

test_lqr_ricatti() = TestLqrRicatti.test_lqr_ricatti()
