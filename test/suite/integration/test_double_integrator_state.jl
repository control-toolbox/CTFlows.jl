"""
End-to-end integration test for the double-integrator OCP with a SECOND-ORDER state
constraint (position `q ≤ a`), built from a `CTModels.Model`. Boundary-arc case (`a =
0.1`): three-arc shooting with costate jumps at the two junctions (chained by hand, as
jumps are not yet threaded through `Flow(ocp, law)`), run in both `:total` and `:partial`
(order-2 on-arc equivalence, item i: constant boundary control). Ported from
[example-state-constraint.md](../../../../OptimalControl/docs/src/example-state-constraint.md).
Also exercises the `*` multi-phase reconstruction with jumps (PR 5 D3): a `CTModels.Solution`
with piecewise reconstructed control.
"""
module TestDoubleIntegratorState

using Test: Test
import CTBase.Data
import CTModels: CTModels
import CTFlows.Flows
import CTFlows.Trajectories
using OrdinaryDiffEqTsit5
using ForwardDiff: ForwardDiff
using NonlinearSolve: NonlinearProblem, SimpleNewtonRaphson, solve

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# Double integrator, SECOND-ORDER state constraint q ≤ a (position).
# x = (q, v), ẋ = [v, u], ℓ = 0.5 u², :min ; x0 = (0,1), xf = (0,-1).
# Boundary-arc case a = 0.1: on the arc u ≡ 0 and μ ≡ 0; costate jumps at both junctions.
# Ported from OptimalControl docs/src/example-state-constraint.md.

const _T0 = 0.0
const _TF = 1.0
const _X0 = [0.0, 1.0]
const _XF = [0.0, -1.0]

function _build_di(a)
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=_T0, tf=_TF)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r .= [x[2], u[1]]; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u[1]^2)
    CTModels.Building.constraint!(
        pre, :path;
        f=(r, t, x, u, v) -> (r[1] = x[1]; nothing), lb=[-Inf], ub=[a], label=:q,
    )
    return CTModels.Building.build(pre)
end

function test_double_integrator_state()
    Test.@testset "Double integrator — 2nd-order state constraint (:total/:partial)" verbose=VERBOSE showtiming=SHOWTIMING begin
        a = 0.1
        ocp = _build_di(a)
        g(x) = a - x[1]   # constraint g(x) ≥ 0

        # Analytic boundary-arc solution (see example-state-constraint.md):
        #   t1 = 3a, t2 = 1-3a, p0 = [-200/9, -60/9], Δpq1 = Δpq2 = 200/9.
        t1_sol = 3a
        t2_sol = 1 - 3a
        p0_sol = [-200 / 9, -60 / 9]
        Δpq_sol = 200 / 9
        ξ_sol = [p0_sol..., t1_sol, t2_sol, Δpq_sol, Δpq_sol]

        function _build_flows(ht)
            fs = Flows.Flow(ocp, (x, p) -> p[2]; hamiltonian_type=ht,
                            alg=Tsit5(), reltol=1e-12, abstol=1e-12)
            fc = Flows.Flow(ocp, (x, p) -> 0.0;
                            constraint=(x, u) -> a - x[1], multiplier=(x, p) -> 0.0,
                            hamiltonian_type=ht, alg=Tsit5(), reltol=1e-12, abstol=1e-12)
            return fs, fc
        end

        function _make_shoot(fs, fc)
            function shoot!(s, p0, t1, t2, Δpq1, Δpq2)
                x1, p1 = fs(_T0, _X0, p0, t1)                 # arc 1: interior
                p1p = [p1[1] + Δpq1, p1[2]]                   # costate jump at t1 (by hand)
                x2, p2 = fc(t1, x1, p1p, t2)                  # arc 2: boundary
                p2p = [p2[1] + Δpq2, p2[2]]                   # costate jump at t2 (by hand)
                xf, _ = fs(t2, x2, p2p, _TF)                  # arc 3: interior
                s[1:2] = xf - _XF                             # reach target
                s[3] = g(x1)                                  # q(t1) = a
                s[4] = x1[2]                                  # v(t1) = 0
                s[5] = p1p[2]                                 # pv(t1+) = 0
                s[6] = p1p[1]                                 # pq(t1+) = 0
                return nothing
            end
            return shoot!
        end

        for ht in (:total, :partial)
            fs, fc = _build_flows(ht)
            shoot! = _make_shoot(fs, fc)

            s = zeros(6)
            shoot!(s, p0_sol, t1_sol, t2_sol, Δpq_sol, Δpq_sol)
            res_known = sqrt(sum(abs2, s))

            ξ0 = [-22.0, -6.7, 0.28, 0.72, 22.0, 22.0]   # perturbed guess
            shoot_nl!(s, ξ, _) = shoot!(s, ξ[1:2], ξ[3], ξ[4], ξ[5], ξ[6])
            nl = solve(NonlinearProblem(shoot_nl!, ξ0), SimpleNewtonRaphson();
                       abstol=1e-10, reltol=1e-10, show_trace=Val(false))
            sc = zeros(6)
            shoot!(sc, nl.u[1:2], nl.u[3], nl.u[4], nl.u[5], nl.u[6])
            res_conv = sqrt(sum(abs2, sc))

            Test.@test res_known < 1e-6
            Test.@test res_conv < 1e-8
            Test.@test isapprox(nl.u[3], t1_sol; atol=1e-6)   # t1 ≈ 0.3
            Test.@test isapprox(nl.u[4], t2_sol; atol=1e-6)   # t2 ≈ 0.7
            Test.@test isapprox(nl.u[5], nl.u[6]; atol=1e-6)  # Δpq1 ≈ Δpq2

            # Final reconstruction via `*` with costate jumps (vector added to costate).
            # Multi-phase OCP flow → CTModels Solution with piecewise control.
            φ = fs * (t1_sol, [Δpq_sol, 0.0], fc) * (t2_sol, [Δpq_sol, 0.0], fs)
            sol = φ((_T0, _TF), _X0, p0_sol)
            Test.@test sol isa CTModels.Solutions.Solution
            uu = CTModels.control(sol)
            _u(t) = uu(t) isa Number ? uu(t) : uu(t)[1]
            # piecewise control: boundary arc [t1,t2] has u ≡ 0; interior arcs u = p₂ ≠ 0
            Test.@test abs(_u(0.5 * (t1_sol + t2_sol))) < 1e-6      # boundary midpoint
            Test.@test abs(_u(0.5 * t1_sol)) > 1e-3                 # interior arc 1
            Test.@test CTModels.objective(sol) > 0                  # ∫0.5u² > 0
        end
    end
end

end # module

test_double_integrator_state() = TestDoubleIntegratorState.test_double_integrator_state()
