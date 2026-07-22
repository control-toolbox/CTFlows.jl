"""
End-to-end integration test for the simple-integrator MIXED CONSTRAINT problem
(single arc, mixed constraint active throughout): `ẋ = u`, `x(0) = -1`, free final
state, `0 ≤ u`, `x + u ≤ 0`, minimise `∫(-u) dt`, `tf = 1` fixed.

Single-arc shooting (fixed tf, 1 equation, 1 unknown `p0`). Closed-form solution
`p0 = exp(-1) - 1`, `u(t) = exp(-t)`, `x(t) = -exp(-t)`.
The mixed constraint `x + u ≤ 0` is active on the entire arc, giving `u = -x`.
Transversality `p(tf) = 0` (free final state, no Mayer term).

PMP (minimization, `H = p·f - ℓ + μ·g`): stationarity `p + 1 + μ = 0` gives
`μ = -1 - p`; costate `ṗ = 1 + p`; constraint `g = x + u`.

The control law `u = -x` has no explicit `p`-dependence (the constraint determines
`u` from `x`), so `:total` and `:partial` coincide — asserted for both.
"""
module TestSimpleIntegratorMixedConstraint

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

# Closed form: p0 = exp(-1) - 1, u(t) = exp(-t), x(t) = -exp(-t).
const _P0_SOL = exp(-1.0) - 1.0

function _build_simple_integrator_mixed_constraint()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=_T0, tf=_TF)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=u[1]; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> -u[1])
    # Control box: 0 ≤ u
    CTModels.Building.constraint!(pre, :control; rg=1:1, lb=[0.0], ub=[Inf], label=:u_box)
    # Mixed path constraint: x + u ≤ 0
    CTModels.Building.constraint!(
        pre,
        :path;
        f=(r, t, x, u, v) -> (r[1]=x[1] + u[1]; nothing),
        lb=[-Inf],
        ub=[0.0],
        label=:mixed_con,
    )
    return CTModels.Building.build(pre)
end

function test_simple_integrator_mixed_constraint()
    Test.@testset "Simple integrator — mixed constraint active (:total/:partial)" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = _build_simple_integrator_mixed_constraint()

        for ht in (:total, :partial)
            # Active constraint: u = -x; multiplier μ = -1 - p from stationarity.
            f = Flows.Flow(
                ocp,
                (x, p) -> -x[1];
                constraint=(x, u) -> x[1] + u[1],
                multiplier=(x, p) -> -1.0 - p[1],
                hamiltonian_type=ht,
                alg=Tsit5(),
                reltol=1e-12,
                abstol=1e-12,
            )

            function shoot!(s, ξ)
                _, pf = f(_T0, _X0, ξ, _TF)
                s[1] = pf   # transversality: p(tf) = 0 (free final state)
                return nothing
            end

            ξ_opt = test_shooting(shoot!, [_P0_SOL], [-0.5]; atol=1e-8)

            Test.@test isapprox(ξ_opt[1], _P0_SOL; atol=1e-6)

            # Reconstruction: single-arc flow returns a CTModels.Solution.
            sol = f((_T0, _TF), _X0, ξ_opt)
            Test.@test sol isa CTModels.Solutions.Solution
            Test.@test CTModels.objective(sol) < 0   # ∫(-u) = exp(-1) - 1 < 0
            # The closed form asserted in the comment above, now actually checked:
            # measured exp(-1) - 1 = -0.6321205588285526 vs analytic -0.6321205588285577.
            Test.@test CTModels.objective(sol) ≈ exp(-1) - 1 rtol = 1e-8
        end
    end
end

end # module

function test_simple_integrator_mixed_constraint()
    return TestSimpleIntegratorMixedConstraint.test_simple_integrator_mixed_constraint()
end
