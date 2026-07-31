"""
Integration test for the singular control example from OptimalControl.jl
(`example-singular-control`): 3D vehicle steering with time-optimal transfer.

State q = (x, y, θ) ∈ R³, control u ∈ R (|u| ≤ 1), free final time tf (variable).
Dynamics: ẋ = cos θ, ẏ = sin θ + x, θ̇ = u.
Boundary: x(0) = 0, y(0) = 0, x(tf) = 1, y(tf) = 0, θ(0) and θ(tf) free.
Objective: tf → min.

The optimal solution is singular throughout: the switching function H₁ = p₃
vanishes identically, yielding the singular feedback control u_s(θ) = sin²θ.

Shooting (5 equations, 5 unknowns [p₁₀, p₂₀, p₃₀, θ₀, tf]):
  s[1] = qf[1] - 1          # x(tf) = 1
  s[2] = qf[2]              # y(tf) = 0
  s[3] = p0[3]              # pθ(0) = 0 (free initial θ)
  s[4] = pf[3]              # pθ(tf) = 0 (free final θ)
  s[5] = pf[1]*cos(qf[3]) + pf[2]*(sin(qf[3]) + 1) - 1   # H(tf) = 1 (time-optimal)
"""
module TestSingularControl

using Test: Test
using CTModels: CTModels
using CTFlows: Flows
using OrdinaryDiffEqTsit5
using NonlinearSolve: NonlinearProblem, SimpleNewtonRaphson, solve

include(joinpath(@__DIR__, "..", "..", "suite", "integration", "utils.jl"))

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const _T0 = 0.0

# Reference solution (converged shooting solution)
const _P0_SOL = [0.7826328345972628, -0.6224836111984365, 0.0]
const _TH0_SOL = -0.6719121189983684
const _TF_SOL = 1.1497308858208615
const _XI_SOL = [_P0_SOL; _TH0_SOL; _TF_SOL]

# Direct method solution (used as initial guess for shooting)
const _P0_DIRECT = [0.784064017685243, -0.6224842865890237, 9.564334353787437e-8]
const _TH0_DIRECT = -0.6717544714481044
const _TF_DIRECT = 1.1497309627876084
const _XI_DIRECT = [_P0_DIRECT; _TH0_DIRECT; _TF_DIRECT]

function _build_singular_control()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.variable!(pre, 1, "tf")
    CTModels.Building.time!(pre; t0=_T0, indf=1)   # free final time = variable[1]
    CTModels.Building.state!(pre, 3, "q", ["x", "y", "θ"])
    CTModels.Building.control!(pre, 1)

    function dyn!(dq, t, q, u, v)
        dq[1] = cos(q[3])
        dq[2] = sin(q[3]) + q[1]
        dq[3] = u[1]
        return nothing
    end
    CTModels.Building.dynamics!(pre, dyn!)

    CTModels.Building.constraint!(
        pre, :control; rg=1:1, lb=[-1.0], ub=[1.0], label=:u_bounds
    )

    function boundary!(b, q0, qf, v)
        b[1] = q0[1]            # x(0) = 0
        b[2] = q0[2]            # y(0) = 0
        b[3] = qf[1] - 1.0      # x(tf) = 1
        b[4] = qf[2]            # y(tf) = 0
        return nothing
    end
    CTModels.Building.constraint!(
        pre, :boundary; f=boundary!, lb=zeros(4), ub=zeros(4), label=:endpoint
    )

    CTModels.Building.objective!(pre, :min; mayer=(q0, qf, v) -> v[1])

    return CTModels.Building.build(pre)
end

function test_singular_control()
    Test.@testset "Singular control — 3D steering time-optimal (:total/:partial)" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = _build_singular_control()

        for ht in (:total, :partial)
            # Singular feedback control: u_s(θ) = sin²θ
            # autonomous + variable + control ⇒ arity (x, p, v)
            f = Flows.Flow(
                ocp,
                (x, p, v) -> sin(x[3])^2;
                hamiltonian_type=ht,
                alg=Tsit5(),
                reltol=1e-12,
                abstol=1e-12,
            )

            function shoot!(s, ξ)
                p10, p20, p30, θ0, tf = ξ[1], ξ[2], ξ[3], ξ[4], ξ[5]
                q0 = [0.0, 0.0, θ0]
                p0 = [p10, p20, p30]
                qf, pf = f(_T0, q0, p0, tf; variable=tf)
                s[1] = qf[1] - 1.0                        # x(tf) = 1
                s[2] = qf[2]                              # y(tf) = 0
                s[3] = p0[3]                              # pθ(0) = 0
                s[4] = pf[3]                              # pθ(tf) = 0
                s[5] = pf[1] * cos(qf[3]) + pf[2] * (sin(qf[3]) + 1.0) - 1.0  # H(tf) = 1
                return nothing
            end

            # Initial guess from the direct method solution
            ξ_opt = test_shooting(shoot!, _XI_SOL, _XI_DIRECT; atol=1e-8)

            Test.@test isapprox(ξ_opt[1], _P0_SOL[1]; atol=1e-6)
            Test.@test isapprox(ξ_opt[2], _P0_SOL[2]; atol=1e-6)
            Test.@test isapprox(ξ_opt[3], _P0_SOL[3]; atol=1e-6)
            Test.@test isapprox(ξ_opt[4], _TH0_SOL; atol=1e-6)
            Test.@test isapprox(ξ_opt[5], _TF_SOL; atol=1e-6)

            # Reconstruction (only for :total to avoid redundant check)
            if ht == :total
                sol = f((_T0, _TF_SOL), [0.0, 0.0, _TH0_SOL], _P0_SOL; variable=_TF_SOL)
                Test.@test sol isa CTModels.Solutions.Solution
                Test.@test CTModels.objective(sol) > 0
                # PINNED REFERENCE — regression guard, NOT a derived optimum (no closed form used).
                Test.@test CTModels.objective(sol) ≈ 1.1497308858 rtol = 1e-6
            end
        end
    end
end

end # module

function test_singular_control()
    return TestSingularControl.test_singular_control()
end
