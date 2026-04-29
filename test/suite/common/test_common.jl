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
        # UNIT TESTS - Abstract Type
        # ====================================================================

        Test.@testset "Abstract Type" begin
            Test.@testset "AbstractConfig is exported" begin
                Test.@test isdefined(Common, :AbstractConfig)
            end

            Test.@testset "PointConfig subtypes AbstractConfig" begin
                config = Common.PointConfig(0.0, [1.0], 1.0)
                Test.@test config isa Common.AbstractConfig
                Test.@test Common.PointConfig <: Common.AbstractConfig
            end

            Test.@testset "TrajectoryConfig subtypes AbstractConfig" begin
                config = Common.TrajectoryConfig((0.0, 1.0), [1.0])
                Test.@test config isa Common.AbstractConfig
                Test.@test Common.TrajectoryConfig <: Common.AbstractConfig
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

        # ====================================================================
        # UNIT TESTS - Display Methods
        # ====================================================================

        Test.@testset "Display Methods" begin
            Test.@testset "PointConfig show methods" begin
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                io = IOBuffer()
                show(io, config)
                output = String(take!(io))
                Test.@test occursin("PointConfig", output)
                Test.@test occursin("t0:", output)
                Test.@test occursin("x0:", output)
                Test.@test occursin("tf:", output)
            end

            Test.@testset "TrajectoryConfig show methods" begin
                config = Common.TrajectoryConfig((0.0, 1.0), [1.0, 0.0])
                io = IOBuffer()
                show(io, config)
                output = String(take!(io))
                Test.@test occursin("TrajectoryConfig", output)
                Test.@test occursin("tspan:", output)
                Test.@test occursin("x0:", output)
            end
        end
    end
end

end # module

test_common() = TestCommon.test_common()
