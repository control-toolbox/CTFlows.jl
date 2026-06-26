module TestIntegrationResult

import Test
import CTFlows.Integrators
import CTBase.Exceptions

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Fake type for stub testing
# ==============================================================================

struct FakeResult <: Integrators.AbstractIntegrationResult end

# ==============================================================================
# Test function
# ==============================================================================

function test_integration_result()
    Test.@testset "Integration Result Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - AbstractIntegrationResult
        # ====================================================================

        Test.@testset "AbstractIntegrationResult" begin
            Test.@testset "final_state throws NotImplemented on abstract type" begin
                result = FakeResult()
                
                Test.@test_throws Exceptions.NotImplemented Integrators.final_state(result)
            end

            Test.@testset "times throws NotImplemented on abstract type" begin
                result = FakeResult()
                
                Test.@test_throws Exceptions.NotImplemented Integrators.times(result)
            end

            Test.@testset "evaluate_at throws NotImplemented on abstract type" begin
                result = FakeResult()
                
                Test.@test_throws Exceptions.NotImplemented Integrators.evaluate_at(result, 0.0)
            end
        end

        # ====================================================================
        # UNIT TESTS - Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "AbstractIntegrationResult is exported" begin
                Test.@test isdefined(Integrators, :AbstractIntegrationResult)
            end

            Test.@testset "final_state is exported" begin
                Test.@test isdefined(Integrators, :final_state)
            end

            Test.@testset "times is exported" begin
                Test.@test isdefined(Integrators, :times)
            end

            Test.@testset "evaluate_at is exported" begin
                Test.@test isdefined(Integrators, :evaluate_at)
            end
        end
    end
end

end # module

test_integration_result() = TestIntegrationResult.test_integration_result()