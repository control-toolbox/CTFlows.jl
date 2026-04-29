module TestCommon

import Test
import CTFlows.Common

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Test function
# ==============================================================================

function test_common()
    Test.@testset "Common Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

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

        # ====================================================================
        # UNIT TESTS - Config Structures
        # ====================================================================

        Test.@testset "Config Structures" begin
            Test.@testset "PointConfig construction" begin
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                Test.@test config isa Common.PointConfig
                Test.@test config.t0 === 0.0
                Test.@test config.x0 == [1.0, 0.0]
                Test.@test config.tf === 1.0
            end

            Test.@testset "TrajectoryConfig construction" begin
                config = Common.TrajectoryConfig((0.0, 1.0), [1.0, 0.0])
                Test.@test config isa Common.TrajectoryConfig
                Test.@test config.tspan == (0.0, 1.0)
                Test.@test config.x0 == [1.0, 0.0]
            end
        end
    end
end

end # module

test_common() = TestCommon.test_common()
