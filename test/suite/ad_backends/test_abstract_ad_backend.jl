module TestAbstractADBackend

import Test
import CTBase.Exceptions
import CTFlows.ADBackends
import CTSolvers: CTSolvers

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Fake types for contract testing
# ==============================================================================

"""
Fake AD backend for testing the AbstractADBackend contract.
"""
struct FakeADBackend <: ADBackends.AbstractADBackend
    options::CTSolvers.Strategies.StrategyOptions
end

function FakeADBackend()
    return FakeADBackend(CTSolvers.Strategies.StrategyOptions())
end

function ADBackends.ctgradient(backend::FakeADBackend, f, x)
    return :fake_gradient
end

function ADBackends.ctjacobian(backend::FakeADBackend, f, x)
    return :fake_jacobian
end

"""
Minimal AD backend that does not implement the contract (for error testing).
"""
struct MinimalADBackend <: ADBackends.AbstractADBackend
    options::CTSolvers.Strategies.StrategyOptions
end

function MinimalADBackend()
    return MinimalADBackend(CTSolvers.Strategies.StrategyOptions())
end

# ==============================================================================
# Test function
# ==============================================================================

function test_abstract_ad_backend()
    Test.@testset "Abstract AD Backend Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            backend = FakeADBackend()
            Test.@test backend isa ADBackends.AbstractADBackend
            Test.@test backend isa CTSolvers.Strategies.AbstractStrategy

            minimal = MinimalADBackend()
            Test.@test minimal isa ADBackends.AbstractADBackend
        end

        # ====================================================================
        # UNIT TESTS - Contract Implementation
        # ====================================================================

        Test.@testset "Contract Implementation" begin
            backend = FakeADBackend()
            f = x -> x^2
            x = 1.0

            Test.@testset "ctgradient returns result" begin
                result = ADBackends.ctgradient(backend, f, x)
                Test.@test result === :fake_gradient
            end

            Test.@testset "ctjacobian returns result" begin
                result = ADBackends.ctjacobian(backend, f, x)
                Test.@test result === :fake_jacobian
            end
        end

        # ====================================================================
        # UNIT TESTS - NotImplemented Errors
        # ====================================================================

        Test.@testset "NotImplemented Errors" begin
            backend = MinimalADBackend()
            f = x -> x^2
            x = 1.0

            Test.@testset "ctgradient throws NotImplemented" begin
                Test.@test_throws Exceptions.NotImplemented ADBackends.ctgradient(backend, f, x)
            end

            Test.@testset "ctjacobian throws NotImplemented" begin
                Test.@test_throws Exceptions.NotImplemented ADBackends.ctjacobian(backend, f, x)
            end
        end
    end
end

end # module

test_abstract_ad_backend() = TestAbstractADBackend.test_abstract_ad_backend()
