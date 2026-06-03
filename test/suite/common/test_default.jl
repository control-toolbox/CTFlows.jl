module TestDefault

import Test
import CTFlows.Common

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

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
                Test.@test Common.__is_autonomous() === true
            end

            Test.@testset "__is_variable returns false" begin
                Test.@test Common.__is_variable() === false
            end

            Test.@testset "__variable returns NotProvided" begin
                Test.@test Common.__variable() isa Common.NotProvided
            end

            Test.@testset "__unsafe returns false" begin
                Test.@test Common.__unsafe() === false
            end

            Test.@testset "__is_inplace returns nothing" begin
                Test.@test Common.__is_inplace() === nothing
            end

            Test.@testset "__hvf_inplace returns false" begin
                Test.@test Common.__hvf_inplace() === false
            end

            Test.@testset "_variable_costate returns false" begin
                Test.@test Common.__variable_costate() === false
            end
        end

        Test.@testset "NotProvided type" begin
            Test.@testset "NotProvided is a concrete type" begin
                Test.@test Common.NotProvided <: Any
            end

            Test.@testset "NotProvided is exported" begin
                Test.@test isdefined(Common, :NotProvided)
            end
        end

        Test.@testset "_variable_costate export" begin
            Test.@testset "_variable_costate is exported" begin
                Test.@test isdefined(Common, :_variable_costate)
            end
        end
    end
end

end # module

test_default() = TestDefault.test_default()
