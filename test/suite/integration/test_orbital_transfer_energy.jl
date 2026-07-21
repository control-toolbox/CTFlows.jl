"""
End-to-end integration test for the ORBITAL TRANSFER energy-minimisation problem
(smooth single arc, 4D state, 2D control): minimises `∫ 0.5‖u‖² dt` subject to
Keplerian dynamics with thrust acceleration.

Single-arc shooting (fixed tf, 4 equations, 4 unknowns `p0 ∈ R⁴`).
Control law `u* = [p3, p4]` (smooth interior optimum from ∂H/∂u = 0).
Terminal conditions: circular orbit at radius `rf` with angular velocity `α`.
Transversality: `xf₂(pf₁+αpf₄) - xf₁(pf₂-αpf₃) = 0`.

The Lagrangian `L = 0.5‖u‖²` has no x-dependence, so `:total` and `:partial` give
identical adjoint equations — asserted for both.
"""
module TestOrbitalTransferEnergy

using Test: Test
import CTModels: CTModels
import CTFlows.Flows
using OrdinaryDiffEqTsit5
using ForwardDiff: ForwardDiff
using NonlinearSolve: NonlinearProblem, SimpleNewtonRaphson, solve

include(joinpath(@__DIR__, "utils.jl"))

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# Physical constants
const _MU = 5.1658620912e12
const _RF = 42165.0
const _ALPHA = sqrt(_MU / _RF^3)
const _T0 = 0.0
const _TF = 20.0
const _X0 = [-42272.67, 0.0, 0.0, -5796.72]

# Initial guess from CTProblems (sol.costate(t0) of the direct solution)
const _XI_GUESS = [131.44483634894812, 34.16617425875177, 249.15735272382514, -23.9732920001312]

# Converged Newton solution (residual ‖s‖ ≈ 4.8e-7)
const _XI_SOL = [131.44483633584628, 34.16617425833765, 249.1573527073759, -23.97329203256135]

function _build_orbital_transfer()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=_T0, tf=_TF)
    CTModels.Building.state!(pre, 4)
    CTModels.Building.control!(pre, 2)
    function dyn!(r, t, x, u, v)
        r1 = sqrt(x[1]^2 + x[2]^2)
        r1c = r1^3
        r[1] = x[3]
        r[2] = x[4]
        r[3] = -_MU * x[1] / r1c + u[1]
        r[4] = -_MU * x[2] / r1c + u[2]
        return nothing
    end
    CTModels.Building.dynamics!(pre, dyn!)
    CTModels.Building.objective!(
        pre, :min; lagrange=(t, x, u, v) -> 0.5 * (u[1]^2 + u[2]^2)
    )
    return CTModels.Building.build(pre)
end

function test_orbital_transfer_energy()
    Test.@testset "Orbital transfer — energy minimisation (:total/:partial)" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = _build_orbital_transfer()

        for ht in (:total, :partial)
            # Smooth control: u* = [p3, p4] from ∂H/∂u = 0
            # Autonomous, no variable ⇒ arity (x, p)
            f = Flows.Flow(
                ocp, (x, p) -> [p[3], p[4]];
                hamiltonian_type=ht, alg=Tsit5(), reltol=1e-12, abstol=1e-12,
            )

            function shoot!(s, ξ)
                p0 = ξ
                xf, pf = f(_T0, _X0, p0, _TF)
                s[1] = sqrt(xf[1]^2 + xf[2]^2) - _RF
                s[2] = xf[3] + _ALPHA * xf[2]
                s[3] = xf[4] - _ALPHA * xf[1]
                s[4] = xf[2] * (pf[1] + _ALPHA * pf[4]) - xf[1] * (pf[2] - _ALPHA * pf[3])
                return nothing
            end

            ξ_opt = test_shooting(shoot!, _XI_SOL, _XI_GUESS; atol=1e-6)

            Test.@test isapprox(ξ_opt[1], _XI_SOL[1]; atol=1e-4)
            Test.@test isapprox(ξ_opt[2], _XI_SOL[2]; atol=1e-4)
            Test.@test isapprox(ξ_opt[3], _XI_SOL[3]; atol=1e-4)
            Test.@test isapprox(ξ_opt[4], _XI_SOL[4]; atol=1e-4)

            # Reconstruction (:total only)
            if ht == :total
                sol = f((_T0, _TF), _X0, _XI_SOL)
                Test.@test sol isa CTModels.Solutions.Solution
            end
        end
    end
end

end # module

test_orbital_transfer_energy() = TestOrbitalTransferEnergy.test_orbital_transfer_energy()
