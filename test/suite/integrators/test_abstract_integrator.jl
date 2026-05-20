module TestAbstractIntegrator

import Test
import CTBase.Exceptions
import CTFlows.Integrators
import CTFlows.Systems
import CTFlows.Common
import CTSolvers: CTSolvers

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for contract testing
# ==============================================================================

"""
Fake system for testing the AbstractIntegrator contract.
"""
struct FakeSystem <: Systems.AbstractSystem{Common.Autonomous, Common.Fixed}
    state_dim::Int
end

"""
Fake integration result for testing merge stub behavior.
"""
struct FakeIntegrationResult <: Integrators.AbstractIntegrationResult
    data::Vector{Float64}
end

Integrators.final_state(r::FakeIntegrationResult) = r.data
Integrators.times(r::FakeIntegrationResult) = collect(eachindex(r.data))
Integrators.evaluate_at(r::FakeIntegrationResult, t::Real) = r.data[Int(clamp(round(t), 1, length(r.data)))]

"""
Fake integrator for testing the AbstractIntegrator contract.

This minimal implementation provides all three required callable signatures
to test routing and default behavior without full integrator complexity.
"""
struct FakeIntegrator <: Integrators.AbstractIntegrator
    options::CTSolvers.Strategies.StrategyOptions
end

function FakeIntegrator()
    return FakeIntegrator(CTSolvers.Strategies.StrategyOptions())
end

# Implement the three required callable signatures
function Integrators.build_problem(integ::FakeIntegrator, system::Systems.AbstractSystem, config::Common.AbstractConfig; variable, cache)
    p = Common.ODEParameters(variable)
    return :fake_ode_problem
end

function Integrators.build_options(integ::FakeIntegrator, config::Union{Common.AbstractConfig, Nothing})
    return Dict{Symbol,Any}()
end

function Integrators.solve_problem(integ::FakeIntegrator, prob, options::Dict{Symbol,Any})
    return :fake_ode_solution
end

"""
Minimal integrator that does not implement the contract (for error testing).
"""
struct MinimalIntegrator <: Integrators.AbstractIntegrator
    options::CTSolvers.Strategies.StrategyOptions
end

function MinimalIntegrator()
    return MinimalIntegrator(CTSolvers.Strategies.StrategyOptions())
end

# ==============================================================================
# Test function
# ==============================================================================

function test_abstract_integrator()
    Test.@testset "Abstract ODE Integrator Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            integ = FakeIntegrator()
            Test.@test integ isa Integrators.AbstractIntegrator
            Test.@test integ isa CTSolvers.Strategies.AbstractStrategy

            minimal = MinimalIntegrator()
            Test.@test minimal isa Integrators.AbstractIntegrator
        end

        # ====================================================================
        # UNIT TESTS - Contract Implementation
        # ====================================================================

        Test.@testset "Contract Implementation" begin
            integ = FakeIntegrator()
            sys = FakeSystem(2)
            config = Common.StatePointConfig(0.0, [1.0, 0.0], 1.0)

            Test.@testset "Problem building signature" begin
                result = Integrators.build_problem(integ, sys, config; variable=nothing, cache=nothing)
                Test.@test result === :fake_ode_problem
            end

            Test.@testset "Integration signature" begin
                result = Integrators.solve_problem(integ, :fake_prob, Dict{Symbol,Any}())
                Test.@test result === :fake_ode_solution
            end

            Test.@testset "build_options signature" begin
                config = Common.StatePointConfig(0.0, [1.0, 0.0], 1.0)
                opts = Integrators.build_options(integ, config)
                Test.@test opts isa Dict{Symbol,Any}
            end
        end

        # ====================================================================
        # UNIT TESTS - NotImplemented Errors
        # ====================================================================

        Test.@testset "NotImplemented Errors" begin
            integ = MinimalIntegrator()
            sys = FakeSystem(2)
            config = Common.StatePointConfig(0.0, [1.0, 0.0], 1.0)

            Test.@testset "Problem building throws NotImplemented" begin
                Test.@test_throws Exceptions.NotImplemented Integrators.build_problem(integ, sys, config; variable=nothing, cache=nothing)
            end

            Test.@testset "Integration throws NotImplemented" begin
                Test.@test_throws Exceptions.NotImplemented Integrators.solve_problem(integ, :fake_prob, Dict{Symbol,Any}())
            end

            Test.@testset "build_options throws NotImplemented" begin
                config = Common.StatePointConfig(0.0, [1.0, 0.0], 1.0)
                Test.@test_throws Exceptions.NotImplemented Integrators.build_options(integ, config)
            end

            Test.@testset "merge throws NotImplemented" begin
                result = FakeIntegrationResult([1.0, 2.0])
                Test.@test_throws Exceptions.NotImplemented Integrators.merge([result])
                Test.@test_throws Exceptions.NotImplemented Integrators.merge(FakeIntegrationResult[])
            end
        end
    end
end

end # module

test_abstract_integrator() = TestAbstractIntegrator.test_abstract_integrator()
