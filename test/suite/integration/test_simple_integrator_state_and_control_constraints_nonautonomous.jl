"""
End-to-end integration test for the simple-integrator STATE AND CONTROL CONSTRAINTS
NON-AUTONOMOUS problem (3 arcs "0C0"): `ẋ = u`, `x(0) = 0`, `0 ≤ u ≤ 3`,
`1 - x - (t-2)² ≤ 0`, minimise `∫ exp(-t) u dt`, `tf = 3`.

Multi-arc shooting (fixed tf, 4 equations, 4 unknowns `[p0, t1, t2, ν2]`).
- Arc 0: `u = 0` on `[0, t1]` (below constraint)
- Arc C: `u = -2(t-2)` on `[t1, t2]` (state constraint active: `x = 1-(t-2)²`)
- Arc 0: `u = 0` on `[t2, 3]`
Costate jump `ν2` at exit `t2` (order-1 state constraint).

Shooting equations (from CTProblems.jl test):
- `pf = 0` (transversality, free final state)
- `g(t1, x1) = 0` (entry on boundary: `1 - x(t1) - (t1-2)² = 0`)
- `p1 = exp(-α*t1)` (costate matching at `t1`)
- `t2 = 2` (exit at parabola vertex)

The control is constant (0) on off arcs and `u(t) = -2(t-2)` on the boundary arc
(no x/p dependence), so `:total` and `:partial` coincide — asserted for both.
Multi-phase reconstruction validated via `*` composition with costate jump.
"""
module TestSimpleIntegratorStateControlNonautonomous

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
const _TF = 3.0
const _X0 = 0.0
const _ALPHA = 1.0

# Exact solution: p0 = exp(-1), t1 = 1, t2 = 2, ν2 = -exp(-2).
const _P0_SOL = exp(-_ALPHA)
const _T1_SOL = 1.0
const _T2_SOL = 2.0
const _NU2_SOL = -exp(-2.0 * _ALPHA)

function _build_si_nonautonomous()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=false)
    CTModels.Building.time!(pre; t0=_T0, tf=_TF)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=u[1]; nothing))
    CTModels.Building.objective!(
        pre, :min; lagrange=(t, x, u, v) -> exp(-_ALPHA * t) * u[1]
    )
    # Control box: 0 ≤ u ≤ 3
    CTModels.Building.constraint!(pre, :control; rg=1:1, lb=[0.0], ub=[3.0], label=:u_con)
    # State path constraint: 1 - x - (t-2)² ≤ 0
    CTModels.Building.constraint!(
        pre,
        :path;
        f=(r, t, x, u, v) -> (r[1]=1.0 - x[1] - (t - 2.0)^2; nothing),
        lb=[-Inf],
        ub=[0.0],
        label=:x_con,
    )
    return CTModels.Building.build(pre)
end

function test_simple_integrator_state_and_control_constraints_nonautonomous()
    Test.@testset "Simple integrator — state+control nonautonomous 0C0 (:total/:partial)" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = _build_si_nonautonomous()

        # State constraint function g(t, x) = 1 - x - (t-2)²
        g(t, x) = 1.0 - x[1] - (t - 2.0)^2

        for ht in (:total, :partial)
            # Off arc: u = 0; boundary arc: u = -2(t-2) from ẋ = d/dt[1-(t-2)²].
            # Non-autonomous + fixed ⇒ arity (t, x, p).
            f0 = Flows.Flow(
                ocp,
                (t, x, p) -> 0.0;
                hamiltonian_type=ht,
                alg=Tsit5(),
                reltol=1e-12,
                abstol=1e-12,
            )
            fc = Flows.Flow(
                ocp,
                (t, x, p) -> -2.0 * (t - 2.0);
                constraint=(t, x, u) -> g(t, x),
                multiplier=(t, x, p) -> -_ALPHA * p[1],
                hamiltonian_type=ht,
                alg=Tsit5(),
                reltol=1e-12,
                abstol=1e-12,
            )

            function shoot!(s, ξ)
                p0, t1, t2, ν2 = ξ[1], ξ[2], ξ[3], ξ[4]
                x1, p1 = f0(_T0, _X0, p0, t1)
                x2, p2 = fc(t1, x1, p1, t2)
                _, pf = f0(t2, x2, p2 + ν2, _TF)
                s[1] = pf[1]                          # transversality p(tf) = 0
                s[2] = g(t1, x1)                      # entry: g(t1, x(t1)) = 0
                s[3] = p1[1] - exp(-_ALPHA * t1)      # costate matching at t1
                s[4] = t2 - 2.0                       # exit at parabola vertex
                return nothing
            end

            ξ_exact = [_P0_SOL, _T1_SOL, _T2_SOL, _NU2_SOL]
            ξ_guess = [0.35, 1.1, 1.9, -0.15]
            ξ_opt = test_shooting(shoot!, ξ_exact, ξ_guess; atol=1e-6)

            Test.@test isapprox(ξ_opt[1], _P0_SOL; atol=1e-4)
            Test.@test isapprox(ξ_opt[2], _T1_SOL; atol=1e-4)
            Test.@test isapprox(ξ_opt[3], _T2_SOL; atol=1e-4)

            # Multi-phase reconstruction (:total only).
            if ht == :total
                φ = f0 * (_T1_SOL, fc) * (_T2_SOL, _NU2_SOL, f0)
                sol = φ((_T0, _TF), _X0, _P0_SOL)
                Test.@test sol isa CTModels.Solutions.Solution
            end
        end
    end
end

end # module

function test_simple_integrator_state_and_control_constraints_nonautonomous()
    return TestSimpleIntegratorStateControlNonautonomous.test_simple_integrator_state_and_control_constraints_nonautonomous()
end
