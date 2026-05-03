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

# Implement the two required callable signatures
function Integrators.build_problem(integ::FakeIntegrator, system::Systems.AbstractSystem, config::Common.AbstractConfig; variable)
    p = Common.ODEParameters(variable)
    return :fake_ode_problem
end

function Integrators.solve_problem(integ::FakeIntegrator, prob)
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
            config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)

            Test.@testset "Problem building signature" begin
                result = Integrators.build_problem(integ, sys, config; variable=nothing)
                Test.@test result === :fake_ode_problem
            end

            Test.@testset "Integration signature" begin
                result = Integrators.solve_problem(integ, :fake_prob)
                Test.@test result === :fake_ode_solution
            end
        end

        # ====================================================================
        # UNIT TESTS - NotImplemented Errors
        # ====================================================================

        Test.@testset "NotImplemented Errors" begin
            integ = MinimalIntegrator()
            sys = FakeSystem(2)
            config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)

            Test.@testset "Problem building throws NotImplemented" begin
                Test.@test_throws Exceptions.NotImplemented Integrators.build_problem(integ, sys, config; variable=nothing)
            end

            Test.@testset "Integration throws NotImplemented" begin
                Test.@test_throws Exceptions.NotImplemented Integrators.solve_problem(integ, :fake_prob)
            end
        end
    end
end

end # module

test_abstract_integrator() = TestAbstractIntegrator.test_abstract_integrator()
