"""
End-to-end integration test for the simple-exponential TIME-OPTIMAL problem (bang-plus
single arc, 1D): `ẋ = -x + u`, `x(0) = -1`, `x(tf) = 0`, `|u| ≤ 1`, minimise `tf`
(encoded as Mayer on variable `v[1] = tf`). Ported from CTProblems.jl
`SimpleExponentialTime`.

Single-arc shooting (free tf, 2 equations, 2 unknowns `[p0, tf]`). Closed-form solution
`tf = log(2)`, `p0 = 0.5` derived from PMP: ṗ = p ⇒ p(t) = p0 exp(t) > 0 throughout
(single bang-plus arc u* = +1), x(tf) = 0 ⇒ tf = log(2), transversality H̃*(tf) = 1
⇒ p(tf) = 1 ⇒ p0 = exp(-tf) = 0.5.

The bang control is piecewise constant on the arc so ∂H̃/∂u ≡ 0 trivially, and
`:total` and `:partial` coincide — asserted strictly for both.
"""
module TestSimpleExponentialTime

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
const _X0 = -1.0
const _XF = 0.0
const _UMAX = 1.0

# Closed form: tf = log(2), p0 = exp(-tf) = 0.5.
const _TF_SOL = log(2.0)    # ≈ 0.6931
const _P0_SOL = 0.5

# Free-tf transversality for Mayer min v[1]: H̃*(tf) = 1.
# H̃ = p*(-x+u); at u=+1: H̃*(tf,xf,pf) = pf*(-xf+1) - 1 = 0.
_H_transv(x, p) = p * (-x + _UMAX) - 1.0

function _build_simple_exp_time()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.variable!(pre, 1)
    CTModels.Building.time!(pre; t0=_T0, indf=1)   # free final time = variable[1]
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1] = -x + u; nothing))
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> v[1])
    return CTModels.Building.build(pre)
end

function test_simple_exponential_time()
    Test.@testset "Simple exponential — time-optimal bang-plus (:total/:partial)" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = _build_simple_exp_time()

        for ht in (:total, :partial)
            # u*(x,p,v) = +1 (single bang-plus arc); autonomous + variable ⇒ arity (x,p,v).
            f = Flows.Flow(
                ocp,
                (x, p, v) -> _UMAX;
                hamiltonian_type=ht,
                alg=Tsit5(),
                reltol=1e-12,
                abstol=1e-12,
            )

            function shoot!(s, ξ)
                p0, tf = ξ[1], ξ[2]
                xf, pf = f(_T0, _X0, p0, tf; variable=tf)
                s[1] = xf - _XF                # final state
                s[2] = _H_transv(xf, pf)       # free-tf transversality: H̃*(tf) = 1
                return nothing
            end

            ξ_opt = test_shooting(shoot!, [_P0_SOL, _TF_SOL], [0.4, 0.8])

            # Bang control is constant ⇒ ∂H̃/∂u ≡ 0 on-arc ⇒ :total ≡ :partial.
            Test.@test isapprox(ξ_opt[1], _P0_SOL; atol=1e-6)
            Test.@test isapprox(ξ_opt[2], _TF_SOL; atol=1e-6)

            # Reconstruction: single-arc flow call returns a CTModels.Solution.
            sol = f((_T0, ξ_opt[2]), _X0, ξ_opt[1]; variable=ξ_opt[2])
            Test.@test sol isa CTModels.Solutions.Solution
            Test.@test CTModels.objective(sol) ≈ _TF_SOL atol = 1e-3   # tf → min
        end
    end
end

end # module

test_simple_exponential_time() = TestSimpleExponentialTime.test_simple_exponential_time()
