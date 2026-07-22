"""
Integration tests for control-free optimal control problems: parameter optimization
via an augmented costate. Based on OptimalControl.jl `example-control-free`.
"""
module TestControlFree

using Test: Test
import CTModels: CTModels
import CTFlows.Flows
using OrdinaryDiffEqTsit5
using NonlinearSolve: NonlinearProblem, SimpleNewtonRaphson, solve

include(joinpath(@__DIR__, "utils.jl"))

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const _T0 = 0.0
const _TF_F1 = 2.0
const _TF_F2 = 1.0

# Reference solutions (user-provided)
const _F1_P0_SOL = 0.058478510601397186
const _F1_LAMBDA_SOL = 0.4966212669483583
const _F2_P0_SOL = [7.62813477748342e-15, -2.0000000000035025]
const _F2_OMEGA_SOL = 1.5707963267948069

# Exponential growth reference data
data(t) = 2.0 * exp(0.5 * t) + 0.2 * sin(4.0 * π * t)

function _build_exponential_growth()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=false)
    CTModels.Building.variable!(pre, 1, "λ")
    CTModels.Building.time!(pre; t0=_T0, tf=_TF_F1)
    CTModels.Building.state!(pre, 1, "x")

    function dyn!(dx, t, x, u, v)
        dx[1] = v[1] * x[1]
        return nothing
    end
    CTModels.Building.dynamics!(pre, dyn!)

    function boundary!(b, x0_, xf_, v)
        b[1] = x0_[1] - 2.0
        return nothing
    end
    CTModels.Building.constraint!(
        pre, :boundary; f=boundary!, lb=[0.0], ub=[0.0], label=:ic
    )

    function lag(t, x, u, v)
        return (x[1] - data(t))^2
    end
    CTModels.Building.objective!(pre, :min; lagrange=lag)

    return CTModels.Building.build(pre)
end

function _build_harmonic_oscillator()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.variable!(pre, 1, "ω")
    CTModels.Building.time!(pre; t0=_T0, tf=_TF_F2)
    CTModels.Building.state!(pre, 2, "x", ["q", "v"])

    function dyn!(dx, t, x, u, v)
        dx[1] = x[2]
        dx[2] = -v[1]^2 * x[1]
        return nothing
    end
    CTModels.Building.dynamics!(pre, dyn!)

    function boundary!(b, x0_, xf_, v)
        b[1] = x0_[1] - 1.0
        b[2] = x0_[2] - 0.0
        b[3] = xf_[1] - 0.0
        return nothing
    end
    CTModels.Building.constraint!(
        pre, :boundary; f=boundary!, lb=zeros(3), ub=zeros(3), label=:endpoint
    )

    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> v[1]^2)

    return CTModels.Building.build(pre)
end

function test_control_free()
    Test.@testset "Control-free parameter optimization" verbose=VERBOSE showtiming=SHOWTIMING begin

        # -------------------------------------------------------------------
        # F.1 — Exponential growth rate estimation
        # -------------------------------------------------------------------
        Test.@testset "F.1: exponential growth rate" begin
            ocp = _build_exponential_growth()
            f = Flows.Flow(ocp; alg=Tsit5(), reltol=1e-12, abstol=1e-12)

            function shoot!(s, ξ)
                p0, λ = ξ[1], ξ[2]
                xf, pf, pvf = f(_T0, 2.0, p0, _TF_F1; variable=[λ], variable_costate=true)
                s[1] = pf                              # p(tf) = 0
                s[2] = pvf                             # pλ(tf) = 0
                return nothing
            end

            # truncated guess as requested
            ξ_guess = [0.0585, 0.4966]
            ξ_opt = test_shooting(shoot!, [_F1_P0_SOL, _F1_LAMBDA_SOL], ξ_guess; atol=1e-8)

            Test.@test isapprox(ξ_opt[1], _F1_P0_SOL; atol=1e-6)
            Test.@test isapprox(ξ_opt[2], _F1_LAMBDA_SOL; atol=1e-6)
        end

        # -------------------------------------------------------------------
        # F.2 — Harmonic oscillator pulsation
        # -------------------------------------------------------------------
        Test.@testset "F.2: harmonic oscillator pulsation" begin
            ocp = _build_harmonic_oscillator()
            f = Flows.Flow(ocp; alg=Tsit5(), reltol=1e-12, abstol=1e-12)

            function shoot!(s, ξ)
                pq0, pv0, ω = ξ[1], ξ[2], ξ[3]
                x0 = [1.0, 0.0]
                p0 = [pq0, pv0]
                xf, pf, pvf = f(_T0, x0, p0, _TF_F2; variable=[ω], variable_costate=true)
                s[1] = xf[1]                           # q(tf) = 0
                s[2] = pf[2]                           # pv(tf) = 0 (free final velocity)
                s[3] = pvf + 2.0 * ω                   # pω(tf) + ∂g/∂ω = 0, g(ω)=ω²
                return nothing
            end

            ξ_guess = [0.0, -2.0, 1.57]
            ξ_opt = test_shooting(shoot!, [_F2_P0_SOL; _F2_OMEGA_SOL], ξ_guess; atol=1e-8)

            Test.@test isapprox(ξ_opt[3], _F2_OMEGA_SOL; atol=1e-6)
            Test.@test isapprox(ξ_opt[1:2], _F2_P0_SOL; atol=1e-6)
        end
    end
end

end # module

function test_control_free()
    return TestControlFree.test_control_free()
end
