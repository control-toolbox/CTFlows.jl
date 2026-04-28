module TestAbstractODEIntegrator

import Test
import CTBase.Exceptions
import CTFlows.Integrators
import CTSolvers: CTSolvers

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Fake types for contract testing
# ==============================================================================

"""
Fake integrator for testing the AbstractODEIntegrator contract.
"""
struct FakeIntegrator <: Integrators.AbstractODEIntegrator
    options::CTSolvers.Strategies.StrategyOptions
end

function FakeIntegrator()
    return FakeIntegrator(CTSolvers.Strategies.StrategyOptions())
end

function (integ::FakeIntegrator)(ode_problem, tspan)
    return :fake_solution
end

"""
Minimal integrator that does not implement the contract (for error testing).
"""
struct MinimalIntegrator <: Integrators.AbstractODEIntegrator
    options::CTSolvers.Strategies.StrategyOptions
end

function MinimalIntegrator()
    return MinimalIntegrator(CTSolvers.Strategies.StrategyOptions())
end

# ==============================================================================
# Test function
# ==============================================================================

function test_abstract_ode_integrator()
    Test.@testset "Abstract ODE Integrator Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            integ = FakeIntegrator()
            Test.@test integ isa Integrators.AbstractODEIntegrator
            Test.@test integ isa CTSolvers.Strategies.AbstractStrategy

            minimal = MinimalIntegrator()
            Test.@test minimal isa Integrators.AbstractODEIntegrator
        end

        # ====================================================================
        # UNIT TESTS - Contract Implementation
        # ====================================================================

        Test.@testset "Contract Implementation" begin
            integ = FakeIntegrator()

            Test.@testset "callable returns solution" begin
                result = integ(:fake_ode_problem, (0.0, 1.0))
                Test.@test result === :fake_solution
            end
        end

        # ====================================================================
        # UNIT TESTS - NotImplemented Errors
        # ====================================================================

        Test.@testset "NotImplemented Errors" begin
            integ = MinimalIntegrator()

            Test.@testset "callable throws NotImplemented" begin
                Test.@test_throws Exceptions.NotImplemented integ(:fake_ode_problem, (0.0, 1.0))
            end
        end
    end
end

end # module

test_abstract_ode_integrator() = TestAbstractODEIntegrator.test_abstract_ode_integrator()
