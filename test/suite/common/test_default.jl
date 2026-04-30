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
            Test.@testset "__autonomous returns true" begin
                Test.@test Common.__autonomous() === true
            end

            Test.@testset "__variable returns false" begin
                Test.@test Common.__variable() === false
            end
        end
    end
end

end # module

test_default() = TestDefault.test_default()
