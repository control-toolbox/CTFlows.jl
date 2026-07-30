"""
Integration tests for combined control + variable parameter problems.
Based on OptimalControl.jl `example-control-and-variable`.
"""
module TestControlAndVariable

using Test: Test
using CTModels: CTModels
using CTFlows: Flows
using OrdinaryDiffEqTsit5
using NonlinearSolve: NonlinearProblem, SimpleNewtonRaphson, solve

include(joinpath(@__DIR__, "utils.jl"))

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const _T0 = 0.0
const _TF_G1 = 2.0
const _TF_G2 = 1.0

# Reference solutions (user-provided)
const _G1_P0_SOL = 0.04754487290047068
const _G1_LAMBDA_SOL = 0.49342678059355
const _G2_P0_SOL = [-2.059399403520461, -2.413456067425259]
const _G2_OMEGA_SOL = -0.6537637061616014

# Exponential growth reference data (same as control-free)
data(t) = 2.0 * exp(0.5 * t) + 0.2 * sin(4.0 * π * t)

function _build_exponential_growth_control()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=false)
    CTModels.Building.variable!(pre, 1, "λ")
    CTModels.Building.time!(pre; t0=_T0, tf=_TF_G1)
    CTModels.Building.state!(pre, 1, "x")
    CTModels.Building.control!(pre, 1)

    function dyn!(dx, t, x, u, v)
        dx[1] = v[1] * x[1] + u[1]
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
        return (x[1] - data(t))^2 + 0.5 * u[1]^2
    end
    CTModels.Building.objective!(pre, :min; lagrange=lag)

    return CTModels.Building.build(pre)
end

function _build_harmonic_oscillator_control()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.variable!(pre, 1, "ω")
    CTModels.Building.time!(pre; t0=_T0, tf=_TF_G2)
    CTModels.Building.state!(pre, 2, "x", ["q", "v"])
    CTModels.Building.control!(pre, 1)

    function dyn!(dx, t, x, u, v)
        dx[1] = x[2]
        dx[2] = -v[1]^2 * x[1] + u[1]
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

    CTModels.Building.objective!(
        pre, :min; mayer=(x0, xf, v) -> v[1]^2, lagrange=(t, x, u, v) -> 0.5 * u[1]^2
    )

    return CTModels.Building.build(pre)
end

function test_control_and_variable()
    Test.@testset "Control + variable parameter" verbose=VERBOSE showtiming=SHOWTIMING begin

        # -------------------------------------------------------------------
        # G.1 — Exponential growth with control
        # -------------------------------------------------------------------
        Test.@testset "G.1: exponential growth with control (:total/:partial)" begin
            ocp = _build_exponential_growth_control()

            for ht in (:total, :partial)
                # non-autonomous + variable + control ⇒ arity (t, x, p, v); u* = p (scalar)
                f = Flows.Flow(
                    ocp,
                    (t, x, p, v) -> p;
                    hamiltonian_type=ht,
                    alg=Tsit5(),
                    reltol=1e-12,
                    abstol=1e-12,
                )

                function shoot!(s, ξ)
                    p0, λ = ξ[1], ξ[2]
                    xf, pf, pvf = f(
                        _T0, 2.0, p0, _TF_G1; variable=[λ], variable_costate=true
                    )
                    s[1] = pf                              # p(tf) = 0 (free final state)
                    s[2] = pvf                             # pλ(tf) = 0 (no Mayer on λ)
                    return nothing
                end

                ξ_guess = [0.0475, 0.4934]
                ξ_opt = test_shooting(
                    shoot!, [_G1_P0_SOL, _G1_LAMBDA_SOL], ξ_guess; atol=1e-8
                )

                Test.@test isapprox(ξ_opt[1], _G1_P0_SOL; atol=1e-6)
                Test.@test isapprox(ξ_opt[2], _G1_LAMBDA_SOL; atol=1e-6)
            end
        end

        # -------------------------------------------------------------------
        # G.2 — Harmonic oscillator with control
        # -------------------------------------------------------------------
        Test.@testset "G.2: harmonic oscillator with control (:total/:partial)" begin
            ocp = _build_harmonic_oscillator_control()

            for ht in (:total, :partial)
                # autonomous + variable + control ⇒ arity (x, p, v); u* = p₂
                f = Flows.Flow(
                    ocp,
                    (x, p, v) -> p[2];
                    hamiltonian_type=ht,
                    alg=Tsit5(),
                    reltol=1e-12,
                    abstol=1e-12,
                )

                function shoot!(s, ξ)
                    pq0, pv0, ω = ξ[1], ξ[2], ξ[3]
                    x0 = [1.0, 0.0]
                    p0 = [pq0, pv0]
                    xf, pf, pvf = f(
                        _T0, x0, p0, _TF_G2; variable=[ω], variable_costate=true
                    )
                    s[1] = xf[1]                           # q(tf) = 0
                    s[2] = pf[2]                           # pv(tf) = 0 (free final velocity)
                    s[3] = pvf + 2.0 * ω                   # pω(tf) + ∂g/∂ω = 0, g(ω)=ω²
                    return nothing
                end

                ξ_guess = [-2.06, -2.41, -0.65]
                ξ_opt = test_shooting(
                    shoot!, [_G2_P0_SOL; _G2_OMEGA_SOL], ξ_guess; atol=1e-8
                )

                # Sign of ω is irrelevant (cost is ω²), assert on abs
                Test.@test isapprox(abs(ξ_opt[3]), abs(_G2_OMEGA_SOL); atol=1e-6)
                Test.@test isapprox(ξ_opt[1:2], _G2_P0_SOL; atol=1e-6)
            end
        end
    end
end

end # module

function test_control_and_variable()
    return TestControlAndVariable.test_control_and_variable()
end
