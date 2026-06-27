module TestGoddard

import Test
import CTBase.Data
import CTLie: CTLie
import CTFlows.Flows
import CTFlows.Trajectories
import DifferentiationInterface
using OrdinaryDiffEqTsit5
using NonlinearSolve: NonlinearSolve, NonlinearProblem, SimpleNewtonRaphson, solve

import CTBase: CTBase # For generated code by the @Lie macro (CTBase.Traits.*)

const VERBOSE    = isdefined(Main, :TestData) ? Main.TestData.VERBOSE    : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Goddard problem physics constants and dynamics (module-level)
# ==============================================================================

const _GODD_t0 = 0.0;  const _GODD_r0 = 1.0;  const _GODD_v0 = 0.0
const _GODD_m0 = 1.0;  const _GODD_vmax = 0.1; const _GODD_mf = 0.6
const _GODD_x0 = [_GODD_r0, _GODD_v0, _GODD_m0]
const _GODD_Cd = 310;  const _GODD_Tmax = 3.5;
const _GODD_β  = 500;  const _GODD_b   = 2

# Dynamics
function _godd_F0(x)
    r, v, m = x
    D = _GODD_Cd * v^2 * exp(-_GODD_β * (r - 1)) # Drag force
    return [v, -D/m - 1/r^2, 0]
end

function _godd_F1(x)
    r, v, m = x
    return [0, _GODD_Tmax/m, -_GODD_b*_GODD_Tmax]
end

# ==============================================================================
# Test function
# ==============================================================================

function test_goddard()
    Test.@testset "Goddard Rocket — Multi-Phase Integration Test" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ======================================================================
        # Build Hamiltonians (requires extensions to be loaded)
        # ======================================================================

        H0 = CTLie.Lift(_godd_F0)                   # H0(x, p) = p' * F0(x)
        H1 = CTLie.Lift(_godd_F1)                   # H1(x, p) = p' * F1(x)
        H01  = CTLie.@Lie {H0, H1}
        H001 = CTLie.@Lie {H0, H01}
        H101 = CTLie.@Lie {H1, H01}

        # ======================================================================
        # Control laws and pseudo-Hamiltonians
        # ======================================================================

        us(x, p) = -H001(x, p) / H101(x, p)          # singular control
        g(x) = _GODD_vmax - x[2]                     # state constraint v ≤ vmax
        ub(x) = -CTLie.ad(_godd_F0, g)(x) / CTLie.ad(_godd_F1, g)(x)          # boundary control
        μ(x, p) = H01(x, p) / (CTLie.ad(_godd_F1, g)(x))         # multiplier

        # Pseudo-Hamiltonian
        H(x, p, u) = (p' * _godd_F0(x) + u * p' * _godd_F1(x))

        # Hamiltonians
        Q0(x, p, tf) = H(x, p, 0)                            # off control
        Q1(x, p, tf) = H(x, p, 1)                            # bang control
        Qs(x, p, tf) = H(x, p, us(x, p))                     # singular arc
        Qb(x, p, tf) = H(x, p, ub(x)) + μ(x, p) * g(x)       # boundary arc

        # ======================================================================
        # Build flows
        # ======================================================================

        φ0 = Flows.Flow(Data.Hamiltonian(Q0; is_variable=true))
        φ1 = Flows.Flow(Data.Hamiltonian(Q1; is_variable=true))
        φs = Flows.Flow(Data.Hamiltonian(Qs; is_variable=true))
        φb = Flows.Flow(Data.Hamiltonian(Qb; is_variable=true))

        # ======================================================================
        # Known solution (from .extras/goddard-latest/goddard-latest.jl)
        # ======================================================================

        p0_sol = [3.945764658689699, 0.15039559623166285, 0.05371271293970429]
        t1_sol = 0.023509684041887746
        t2_sol = 0.05973738089985649
        t3_sol = 0.10157134842431054
        tf_sol = 0.2020474405709961

        # ======================================================================
        # Shooting function (nested, closes over constants and flows)
        # ======================================================================

        function shoot!(s, p0, t1, t2, t3, tf)
            x1, p1 = φ1(_GODD_t0, _GODD_x0, p0, t1; variable=tf)
            x2, p2 = φs(t1, x1, p1, t2; variable=tf)
            x3, p3 = φb(t2, x2, p2, t3; variable=tf)
            xf, pf = φ0(t3, x3, p3, tf; variable=tf)

            s[1] = xf[3] - _GODD_mf           # final mass constraint
            s[2:3] = pf[1:2] - [1, 0]        # transversality conditions
            s[4] = H1(x1, p1)                # H1 = H01 = 0 at entrance of singular arc
            s[5] = H01(x1, p1)               # at the entrance of the singular arc
            s[6] = g(x2)                     # g = 0 when entering the boundary arc
            s[7] = H0(xf, pf)                # since tf is free

            return nothing
        end

        # ======================================================================
        # Test 1: Flow type — trajectory call
        # ======================================================================

        Test.@testset "Flow type — trajectory call" begin
            φf = φ1 * (t1_sol, φs) * (t2_sol, φb) * (t3_sol, φ0)
            sol = φf((_GODD_t0, tf_sol), _GODD_x0, p0_sol; variable=tf_sol)
            Test.@test sol isa Trajectories.HamiltonianVectorFieldTrajectory
        end

        # ======================================================================
        # Test 2: Flow type — point call
        # ======================================================================

        Test.@testset "Flow type — point call" begin
            x1, p1 = φ1(_GODD_t0, _GODD_x0, p0_sol, t1_sol; variable=tf_sol)
            Test.@test length((x1, p1)) == 2
            Test.@test length(x1) == 3
            Test.@test length(p1) == 3
        end

        # ======================================================================
        # Test 3: Shooting residual — known solution
        # ======================================================================

        Test.@testset "Shooting residual — known solution" begin
            s = similar(p0_sol, 7)
            shoot!(s, p0_sol, t1_sol, t2_sol, t3_sol, tf_sol)
            Test.@test sqrt(sum(abs2, s)) < 1e-5
        end

        # ======================================================================
        # Test 4: NonlinearSolve convergence
        # ======================================================================

        Test.@testset "NonlinearSolve convergence" begin
            # Initial guess
            ξ0 = [[3.94, 0.15, 0.05]..., 0.02, 0.05, 0.10, 0.20]

            # Wrap shoot! for NonlinearSolve — (residual, u, p) signature required
            shoot!(s, ξ, _) = shoot!(s, ξ[1:3], ξ[4], ξ[5], ξ[6], ξ[7])

            prob = NonlinearProblem(shoot!, ξ0)
            nl_sol = solve(prob, SimpleNewtonRaphson(); abstol=1e-8, reltol=1e-8, show_trace=Val(false))

            # Check convergence
            ξ_opt = nl_sol.u
            s_converged = similar(p0_sol, 7)
            shoot!(s_converged, ξ_opt[1:3], ξ_opt[4], ξ_opt[5], ξ_opt[6], ξ_opt[7])
            Test.@test sqrt(sum(abs2, s_converged)) < 1e-7
        end

    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_goddard() = TestGoddard.test_goddard()
