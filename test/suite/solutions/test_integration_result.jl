module TestIntegrationResult

import Test
import CTFlows.Solutions
import CTBase.Exceptions

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake type for stub testing
# ==============================================================================

struct FakeResult <: Solutions.AbstractIntegrationResult end

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
                
                Test.@test_throws Exceptions.NotImplemented Solutions.final_state(result)
            end

            Test.@testset "times throws NotImplemented on abstract type" begin
                result = FakeResult()
                
                Test.@test_throws Exceptions.NotImplemented Solutions.times(result)
            end

            Test.@testset "evaluate_at throws NotImplemented on abstract type" begin
                result = FakeResult()
                
                Test.@test_throws Exceptions.NotImplemented Solutions.evaluate_at(result, 0.0)
            end
        end

        # ====================================================================
        # UNIT TESTS - Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "AbstractIntegrationResult is exported" begin
                Test.@test isdefined(Solutions, :AbstractIntegrationResult)
            end

            Test.@testset "final_state is exported" begin
                Test.@test isdefined(Solutions, :final_state)
            end

            Test.@testset "times is exported" begin
                Test.@test isdefined(Solutions, :times)
            end

            Test.@testset "evaluate_at is exported" begin
                Test.@test isdefined(Solutions, :evaluate_at)
            end
        end
    end
end

end # module

test_integration_result() = TestIntegrationResult.test_integration_result()