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

            Test.@testset "__variable returns nothing" begin
                Test.@test Common.__variable() === nothing
            end

            Test.@testset "__unsafe returns false" begin
                Test.@test Common.__unsafe() === false
            end
        end
    end
end

end # module

test_default() = TestDefault.test_default()
