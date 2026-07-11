"""
End-to-end integration test for the double-integrator TIME-OPTIMAL problem (bang-bang, no
state constraint): `ẋ1 = x2`, `ẋ2 = u`, `u ∈ [-1,1]`, `x(0) = (-1,0)`, `x(tf) = (0,0)`,
minimise `tf`. Ported from
[example-double-integrator-time.md](../../../../OptimalControl/docs/src/example-double-integrator-time.md).

Two-phase bang-bang OCP flow (`u=+1` then `u=-1`, free final time, ONE switching time, NO
jump). Purpose (PR 5 B3): exercise the D3 return-type / piecewise-control reconstruction
with genuinely DIFFERENT laws per arc, independent of any constraint — the multi-phase `*`
of two `OptimalControlFlow`s must return a `CTModels.Solution` whose reconstructed `u(t)`
is `+1` then `-1`.
"""
module TestDoubleIntegratorTime

using Test: Test
import CTModels: CTModels
import CTFlows.Flows
using OrdinaryDiffEqTsit5
using ForwardDiff: ForwardDiff
using NonlinearSolve: NonlinearProblem, SimpleNewtonRaphson, solve

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const _T0 = 0.0
const _X0 = [-1.0, 0.0]
const _XF = [0.0, 0.0]
const _UMAX = 1.0
const _UMIN = -1.0

function _build_di_time()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.variable!(pre, 1)
    CTModels.Building.time!(pre; t0=_T0, indf=1)   # free final time = variable[1]
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r .= [x[2], u[1]]; nothing))
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> v[1])
    return CTModels.Building.build(pre)
end

# pseudo-Hamiltonian H = p1 x2 + p2 u - 1 (normal case, sp0 = -1); u = sign(p2)
_H(x, p, u) = p[1] * x[2] + p[2] * u - 1

function test_double_integrator_time()
    Test.@testset "Double integrator — time-optimal bang-bang (:total/:partial)" verbose = VERBOSE showtiming = SHOWTIMING begin
        ocp = _build_di_time()

        # Closed form (PMP): ṗ1 = 0 ⇒ p1 ≡ 1 (normal case), ṗ2 = -p1 ⇒ p2(t) = 1 - t,
        # switching at p2(t1) = 0 ⇒ t1 = 1. Phase 1 (u=+1): x2(t) = t, x1(t) = -1 + t²/2.
        # Phase 2 (u=-1), symmetric return to the origin ⇒ tf = 2 t1 = 2.
        p0_sol = [1.0, 1.0]
        t1_sol = 1.0
        tf_sol = 2.0

        function _build_flows(ht)
            fmax = Flows.Flow(
                ocp,
                (x, p, v) -> _UMAX;
                hamiltonian_type=ht,
                alg=Tsit5(),
                reltol=1e-12,
                abstol=1e-12,
            )
            fmin = Flows.Flow(
                ocp,
                (x, p, v) -> _UMIN;
                hamiltonian_type=ht,
                alg=Tsit5(),
                reltol=1e-12,
                abstol=1e-12,
            )
            return fmax, fmin
        end

        function _make_shoot(fmax, fmin)
            function shoot!(s, p0, t1, tf)
                x1, p1v = fmax(_T0, _X0, p0, t1; variable=tf)
                xf, pf = fmin(t1, x1, p1v, tf; variable=tf)
                s[1:2] = xf - _XF          # target conditions
                s[3] = p1v[2]              # switching condition p2(t1) = 0
                s[4] = _H(xf, pf, _UMIN)   # free final time transversality
                return nothing
            end
            return shoot!
        end

        for ht in (:total, :partial)
            fmax, fmin = _build_flows(ht)
            shoot! = _make_shoot(fmax, fmin)

            # Residual at the KNOWN (closed-form) solution
            s = zeros(4)
            shoot!(s, p0_sol, t1_sol, tf_sol)
            res_known = sqrt(sum(abs2, s))

            # Newton from a perturbed guess
            ξ0 = [0.8, 0.8, 0.8, 1.8]
            shoot_nl!(s, ξ, _) = shoot!(s, ξ[1:2], ξ[3], ξ[4])
            prob = NonlinearProblem(shoot_nl!, ξ0)
            nl = solve(prob, SimpleNewtonRaphson(); abstol=1e-10, reltol=1e-10, show_trace=Val(false))
            sc = zeros(4)
            shoot!(sc, nl.u[1:2], nl.u[3], nl.u[4])
            res_conv = sqrt(sum(abs2, sc))

            # A bang-bang control is constant on each arc, so ∂H̃/∂u ≡ 0 trivially on-arc:
            # :total and :partial coincide everywhere here — assert strictly for both.
            Test.@test res_known < 1e-10
            Test.@test res_conv < 1e-8
            Test.@test isapprox(nl.u[1:2], p0_sol; atol=1e-6)
            Test.@test isapprox(nl.u[3], t1_sol; atol=1e-6)
            Test.@test isapprox(nl.u[4], tf_sol; atol=1e-6)

            if ht === :total
                Test.@testset "MultiPhase reconstruction: fmax*(t1,fmin) → Solution, piecewise u" begin
                    φ = fmax * (t1_sol, fmin)
                    sol = φ((_T0, tf_sol), _X0, p0_sol; variable=tf_sol)
                    Test.@test sol isa CTModels.Solutions.Solution
                    uu = CTModels.control(sol)
                    _u(t) = uu(t) isa Number ? uu(t) : uu(t)[1]
                    Test.@test _u(0.5 * t1_sol) ≈ _UMAX atol = 1e-6                    # phase 1
                    Test.@test _u(t1_sol + 0.5 * (tf_sol - t1_sol)) ≈ _UMIN atol = 1e-6 # phase 2
                    Test.@test CTModels.objective(sol) ≈ tf_sol atol = 1e-3            # tf → min
                end
            end
        end
    end
end

end # module

test_double_integrator_time() = TestDoubleIntegratorTime.test_double_integrator_time()
