"""
End-to-end integration test for the double-integrator TIME-OPTIMAL problem with FREE INITIAL
TIME (bang-bang, 2 arcs): `ẋ1 = x2`, `ẋ2 = u`, `u ∈ [-1,1]`, `x(t0) = [0,0]`, `x(0) = [1,0]`,
maximise `t0` (minimise `-t0`). Ported from
[tutorial-free-times-initial.md](https://github.com/control-toolbox/Tutorials.jl/blob/main/docs/src/tutorial-free-times-initial.md).

Multi-arc shooting (free t0, 4 equations, 4 unknowns `[p10, p20, t1, t0]`).
Closed-form solution `t0 = -2`, `t1 = -1`, `p0 = [1, 1]`.
Transversality: H(t0) = 1 (Mayer g = -t0, ∂g/∂t0 = -1, H(t0) = -∂g/∂t0 = 1).
Switching: p2(t1) = 0.

Bang-bang control is constant on each arc, so `:total` and `:partial` coincide — asserted
for both. Multi-phase reconstruction validated via `*` composition.
"""
module TestFreeInitialTime

using Test: Test
import CTModels: CTModels
import CTFlows.Flows
using OrdinaryDiffEqTsit5
using ForwardDiff: ForwardDiff
using NonlinearSolve: NonlinearProblem, SimpleNewtonRaphson, solve

include(joinpath(@__DIR__, "utils.jl"))

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const _TF = 0.0
const _X0 = [0.0, 0.0]
const _XF = [1.0, 0.0]

# Converged Newton solution (= exact PMP solution)
const _P0_SOL = [1.0, 1.0]
const _T1_SOL = -1.0
const _T0_SOL = -2.0
const _XI_SOL = [_P0_SOL; _T1_SOL; _T0_SOL]

# Initial guess from tutorial direct method (sol.costate(t0))
# ‖s‖ ≈ 4.7e-3 at this point — Newton converges readily
const _XI_GUESS = [0.9999999954958447, 0.996660258625808, -0.9999999955009733, -1.9999999910019466]

function _build_free_initial_time()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.variable!(pre, 1)
    CTModels.Building.time!(pre; ind0=1, tf=_TF)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r .= [x[2], u[1]]; nothing))
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> -v[1])
    return CTModels.Building.build(pre)
end

function test_free_initial_time()
    Test.@testset "Free initial time — double integrator bang-bang (:total/:partial)" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = _build_free_initial_time()

        for ht in (:total, :partial)
            # Bang-bang: u=+1 on [t0, t1], u=-1 on [t1, 0]
            # Autonomous + variable ⇒ arity (x, p, v)
            f_pos = Flows.Flow(
                ocp, (x, p, v) -> 1.0;
                hamiltonian_type=ht, alg=Tsit5(), reltol=1e-12, abstol=1e-12,
            )
            f_neg = Flows.Flow(
                ocp, (x, p, v) -> -1.0;
                hamiltonian_type=ht, alg=Tsit5(), reltol=1e-12, abstol=1e-12,
            )

            function shoot!(s, ξ)
                p0 = [ξ[1], ξ[2]]
                t1, t0 = ξ[3], ξ[4]
                x_t1, p_t1 = f_pos(t0, _X0, p0, t1; variable=t0)
                x_tf, p_tf = f_neg(t1, x_t1, p_t1, _TF; variable=t0)
                s[1] = x_tf[1] - _XF[1]              # x(tf)[1] = 1
                s[2] = x_tf[2]                       # x(tf)[2] = 0
                s[3] = p0[1] * _X0[2] + p0[2] * 1.0 - 1.0  # H(t0) = 1 (transversality)
                s[4] = p_t1[2]                       # switching: p2(t1) = 0
                return nothing
            end

            ξ_opt = test_shooting(shoot!, _XI_SOL, _XI_GUESS; atol=1e-8)

            Test.@test isapprox(ξ_opt[1], _P0_SOL[1]; atol=1e-6)
            Test.@test isapprox(ξ_opt[2], _P0_SOL[2]; atol=1e-6)
            Test.@test isapprox(ξ_opt[3], _T1_SOL; atol=1e-6)
            Test.@test isapprox(ξ_opt[4], _T0_SOL; atol=1e-6)

            # Multi-phase reconstruction (:total only)
            if ht == :total
                φ = f_pos * (_T1_SOL, f_neg)
                sol = φ((_T0_SOL, _TF), _X0, _P0_SOL; variable=_T0_SOL)
                Test.@test sol isa CTModels.Solutions.Solution
            end
        end
    end
end

end # module

test_free_initial_time() = TestFreeInitialTime.test_free_initial_time()
