"""
End-to-end integration test for the double-integrator OCP with a FIRST-ORDER state
constraint (velocity `v ≤ v_max`), built from a `CTModels.Model`. Three-arc structure
(interior → boundary → interior) with **continuous costate** (no jumps, since the
constraint is first-order). Ported from
[example-state-constraint.md](../../../../OptimalControl/docs/src/example-state-constraint.md).

OCP: `ẋ = [v, u]`, `x(0) = (-1, 0)`, `x(1) = (0, 0)`, minimise `∫ 0.5u² dt`,
path constraint `v ≤ 1.2`.

Boundary arc: `u = 0` (from `ġ = -u = 0`), multiplier `μ = p[1]` (from `ṗ₂ = -p₁ + μ = 0`).
Shooting: 4 unknowns `[p0[1], p0[2], t1, t2]`, 4 equations (target + entry + switching).
Analytic solution: `p0 = [38.4, 9.6]`, `t1 = 0.25`, `t2 = 0.75`.
"""
module TestDoubleIntegratorStateFirstOrder

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
const _TF = 1.0
const _X0 = [-1.0, 0.0]
const _XF = [0.0, 0.0]
const _V_MAX = 1.2

# Analytic solution from OptimalControl.jl docs Newton output.
const _P0_SOL = [38.4, 9.6]
const _T1_SOL = 0.25
const _T2_SOL = 0.75

function _build_di_first_order()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=_T0, tf=_TF)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r.=[x[2], u[1]]; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u[1]^2)
    CTModels.Building.constraint!(
        pre,
        :path;
        f=(r, t, x, u, v) -> (r[1]=x[2]; nothing),
        lb=[-Inf],
        ub=[_V_MAX],
        label=:v_con,
    )
    return CTModels.Building.build(pre)
end

function test_double_integrator_state_first_order()
    Test.@testset "Double integrator — 1st-order state constraint v≤v_max (:total/:partial)" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = _build_di_first_order()
        g(x) = _V_MAX - x[2]   # constraint g(x) ≥ 0

        for ht in (:total, :partial)
            # Interior flow: u* = p₂ (smooth optimum from PMP).
            f_interior = Flows.Flow(
                ocp,
                (x, p) -> p[2];
                hamiltonian_type=ht,
                alg=Tsit5(),
                reltol=1e-12,
                abstol=1e-12,
            )
            # Boundary flow: u = 0, constraint g(x) = v_max - v, multiplier μ = p₁.
            f_boundary = Flows.Flow(
                ocp,
                (x, p) -> 0.0;
                constraint=(x, u) -> _V_MAX - x[2],
                multiplier=(x, p) -> p[1],
                hamiltonian_type=ht,
                alg=Tsit5(),
                reltol=1e-12,
                abstol=1e-12,
            )

            function shoot!(s, ξ)
                p0 = [ξ[1], ξ[2]]
                t1, t2 = ξ[3], ξ[4]
                x1, p1 = f_interior(_T0, _X0, p0, t1)
                x2, p2 = f_boundary(t1, x1, p1, t2)
                xf, pf = f_interior(t2, x2, p2, _TF)
                s[1] = xf[1] - _XF[1]
                s[2] = xf[2] - _XF[2]
                s[3] = g(x1)          # entry: v(t1) = v_max
                s[4] = p1[2]          # switching: p₂(t1) = 0
                return nothing
            end

            ξ_exact = [_P0_SOL..., _T1_SOL, _T2_SOL]
            ξ_guess = [35.0, 8.0, 0.2, 0.8]
            ξ_opt = test_shooting(shoot!, ξ_exact, ξ_guess; atol=1e-6)

            Test.@test isapprox(ξ_opt[1], _P0_SOL[1]; atol=1e-4)
            Test.@test isapprox(ξ_opt[2], _P0_SOL[2]; atol=1e-4)
            Test.@test isapprox(ξ_opt[3], _T1_SOL; atol=1e-4)
            Test.@test isapprox(ξ_opt[4], _T2_SOL; atol=1e-4)

            # Reconstruction (:total only).
            if ht == :total
                p0 = [ξ_opt[1], ξ_opt[2]]
                t1, t2 = ξ_opt[3], ξ_opt[4]
                φ = f_interior * (t1, f_boundary) * (t2, f_interior)
                sol = φ((_T0, _TF), _X0, p0)
                Test.@test sol isa CTModels.Solutions.Solution
                uu = CTModels.control(sol)
                _u(t) = uu(t) isa Number ? uu(t) : uu(t)[1]
                # Boundary arc midpoint: u ≈ 0
                Test.@test abs(_u(0.5 * (t1 + t2))) < 1e-6
                # Interior arc: u = p₂ ≠ 0
                Test.@test abs(_u(0.5 * t1)) > 1e-3
                Test.@test CTModels.objective(sol) > 0
                # PINNED REFERENCE — regression guard, NOT a derived optimum (sits on 7.68 to ~5e-12).
                Test.@test CTModels.objective(sol) ≈ 7.68 rtol = 1e-6
            end
        end
    end
end

end # module

function test_double_integrator_state_first_order()
    return TestDoubleIntegratorStateFirstOrder.test_double_integrator_state_first_order()
end
