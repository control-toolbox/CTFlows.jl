module TestShowConfigs

using Test: Test
import CTFlows.Configs

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_show_configs()
    Test.@testset "Show Configs Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Display Methods
        # ====================================================================

        Test.@testset "UNIT TESTS - Display Methods" begin
            Test.@testset "StateEndPointConfig show methods" begin
                config = Configs.StateEndPointConfig(0.0, [1.0, 0.0], 1.0)
                io = IOBuffer()
                show(io, config)
                output = String(take!(io))
                Test.@test occursin("StateEndPointConfig", output)
                Test.@test occursin("t0:", output)
                Test.@test occursin("x0:", output)
                Test.@test occursin("tf:", output)
            end

            Test.@testset "StateEndPointConfig text/plain show method" begin
                config = Configs.StateEndPointConfig(0.0, [1.0, 0.0], 1.0)
                io = IOBuffer()
                show(io, MIME("text/plain"), config)
                output = String(take!(io))
                Test.@test occursin("StateEndPointConfig", output)
                Test.@test occursin("t0:", output)
                Test.@test occursin("x0:", output)
                Test.@test occursin("tf:", output)
            end

            Test.@testset "StateTrajectoryConfig show methods" begin
                config = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0, 0.0])
                io = IOBuffer()
                show(io, config)
                output = String(take!(io))
                Test.@test occursin("StateTrajectoryConfig", output)
                Test.@test occursin("tspan:", output)
                Test.@test occursin("x0:", output)
            end

            Test.@testset "StateTrajectoryConfig text/plain show method" begin
                config = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0, 0.0])
                io = IOBuffer()
                show(io, MIME("text/plain"), config)
                output = String(take!(io))
                Test.@test occursin("StateTrajectoryConfig", output)
                Test.@test occursin("tspan:", output)
                Test.@test occursin("x0:", output)
            end

            Test.@testset "HamiltonianEndPointConfig show methods" begin
                config = Configs.HamiltonianEndPointConfig(0.0, [1.0], [0.5], 1.0)
                io = IOBuffer()
                show(io, config)
                output = String(take!(io))
                Test.@test occursin("HamiltonianEndPointConfig", output)
                Test.@test occursin("t0:", output)
                Test.@test occursin("x0:", output)
                Test.@test occursin("p0:", output)
                Test.@test occursin("tf:", output)
            end

            Test.@testset "HamiltonianEndPointConfig text/plain show method" begin
                config = Configs.HamiltonianEndPointConfig(0.0, [1.0], [0.5], 1.0)
                io = IOBuffer()
                show(io, MIME("text/plain"), config)
                output = String(take!(io))
                Test.@test occursin("HamiltonianEndPointConfig", output)
                Test.@test occursin("t0:", output)
                Test.@test occursin("x0:", output)
                Test.@test occursin("p0:", output)
                Test.@test occursin("tf:", output)
            end

            Test.@testset "HamiltonianTrajectoryConfig show methods" begin
                config = Configs.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0], [0.5])
                io = IOBuffer()
                show(io, config)
                output = String(take!(io))
                Test.@test occursin("HamiltonianTrajectoryConfig", output)
                Test.@test occursin("tspan:", output)
                Test.@test occursin("x0:", output)
                Test.@test occursin("p0:", output)
            end

            Test.@testset "HamiltonianTrajectoryConfig text/plain show method" begin
                config = Configs.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0], [0.5])
                io = IOBuffer()
                show(io, MIME("text/plain"), config)
                output = String(take!(io))
                Test.@test occursin("HamiltonianTrajectoryConfig", output)
                Test.@test occursin("tspan:", output)
                Test.@test occursin("x0:", output)
                Test.@test occursin("p0:", output)
            end

            Test.@testset "AugmentedHamiltonianEndPointConfig show methods" begin
                config = Configs.AugmentedHamiltonianEndPointConfig(
                    0.0, [1.0], [0.5], [0.0], 1.0
                )
                io = IOBuffer()
                show(io, config)
                output = String(take!(io))
                Test.@test occursin("AugmentedHamiltonianEndPointConfig", output)
                Test.@test occursin("t0:", output)
                Test.@test occursin("x0:", output)
                Test.@test occursin("p0:", output)
                Test.@test occursin("pv0:", output)
                Test.@test occursin("tf:", output)
            end

            Test.@testset "AugmentedHamiltonianEndPointConfig text/plain show method" begin
                config = Configs.AugmentedHamiltonianEndPointConfig(
                    0.0, [1.0], [0.5], [0.0], 1.0
                )
                io = IOBuffer()
                show(io, MIME("text/plain"), config)
                output = String(take!(io))
                Test.@test occursin("AugmentedHamiltonianEndPointConfig", output)
                Test.@test occursin("t0:", output)
                Test.@test occursin("x0:", output)
                Test.@test occursin("p0:", output)
                Test.@test occursin("pv0:", output)
                Test.@test occursin("tf:", output)
            end
        end
    end
end

end # module

test_show_configs() = TestShowConfigs.test_show_configs()
