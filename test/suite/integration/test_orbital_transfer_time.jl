"""
End-to-end integration test for the ORBITAL TRANSFER TIME minimisation problem
(bang single arc, 4D): Keplerian dynamics with low-thrust control, `tf` free
(variable `v[1] = tf`), minimise `tf`. Ported from CTProblems.jl
`OrbitalTransferTime`.

Single-arc shooting (free tf, 5 equations, 5 unknowns `[p0[1:4], tf]`).
- Bang control: `u = γ_max * [p₃, p₄] / ||p[3:4]||`
- Boundary: `||x(tf)[1:2]|| = rf`, `x₃(tf) + α*x₂(tf) = 0`, `x₄(tf) - α*x₁(tf) = 0`
- Transversality: `H̃*(tf) = 1` (Mayer `M = tf`, minimisation)
- Extra transversality for free final angle: `x₂*(p₁+α*p₄) - x₁*(p₂-α*p₃) = 0`

The bang control depends only on `p` (not `x`), so `:total` and `:partial` coincide
— asserted for both.
"""
module TestOrbitalTransferTime

using Test: Test
import CTModels: CTModels
import CTFlows.Flows
using OrdinaryDiffEqTsit5
using ForwardDiff: ForwardDiff
using NonlinearSolve: NonlinearProblem, SimpleNewtonRaphson, solve

include(joinpath(@__DIR__, "utils.jl"))

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# Problem constants (from CTProblems.jl, F_max = 100 N)
const _T0 = 0.0
const _X0 = [-42272.67, 0.0, 0.0, -5796.72]
const _MU = 5.1658620912e12
const _RF = 42165.0
const _RF3 = _RF^3
const _M0 = 2000.0
const _F_MAX = 100.0
const _GAMMA_MAX = _F_MAX * 3600.0^2 / (_M0 * 1e3)
const _ALPHA = sqrt(_MU / _RF3)

# CTProblems initial guess (F_max = 100 N)
const _XI_GUESS = [
    0.00010323118913618907,
    4.89264278123618e-5,
    0.0003567967293906554,
    -0.0001553613886286001,
    13.403181957149329,
]

# Placeholder — will be updated after Newton convergence
const _XI_SOL = _XI_GUESS

function _build_orbital_transfer_time()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.variable!(pre, 1)
    CTModels.Building.time!(pre; t0=_T0, indf=1)  # free final time = variable[1]
    CTModels.Building.state!(pre, 4)
    CTModels.Building.control!(pre, 2)
    # Dynamics: Keplerian + control
    CTModels.Building.dynamics!(
        pre, (r, t, x, u, v) -> begin
            r1 = sqrt(x[1]^2 + x[2]^2)
            r[1] = x[3]
            r[2] = x[4]
            r[3] = -_MU * x[1] / r1^3 + u[1]
            r[4] = -_MU * x[2] / r1^3 + u[2]
            return nothing
        end
    )
    # Mayer: minimise tf
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> v[1])
    # Control norm constraint: ||u||² ≤ γ_max²
    CTModels.Building.constraint!(
        pre,
        :path;
        f=(r, t, x, u, v) -> (r[1]=u[1]^2 + u[2]^2 - _GAMMA_MAX^2; nothing),
        lb=[-Inf],
        ub=[0.0],
        label=:u_con,
    )
    # Final boundary constraint
    CTModels.Building.constraint!(
        pre,
        :boundary;
        f=(r, x0, xf, v) -> begin
            r[1] = sqrt(xf[1]^2 + xf[2]^2) - _RF
            r[2] = xf[3] + _ALPHA * xf[2]
            r[3] = xf[4] - _ALPHA * xf[1]
            return nothing
        end,
        lb=[0.0, 0.0, 0.0],
        ub=[0.0, 0.0, 0.0],
        label=:boundary_con,
    )
    return CTModels.Building.build(pre)
end

# Bang control: u = γ_max * [p₃, p₄] / ||p[3:4]||
_control_law(x, p, v) = _GAMMA_MAX * [p[3], p[4]] / sqrt(p[3]^2 + p[4]^2)

# Pseudo-Hamiltonian H̃ = p·f (for transversality computation)
function _ham(x, p)
    let u = _control_law(x, p, nothing)
        r1 = sqrt(x[1]^2 + x[2]^2)
        p[1] * x[3] +
        p[2] * x[4] +
        p[3] * (-_MU * x[1] / r1^3 + u[1]) +
        p[4] * (-_MU * x[2] / r1^3 + u[2])
    end
end

function test_orbital_transfer_time()
    Test.@testset "Orbital transfer — time minimisation (:total/:partial)" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = _build_orbital_transfer_time()

        for ht in (:total, :partial)
            f = Flows.Flow(
                ocp,
                _control_law;
                hamiltonian_type=ht,
                alg=Tsit5(),
                reltol=1e-12,
                abstol=1e-12,
            )

            function shoot!(s, ξ)
                p0 = ξ[1:4]
                tf = ξ[5]
                xf, pf = f(_T0, _X0, p0, tf; variable=tf)
                s[1] = sqrt(xf[1]^2 + xf[2]^2) - _RF
                s[2] = xf[3] + _ALPHA * xf[2]
                s[3] = xf[4] - _ALPHA * xf[1]
                s[4] = xf[2] * (pf[1] + _ALPHA * pf[4]) - xf[1] * (pf[2] - _ALPHA * pf[3])
                s[5] = _ham(xf, pf) - 1.0
                return nothing
            end

            ξ_opt = test_shooting(shoot!, _XI_SOL, _XI_GUESS; atol=1e-4)

            Test.@test isapprox(ξ_opt[5], _XI_SOL[5]; atol=1e-2)

            # Reconstruction (:total only).
            if ht == :total
                sol = f((_T0, ξ_opt[5]), _X0, ξ_opt[1:4]; variable=ξ_opt[5])
                Test.@test sol isa CTModels.Solutions.Solution
            end
        end
    end
end

end # module

test_orbital_transfer_time() = TestOrbitalTransferTime.test_orbital_transfer_time()
