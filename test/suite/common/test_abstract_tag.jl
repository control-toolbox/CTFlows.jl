module TestAbstractTag

import Test
import CTFlows.Common

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Test function
# ==============================================================================

function test_abstract_tag()
    Test.@testset "Abstract Tag Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Type
        # ====================================================================

        Test.@testset "Abstract Type" begin
            Test.@testset "AbstractTag is exported" begin
                Test.@test isdefined(Common, :AbstractTag)
            end

            Test.@testset "AbstractTag is abstract" begin
                Test.@test isabstracttype(Common.AbstractTag)
            end
        end
    end
end

end # module

test_abstract_tag() = TestAbstractTag.test_abstract_tag()
