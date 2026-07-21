"""
End-to-end integration test for the ORBITAL TRANSFERT CONSUMPTION minimisation problem
(bang-off-bang-off-bang, 5 arcs "B+B0B+B0B+"): Keplerian dynamics with low-thrust
control, `tf = 1.5 * tf_min` fixed, minimise `∫ ||u|| dt`. Ported from CTProblems.jl
`OrbitalTransfertConsumption`.

Multi-arc shooting (fixed tf, 8 equations, 8 unknowns `[p0[1:4], t1, t2, t3, t4]`).
- Bang arc: `u = p[3:4] / ||p[3:4]||` (||u|| = 1, max thrust)
- Off arc: `u = [0, 0]` (no thrust)
- Switching condition: `γ_max * ||p[3:4]|| = 1` (H_bang = H_off)
- Boundary: `||x(tf)[1:2]|| = rf`, `x₃(tf) + α*x₂(tf) = 0`, `x₄(tf) - α*x₁(tf) = 0`
- Transversality: `x₂*(p₁+α*p₄) - x₁*(p₂-α*p₃) = 0` (free final angle)

The bang control depends on p, so `:total` and `:partial` may differ in general,
but both are tested. Multi-phase reconstruction via `*` composition.
"""
module TestOrbitalTransfertConsumption

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
const _TF_MIN = 13.40318195708344
const _TF = 1.5 * _TF_MIN

# CTProblems initial guess (F_max = 100 N), p0[5] ≈ 0 removed
const _P0_GUESS = [
    0.02698412111231433,
    0.006910835140705538,
    0.050397371862031096,
    -0.0032972040120747836,
]
const _TI_GUESS = [
    0.4556797711668658,
    3.6289692721936913,
    11.683607683450061,
    12.505465498856514,
]
const _XI_GUESS = [deepcopy(_P0_GUESS); deepcopy(_TI_GUESS)]

function _build_orbital_transfert_consumption()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=_T0, tf=_TF)
    CTModels.Building.state!(pre, 4)
    CTModels.Building.control!(pre, 2)
    # Dynamics: Keplerian + γ_max * u
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> begin
        r1 = sqrt(x[1]^2 + x[2]^2)
        r[1] = x[3]
        r[2] = x[4]
        r[3] = -_MU * x[1] / r1^3 + _GAMMA_MAX * u[1]
        r[4] = -_MU * x[2] / r1^3 + _GAMMA_MAX * u[2]
        return nothing
    end)
    # Lagrange: ||u||
    CTModels.Building.objective!(
        pre, :min; lagrange=(t, x, u, v) -> sqrt(u[1]^2 + u[2]^2),
    )
    # Control norm constraint: ||u||² ≤ 1
    CTModels.Building.constraint!(
        pre, :path; f=(r, t, x, u, v) -> (r[1] = u[1]^2 + u[2]^2 - 1.0; nothing),
        lb=[-Inf], ub=[0.0], label=:u_con,
    )
    # Final boundary constraint
    CTModels.Building.constraint!(
        pre, :boundary;
        f=(r, x0, xf, v) -> begin
            r[1] = sqrt(xf[1]^2 + xf[2]^2) - _RF
            r[2] = xf[3] + _ALPHA * xf[2]
            r[3] = xf[4] - _ALPHA * xf[1]
            return nothing
        end,
        lb=[0.0, 0.0, 0.0], ub=[0.0, 0.0, 0.0], label=:boundary_con,
    )
    return CTModels.Building.build(pre)
end

# Bang control: u = p[3:4] / ||p[3:4]||
_bang_law(x, p) = [p[3], p[4]] / sqrt(p[3]^2 + p[4]^2)

# Off control: u = [0, 0]
_off_law(x, p) = [0.0, 0.0]

function test_orbital_transfert_consumption()
    Test.@testset "Orbital transfert — consumption B+B0B+B0B+ (:total/:partial)" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = _build_orbital_transfert_consumption()

        for ht in (:total, :partial)
            f_bang = Flows.Flow(
                ocp, _bang_law;
                hamiltonian_type=ht, alg=Tsit5(), reltol=1e-12, abstol=1e-12,
            )
            f_off = Flows.Flow(
                ocp, _off_law;
                hamiltonian_type=ht, alg=Tsit5(), reltol=1e-12, abstol=1e-12,
            )

            function shoot!(s, ξ)
                p0 = ξ[1:4]
                t1, t2, t3, t4 = ξ[5], ξ[6], ξ[7], ξ[8]
                x1, p1 = f_bang(_T0, _X0, p0, t1)
                x2, p2 = f_off(t1, x1, p1, t2)
                x3, p3 = f_bang(t2, x2, p2, t3)
                x4, p4 = f_off(t3, x3, p3, t4)
                xf, pf = f_bang(t4, x4, p4, _TF)
                s[1] = sqrt(xf[1]^2 + xf[2]^2) - _RF
                s[2] = xf[3] + _ALPHA * xf[2]
                s[3] = xf[4] - _ALPHA * xf[1]
                s[4] = xf[2] * (pf[1] + _ALPHA * pf[4]) - xf[1] * (pf[2] - _ALPHA * pf[3])
                # Switching: γ_max * (p3² + p4²) = 1 (CTProblems convention)
                s[5] = _GAMMA_MAX * (p1[3]^2 + p1[4]^2) - 1.0
                s[6] = _GAMMA_MAX * (p2[3]^2 + p2[4]^2) - 1.0
                s[7] = _GAMMA_MAX * (p3[3]^2 + p3[4]^2) - 1.0
                s[8] = _GAMMA_MAX * (p4[3]^2 + p4[4]^2) - 1.0
                return nothing
            end

            ξ_opt = test_shooting(shoot!, _XI_GUESS, _XI_GUESS; atol=1e-4)

            # Reconstruction (:total only).
            if ht == :total
                p0 = ξ_opt[1:4]
                t1, t2, t3, t4 = ξ_opt[5], ξ_opt[6], ξ_opt[7], ξ_opt[8]
                φ = f_bang * (t1, f_off) * (t2, f_bang) * (t3, f_off) * (t4, f_bang)
                sol = φ((_T0, _TF), _X0, p0)
                Test.@test sol isa CTModels.Solutions.Solution
            end
        end
    end
end

end # module

test_orbital_transfert_consumption() =
    TestOrbitalTransfertConsumption.test_orbital_transfert_consumption()
