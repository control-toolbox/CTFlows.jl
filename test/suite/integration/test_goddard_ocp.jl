"""
End-to-end integration test for the Goddard optimal control problem, built from a
`CTModels.Model` (not the hand-built Hamiltonian of `test_goddard.jl`): four arcs
(boundary-departure, singular, velocity-boundary, off) rebuilt via `Flow(ocp, law)` and
`Flow(ocp, law; constraint, multiplier)`, and a 7-unknown multi-phase shooting run in both
`:total` and `:partial` — the hardest end-to-end witness that they converge to the same
known solution (`on-arc :total ≡ :partial`, see the constrained-flows design note). Also
exercises the `*` multi-phase reconstruction (a `CTModels.Solution`, PR 5 D3) and the
1-tuple constraint/multiplier convenience (PR 5 D1) on this problem.
"""
module TestGoddardOCP

using Test: Test
import CTBase.Data
import CTBase.Traits
import CTLie: CTLie
import CTModels: CTModels
import CTFlows.Flows
import CTFlows.Trajectories
using ForwardDiff: ForwardDiff  # triggers DifferentiationInterfaceForwardDiff
using OrdinaryDiffEqTsit5
using NonlinearSolve: NonlinearProblem, SimpleNewtonRaphson, solve

import CTBase: CTBase # For generated code by the @Lie macro (CTBase.Traits.*)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Goddard constants + dynamics (module-level), same as test_goddard.jl
# ==============================================================================

const _GODD_t0 = 0.0
const _GODD_r0 = 1.0
const _GODD_v0 = 0.0
const _GODD_m0 = 1.0
const _GODD_vmax = 0.1
const _GODD_mf = 0.6
const _GODD_x0 = [_GODD_r0, _GODD_v0, _GODD_m0]
const _GODD_Cd = 310
const _GODD_Tmax = 3.5
const _GODD_β = 500
const _GODD_b = 2

function _godd_F0(x)
    r, v, m = x
    D = _GODD_Cd * v^2 * exp(-_GODD_β * (r - 1))
    return [v, -D / m - 1 / r^2, 0]
end

function _godd_F1(x)
    r, v, m = x
    return [0, _GODD_Tmax / m, -_GODD_b * _GODD_Tmax]
end

# Goddard OCP: ẋ = F0(x) + u F1(x), free tf (variable), path constraint v ≤ vmax.
# Mayer-only objective (irrelevant to the pseudo-Hamiltonian flow: no Lagrange term).
function _build_goddard_ocp()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.state!(pre, 3)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.variable!(pre, 1)
    CTModels.Building.time!(pre; t0=_GODD_t0, indf=1)   # free final time = variable[1]
    CTModels.Building.dynamics!(
        pre, (r, t, x, u, v) -> (r .= _godd_F0(x) .+ u[1] .* _godd_F1(x); nothing)
    )
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> -xf[3])
    CTModels.Building.constraint!(
        pre,
        :path;
        f=(r, t, x, u, v) -> (r[1] = x[2]; nothing),
        lb=[-Inf],
        ub=[_GODD_vmax],
        label=:vmax,
    )
    return CTModels.Building.build(pre)
end

# ==============================================================================
# Test
# ==============================================================================

