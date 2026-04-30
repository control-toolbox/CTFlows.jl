module TestConfigs

import Test
import CTBase.Exceptions
import CTFlows.Common

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for contract testing
# ==============================================================================

"""
Fake config type for testing the AbstractConfig contract.
Does not implement tspan to trigger NotImplemented error.
"""
struct FakeConfig <: Common.AbstractConfig end

"""
Fake config type that implements the tspan contract.
Used to test contract implementation without relying on concrete types.
"""
struct FakeConfigWithTspan <: Common.AbstractConfig
    t0::Float64
    tf::Float64
end

function Common.tspan(c::FakeConfigWithTspan)
    return (c.t0, c.tf)
end

# ==============================================================================
# Test function
# ==============================================================================

function test_configs()
    Test.@testset "Config Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

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
        # UNIT TESTS - tspan Contract
        # ====================================================================

        Test.@testset "tspan Contract" begin
            Test.@testset "AbstractConfig tspan throws NotImplemented" begin
                config = FakeConfig()
                Test.@test_throws Exceptions.NotImplemented Common.tspan(config)
            end

            Test.@testset "PointConfig tspan returns tuple" begin
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                ts = Common.tspan(config)
                Test.@test ts isa Tuple{Real, Real}
                Test.@test ts == (0.0, 1.0)
            end

            Test.@testset "TrajectoryConfig tspan returns tuple" begin
                config = Common.TrajectoryConfig((0.0, 1.0), [1.0, 0.0])
                ts = Common.tspan(config)
                Test.@test ts isa Tuple{Real, Real}
                Test.@test ts == (0.0, 1.0)
            end

            Test.@testset "Fake config with tspan contract" begin
                config = FakeConfigWithTspan(0.5, 2.5)
                ts = Common.tspan(config)
                Test.@test ts == (0.5, 2.5)
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

test_configs() = TestConfigs.test_configs()
