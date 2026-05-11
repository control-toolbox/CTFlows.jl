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
struct FakeConfig{X0} <: Common.AbstractConfig{X0}
    x0::X0
end

"""
Fake config type that implements the tspan contract.
Used to test contract implementation without relying on concrete types.
"""
struct FakeConfigWithTspan{X0} <: Common.AbstractConfig{X0}
    t0::Float64
    tf::Float64
    x0::X0
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
            Test.@testset "initial_condition is exported" begin
                Test.@test isdefined(Common, :initial_condition)
            end

            Test.@testset "initial_condition handles scalar" begin
                config = Common.PointConfig(0.0, 1.0, 1.0)
                ic = Common.initial_condition(config)
                Test.@test ic isa AbstractVector
                Test.@test ic == [1.0]
                Test.@test typeof(config) == Common.PointConfig{Float64, Float64, Float64}  # X0 <: Number
            end

            Test.@testset "initial_condition handles vector" begin
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                ic = Common.initial_condition(config)
                Test.@test ic isa AbstractVector
                Test.@test ic == [1.0, 0.0]
                Test.@test typeof(config) <: Common.PointConfig{Float64, <:AbstractVector, Float64}  # X0 is vector
            end

            Test.@testset "initial_state is exported" begin
                Test.@test isdefined(Common, :initial_state)
            end

            Test.@testset "initial_costate is exported" begin
                Test.@test isdefined(Common, :initial_costate)
            end

            Test.@testset "initial_state for PointConfig" begin
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                Test.@test Common.initial_state(config) == [1.0, 0.0]
            end

            Test.@testset "initial_state for TrajectoryConfig" begin
                config = Common.TrajectoryConfig((0.0, 1.0), [1.0, 0.0])
                Test.@test Common.initial_state(config) == [1.0, 0.0]
            end

            Test.@testset "initial_state for HamiltonianPointConfig" begin
                config = Common.HamiltonianPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], 1.0)
                Test.@test Common.initial_state(config) == [1.0, 0.0]
            end

            Test.@testset "initial_state for HamiltonianTrajectoryConfig" begin
                config = Common.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0, 0.0], [0.5, 0.3])
                Test.@test Common.initial_state(config) == [1.0, 0.0]
            end

            Test.@testset "initial_costate for HamiltonianPointConfig" begin
                config = Common.HamiltonianPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], 1.0)
                Test.@test Common.initial_costate(config) == [0.5, 0.3]
            end

            Test.@testset "initial_costate for HamiltonianTrajectoryConfig" begin
                config = Common.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0, 0.0], [0.5, 0.3])
                Test.@test Common.initial_costate(config) == [0.5, 0.3]
            end

            Test.@testset "initial_costate throws PreconditionError for non-Hamiltonian configs" begin
                config = Common.PointConfig(0.0, [1.0], 1.0)
                Test.@test_throws Exceptions.PreconditionError Common.initial_costate(config)

                Test.@testset "PreconditionError message quality" begin
                    config = Common.PointConfig(0.0, [1.0], 1.0)
                    e = try
                        Common.initial_costate(config)
                    catch err
                        err
                    end
                    Test.@test e isa Exceptions.PreconditionError
                    Test.@test occursin("Hamiltonian", string(e))
                    Test.@test occursin("costate", string(e))
                end
            end

            Test.@testset "initial_condition with TrajectoryConfig scalar" begin
                config = Common.TrajectoryConfig((0.0, 1.0), 1.0)
                ic = Common.initial_condition(config)
                Test.@test ic isa AbstractVector
                Test.@test ic == [1.0]
            end

            Test.@testset "initial_condition with TrajectoryConfig vector" begin
                config = Common.TrajectoryConfig((0.0, 1.0), [1.0, 0.0])
                ic = Common.initial_condition(config)
                Test.@test ic isa AbstractVector
                Test.@test ic == [1.0, 0.0]
            end

            Test.@testset "AbstractConfig is exported" begin
                Test.@test isdefined(Common, :AbstractConfig)
            end

            Test.@testset "AbstractPointConfig is exported" begin
                Test.@test isdefined(Common, :AbstractPointConfig)
            end

            Test.@testset "AbstractTrajectoryConfig is exported" begin
                Test.@test isdefined(Common, :AbstractTrajectoryConfig)
            end

            Test.@testset "PointConfig subtypes AbstractConfig" begin
                config = Common.PointConfig(0.0, [1.0], 1.0)
                Test.@test config isa Common.AbstractConfig
                Test.@test Common.PointConfig <: Common.AbstractConfig
            end

            Test.@testset "PointConfig subtypes AbstractPointConfig" begin
                config = Common.PointConfig(0.0, [1.0], 1.0)
                Test.@test config isa Common.AbstractPointConfig
                Test.@test Common.PointConfig <: Common.AbstractPointConfig
            end

            Test.@testset "TrajectoryConfig subtypes AbstractConfig" begin
                config = Common.TrajectoryConfig((0.0, 1.0), [1.0])
                Test.@test config isa Common.AbstractConfig
                Test.@test Common.TrajectoryConfig <: Common.AbstractConfig
            end

            Test.@testset "TrajectoryConfig subtypes AbstractTrajectoryConfig" begin
                config = Common.TrajectoryConfig((0.0, 1.0), [1.0])
                Test.@test config isa Common.AbstractTrajectoryConfig
                Test.@test Common.TrajectoryConfig <: Common.AbstractTrajectoryConfig
            end

            Test.@testset "HamiltonianPointConfig subtypes AbstractPointConfig" begin
                config = Common.HamiltonianPointConfig(0.0, [1.0], [0.5], 1.0)
                Test.@test config isa Common.AbstractPointConfig
                Test.@test Common.HamiltonianPointConfig <: Common.AbstractPointConfig
            end

            Test.@testset "HamiltonianTrajectoryConfig subtypes AbstractTrajectoryConfig" begin
                config = Common.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0], [0.5])
                Test.@test config isa Common.AbstractTrajectoryConfig
                Test.@test Common.HamiltonianTrajectoryConfig <: Common.AbstractTrajectoryConfig
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

            Test.@testset "HamiltonianPointConfig construction" begin
                config = Common.HamiltonianPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], 1.0)
                Test.@test config isa Common.HamiltonianPointConfig
                Test.@test config.t0 === 0.0
                Test.@test config.x0 == [1.0, 0.0]
                Test.@test config.p0 == [0.5, 0.3]
                Test.@test config.tf === 1.0
            end

            Test.@testset "HamiltonianTrajectoryConfig construction" begin
                config = Common.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0, 0.0], [0.5, 0.3])
                Test.@test config isa Common.HamiltonianTrajectoryConfig
                Test.@test config.tspan == (0.0, 1.0)
                Test.@test config.x0 == [1.0, 0.0]
                Test.@test config.p0 == [0.5, 0.3]
            end
        end

        # ====================================================================
        # UNIT TESTS - tspan Contract
        # ====================================================================

        Test.@testset "tspan Contract" begin
            Test.@testset "AbstractConfig tspan throws NotImplemented" begin
                config = FakeConfig(1.0)
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

            Test.@testset "HamiltonianPointConfig tspan returns tuple" begin
                config = Common.HamiltonianPointConfig(0.0, [1.0], [0.5], 1.0)
                ts = Common.tspan(config)
                Test.@test ts isa Tuple{Real, Real}
                Test.@test ts == (0.0, 1.0)
            end

            Test.@testset "HamiltonianTrajectoryConfig tspan returns tuple" begin
                config = Common.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0], [0.5])
                ts = Common.tspan(config)
                Test.@test ts isa Tuple{Real, Real}
                Test.@test ts == (0.0, 1.0)
            end

            Test.@testset "Fake config with tspan contract" begin
                config = FakeConfigWithTspan(0.5, 2.5, 1.0)
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

            Test.@testset "PointConfig text/plain show method" begin
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                io = IOBuffer()
                show(io, MIME("text/plain"), config)
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

            Test.@testset "TrajectoryConfig text/plain show method" begin
                config = Common.TrajectoryConfig((0.0, 1.0), [1.0, 0.0])
                io = IOBuffer()
                show(io, MIME("text/plain"), config)
                output = String(take!(io))
                Test.@test occursin("TrajectoryConfig", output)
                Test.@test occursin("tspan:", output)
                Test.@test occursin("x0:", output)
            end

            Test.@testset "HamiltonianPointConfig show methods" begin
                config = Common.HamiltonianPointConfig(0.0, [1.0], [0.5], 1.0)
                io = IOBuffer()
                show(io, config)
                output = String(take!(io))
                Test.@test occursin("HamiltonianPointConfig", output)
                Test.@test occursin("t0:", output)
                Test.@test occursin("x0:", output)
                Test.@test occursin("p0:", output)
                Test.@test occursin("tf:", output)
            end

            Test.@testset "HamiltonianPointConfig text/plain show method" begin
                config = Common.HamiltonianPointConfig(0.0, [1.0], [0.5], 1.0)
                io = IOBuffer()
                show(io, MIME("text/plain"), config)
                output = String(take!(io))
                Test.@test occursin("HamiltonianPointConfig", output)
                Test.@test occursin("t0:", output)
                Test.@test occursin("x0:", output)
                Test.@test occursin("p0:", output)
                Test.@test occursin("tf:", output)
            end

            Test.@testset "HamiltonianTrajectoryConfig show methods" begin
                config = Common.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0], [0.5])
                io = IOBuffer()
                show(io, config)
                output = String(take!(io))
                Test.@test occursin("HamiltonianTrajectoryConfig", output)
                Test.@test occursin("tspan:", output)
                Test.@test occursin("x0:", output)
                Test.@test occursin("p0:", output)
            end

            Test.@testset "HamiltonianTrajectoryConfig text/plain show method" begin
                config = Common.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0], [0.5])
                io = IOBuffer()
                show(io, MIME("text/plain"), config)
                output = String(take!(io))
                Test.@test occursin("HamiltonianTrajectoryConfig", output)
                Test.@test occursin("tspan:", output)
                Test.@test occursin("x0:", output)
                Test.@test occursin("p0:", output)
            end
        end
    end
end

end # module

test_configs() = TestConfigs.test_configs()
