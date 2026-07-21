"""
End-to-end integration test for the simple-integrator NONSMOOTH TURNPIKE problem
(3 arcs: bang- / singular / bang+): `ẋ = u`, `x(0) = 1`, `x(2) = 0.5`, `u ∈ [-1,1]`,
minimise `∫₀² x² dt`. Ported from CTProblems.jl `SimpleIntegratorNonsmoothTurnpike`.

Multi-arc shooting (fixed tf, 3 equations, 3 unknowns `[p0, t1, t2]`).
Closed-form solution `p0 = -1`, `t1 = 1`, `t2 = 1.5`.
Arc structure: u=-1 on [0, t1], u=0 on [t1, t2] (singular), u=+1 on [t2, 2].
Switching conditions: x(t1) = 0 (singular arc entry), p(t1) = 0 (costate vanishes).

Both `:total` and `:partial` are tested — the control is constant on each arc
(-1, 0, +1), so `∂u/∂x = 0` and the two Hamiltonian types coincide.
"""
module TestSimpleIntegratorNonsmoothTurnpike

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
const _TF = 2.0
const _X0 = 1.0
const _XF = 0.5

# Closed form: p0 = -1, t1 = 1, t2 = 1.5
const _P0_SOL = -1.0
const _T1_SOL = 1.0
const _T2_SOL = 1.5
const _XI_SOL = [_P0_SOL, _T1_SOL, _T2_SOL]

function _build_nonsmooth_turnpike()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=_T0, tf=_TF)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1] = u[1]; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> x[1]^2)
    return CTModels.Building.build(pre)
end

function test_simple_integrator_nonsmooth_turnpike()
    Test.@testset "Nonsmooth turnpike — bang/singular/bang (:total/:partial)" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = _build_nonsmooth_turnpike()

        for ht in (:total, :partial)
            # 3 arcs: u=-1, u=0 (singular), u=+1
            # Autonomous, no variable ⇒ arity (x, p)
            fm = Flows.Flow(
                ocp, (x, p) -> -1.0;
                hamiltonian_type=ht, alg=Tsit5(), reltol=1e-12, abstol=1e-12,
            )
            f0 = Flows.Flow(
                ocp, (x, p) -> 0.0;
                hamiltonian_type=ht, alg=Tsit5(), reltol=1e-12, abstol=1e-12,
            )
            fp = Flows.Flow(
                ocp, (x, p) -> 1.0;
                hamiltonian_type=ht, alg=Tsit5(), reltol=1e-12, abstol=1e-12,
            )

            function shoot!(s, ξ)
                p0, t1, t2 = ξ[1], ξ[2], ξ[3]
                x1, p1 = fm(_T0, _X0, p0, t1)
                x2, p2 = f0(t1, x1, p1, t2)
                xf_, pf_ = fp(t2, x2, p2, _TF)
                s[1] = xf_ - _XF          # x(tf) = 0.5
                s[2] = x1                 # x(t1) = 0 (singular arc entry)
                s[3] = p1                 # p(t1) = 0 (switching condition)
                return nothing
            end

            # Perturbed guess for Newton
            ξ_guess = _XI_SOL .* (1.0 .+ 0.01 .* [-0.3, 0.5, -0.2])
            ξ_opt = test_shooting(shoot!, _XI_SOL, ξ_guess; atol=1e-8)

            Test.@test isapprox(ξ_opt[1], _P0_SOL; atol=1e-6)
            Test.@test isapprox(ξ_opt[2], _T1_SOL; atol=1e-6)
            Test.@test isapprox(ξ_opt[3], _T2_SOL; atol=1e-6)

            # Multi-phase reconstruction (:total only)
            if ht == :total
                φ = fm * (_T1_SOL, f0) * (_T2_SOL, fp)
                sol = φ((_T0, _TF), _X0, _P0_SOL)
                Test.@test sol isa CTModels.Solutions.Solution
            end
        end
    end
end

end # module

test_simple_integrator_nonsmooth_turnpike() =
    TestSimpleIntegratorNonsmoothTurnpike.test_simple_integrator_nonsmooth_turnpike()
