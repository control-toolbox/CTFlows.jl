module TestDefault

using Test: Test
import CTBase.Data
import CTFlows.Flows
import CTFlows.Systems
import CTBase.Core

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Test function
# ==============================================================================

function test_default()
    Test.@testset "Default Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Default Value Functions
        # ====================================================================

        Test.@testset "Default Value Functions" begin
            Test.@testset "__is_autonomous returns true" begin
                Test.@test Data.__is_autonomous() === true
            end

            Test.@testset "__is_variable returns false" begin
                Test.@test Data.__is_variable() === false
            end

            Test.@testset "__variable returns NotProvided" begin
                Test.@test Flows.__variable() isa Core.NotProvidedType
            end

            Test.@testset "__unsafe returns false" begin
                Test.@test Flows.__unsafe() === false
            end

            Test.@testset "__hvf_inplace returns false" begin
                Test.@test Systems.__hvf_inplace() === false
            end

            Test.@testset "_variable_costate returns false" begin
                Test.@test Flows.__variable_costate() === false
            end
        end

        Test.@testset "NotProvided sentinel (lives in CTBase.Core)" begin
            Test.@test Core.NotProvidedType <: Any
            Test.@test isdefined(Core, :NotProvided)
            Test.@test !isdefined(Flows, :NotProvided)
        end

        Test.@testset "__variable_costate export" begin
            Test.@testset "__variable_costate is exported" begin
                Test.@test isdefined(Flows, :__variable_costate)
            end
        end
    end
end

end # module

test_default() = TestDefault.test_default()