function test_goddard_ocp()
    Test.@testset "Goddard OCP-built flows — :total / :partial" verbose=VERBOSE showtiming=SHOWTIMING begin

        # Lie brackets / controls / multiplier (same as test_goddard.jl)
        H0 = CTLie.Lift(_godd_F0)
        H1 = CTLie.Lift(_godd_F1)
        H01 = CTLie.@Lie {H0, H1}
        H001 = CTLie.@Lie {H0, H01}
        H101 = CTLie.@Lie {H1, H01}

        us(x, p) = -H001(x, p) / H101(x, p)
        g(x) = _GODD_vmax - x[2]
        ub(x) = -CTLie.ad(_godd_F0, g)(x) / CTLie.ad(_godd_F1, g)(x)
        μ(x, p) = H01(x, p) / (CTLie.ad(_godd_F1, g)(x))

        # Known solution
        p0_sol = [3.945764658689699, 0.15039559623166285, 0.05371271293970429]
        t1_sol = 0.023509684041887746
        t2_sol = 0.05973738089985649
        t3_sol = 0.10157134842431054
        tf_sol = 0.2020474405709961

        ocp = _build_goddard_ocp()

        # Control laws as (x,p,v) feedbacks; constraint (x,u,v); multiplier (x,p,v).
        u0law(x, p, v) = 0.0
        u1law(x, p, v) = 1.0
        uslaw(x, p, v) = us(x, p)
        ublaw(x, p, v) = ub(x)
        gc(x, u, v) = _GODD_vmax - x[2]     # function ⇒ MixedConstraint (∂g/∂u = 0)
        μc(x, p, v) = μ(x, p)

        function _build_flows(ht)
            φ0 = Flows.Flow(ocp, u0law; hamiltonian_type=ht)
            φ1 = Flows.Flow(ocp, u1law; hamiltonian_type=ht)
            φs = Flows.Flow(ocp, uslaw; hamiltonian_type=ht)
            φb = Flows.Flow(ocp, ublaw; constraint=gc, multiplier=μc, hamiltonian_type=ht)
            return φ0, φ1, φs, φb
        end

        function _make_shoot(φ0, φ1, φs, φb)
            function shoot!(s, p0, t1, t2, t3, tf)
                x1, p1 = φ1(_GODD_t0, _GODD_x0, p0, t1; variable=tf)
                x2, p2 = φs(t1, x1, p1, t2; variable=tf)
                x3, p3 = φb(t2, x2, p2, t3; variable=tf)
                xf, pf = φ0(t3, x3, p3, tf; variable=tf)
                s[1] = xf[3] - _GODD_mf
                s[2:3] = pf[1:2] - [1, 0]
                s[4] = H1(x1, p1)
                s[5] = H01(x1, p1)
                s[6] = g(x2)
                s[7] = H0(xf, pf)
                return nothing
            end
            return shoot!
        end

        ξ_sol = [p0_sol..., t1_sol, t2_sol, t3_sol, tf_sol]

        for ht in (:total, :partial)
            φ0, φ1, φs, φb = _build_flows(ht)
            shoot! = _make_shoot(φ0, φ1, φs, φb)

            # Residual at the KNOWN solution
            s = zeros(7)
            shoot!(s, p0_sol, t1_sol, t2_sol, t3_sol, tf_sol)
            res_known = sqrt(sum(abs2, s))

            # Newton from the known solution's neighbourhood
            ξ0 = [3.94, 0.15, 0.05, 0.02, 0.05, 0.10, 0.20]
            shoot_nl!(s, ξ, _) = shoot!(s, ξ[1:3], ξ[4], ξ[5], ξ[6], ξ[7])
            prob = NonlinearProblem(shoot_nl!, ξ0)
            nl = solve(prob, SimpleNewtonRaphson(); abstol=1e-10, reltol=1e-10, show_trace=Val(false))
            sc = zeros(7)
            shoot!(sc, nl.u[1:3], nl.u[4], nl.u[5], nl.u[6], nl.u[7])
            res_conv = sqrt(sum(abs2, sc))
            dist_sol = sqrt(sum(abs2, nl.u .- ξ_sol))

            # On every Goddard arc the frozen-control :partial dynamics coincides with
            # :total: bang arcs have constant u; on the singular and boundary arcs
            # ∂H̃/∂u = H1 = 0 (PMP stationarity of the augmented Hamiltonian, ∂g/∂u = 0
            # for the state constraint); and g ≡ 0 on the boundary arc freezes μ soundly.
            # So both modes hit the same known solution — assert strictly for both.
            Test.@test res_known < 1e-5
            Test.@test res_conv < 1e-7
            Test.@test dist_sol < 1e-6

            # Reference arc-by-arc chain at the known solution (same chain as shoot!,
            # exposed here to cross-check the `*` multi-phase reconstruction below).
            x1r, p1r = φ1(_GODD_t0, _GODD_x0, p0_sol, t1_sol; variable=tf_sol)
            x2r, p2r = φs(t1_sol, x1r, p1r, t2_sol; variable=tf_sol)
            x3r, p3r = φb(t2_sol, x2r, p2r, t3_sol; variable=tf_sol)
            xfr, pfr = φ0(t3_sol, x3r, p3r, tf_sol; variable=tf_sol)

            if ht === :total
                Test.@testset "MultiPhase reconstruction: φ1*(t1,φs)*(t2,φb)*(t3,φ0) → Solution" begin
                    φ = φ1 * (t1_sol, φs) * (t2_sol, φb) * (t3_sol, φ0)

                    # point eval: reproduces the hand-chained arcs, right dimensions (ℝ³)
                    # (Hamiltonian dynamics returns the flat concatenation [x; p], not a
                    # (x, p) tuple — see MultiPhase._format_final_output)
                    res = φ(_GODD_t0, _GODD_x0, p0_sol, tf_sol; variable=tf_sol)
                    xf_multi, pf_multi = res[1:3], res[4:6]
                    Test.@test length(xf_multi) == 3
                    Test.@test length(pf_multi) == 3
                    Test.@test xf_multi ≈ xfr atol = 1e-8
                    Test.@test pf_multi ≈ pfr atol = 1e-8

                    # trajectory: same return type as a single-phase OCP flow
                    sol = φ((_GODD_t0, tf_sol), _GODD_x0, p0_sol; variable=tf_sol)
                    Test.@test sol isa CTModels.Solutions.Solution
                    Test.@test CTModels.state(sol)(tf_sol) ≈ xfr atol = 1e-3
                    Test.@test CTModels.costate(sol)(tf_sol) ≈ pfr atol = 1e-3
                end

                Test.@testset "1-tuple constraint/multiplier ≡ scalar form (boundary arc)" begin
                    φb_tuple = Flows.Flow(
                        ocp, ublaw; constraint=(gc,), multiplier=(μc,), hamiltonian_type=ht
                    )
                    x3t, p3t = φb_tuple(t2_sol, x2r, p2r, t3_sol; variable=tf_sol)
                    Test.@test x3t ≈ x3r atol = 1e-10
                    Test.@test p3t ≈ p3r atol = 1e-10
                end
            end
        end
    end
end

end # module

test_goddard_ocp() = TestGoddardOCP.test_goddard_ocp()
