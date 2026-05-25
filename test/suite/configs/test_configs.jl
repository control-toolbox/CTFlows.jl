module TestConfigs

import Test
import CTBase.Exceptions
import CTFlows.Configs
import CTFlows.Traits

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for contract testing
# ==============================================================================

"""
Fake config type for testing the AbstractConfig contract.
"""
struct FakeConfig{X0} <: Configs.AbstractConfigWithMaC{X0, Traits.PointTrait, Traits.StateTrait}
    x0::X0
end

"""
Fake config type that implements the tspan contract.
Used to test contract implementation without relying on concrete types.
"""
struct FakeConfigWithTspan{X0} <: Configs.AbstractConfigWithMaC{X0, Traits.PointTrait, Traits.StateTrait}
    t0::Float64
    tf::Float64
    x0::X0
end

"""
Fake bare config that intentionally does not implement any AbstractConfig stubs.
"""
struct FakeBareConfig <: Configs.AbstractConfig{Float64} end

function Configs.tspan(c::FakeConfigWithTspan)
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
            Test.@testset "Trait Aliases" begin
                # Mode aliases
                Test.@test Configs.StatePointConfig <: Configs.AbstractPointConfig
                Test.@test Configs.HamiltonianPointConfig <: Configs.AbstractPointConfig
                Test.@test Configs.StateTrajectoryConfig <: Configs.AbstractTrajectoryConfig
                Test.@test Configs.HamiltonianTrajectoryConfig <: Configs.AbstractTrajectoryConfig

                # Content aliases
                Test.@test Configs.StatePointConfig <: Configs.AbstractStateConfig
                Test.@test Configs.StateTrajectoryConfig <: Configs.AbstractStateConfig
                Test.@test Configs.HamiltonianPointConfig <: Configs.AbstractHamiltonianConfig
                Test.@test Configs.HamiltonianTrajectoryConfig <: Configs.AbstractHamiltonianConfig

                # Negative checks
                Test.@test !(Configs.StatePointConfig <: Configs.AbstractHamiltonianConfig)
                Test.@test !(Configs.HamiltonianPointConfig <: Configs.AbstractStateConfig)
                Test.@test !(Configs.StatePointConfig <: Configs.AbstractTrajectoryConfig)
            end

            Test.@testset "initial_condition is exported" begin
                Test.@test isdefined(Configs, :initial_condition)
            end

            Test.@testset "initial_condition handles scalar" begin
                config = Configs.StatePointConfig(0.0, 1.0, 1.0)
                ic = Configs.initial_condition(config)
                Test.@test ic isa AbstractVector
                Test.@test ic == [1.0]
                Test.@test typeof(config) == Configs.StatePointConfig{Float64, Float64, Float64}  # X0 <: Number
            end

            Test.@testset "initial_condition handles vector" begin
                config = Configs.StatePointConfig(0.0, [1.0, 0.0], 1.0)
                ic = Configs.initial_condition(config)
                Test.@test ic isa AbstractVector
                Test.@test ic == [1.0, 0.0]
                Test.@test typeof(config) <: Configs.StatePointConfig{Float64, <:AbstractVector, Float64}  # X0 is vector
            end

            Test.@testset "initial_state is exported" begin
                Test.@test isdefined(Configs, :initial_state)
            end

            Test.@testset "initial_costate is exported" begin
                Test.@test isdefined(Configs, :initial_costate)
            end

            Test.@testset "AbstractConfig stub methods throw NotImplemented" begin
                config = FakeBareConfig()
                Test.@test_throws Exceptions.NotImplemented Configs.tspan(config)
                Test.@test_throws Exceptions.NotImplemented Configs.initial_condition(config)
                Test.@test_throws Exceptions.NotImplemented Configs.initial_state(config)
                Test.@test_throws Exceptions.NotImplemented Configs.initial_costate(config)
            end

            Test.@testset "initial_state for StatePointConfig" begin
                config = Configs.StatePointConfig(0.0, [1.0, 0.0], 1.0)
                Test.@test Configs.initial_state(config) == [1.0, 0.0]
            end

            Test.@testset "initial_state for StateTrajectoryConfig" begin
                config = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0, 0.0])
                Test.@test Configs.initial_state(config) == [1.0, 0.0]
            end

            Test.@testset "initial_state for HamiltonianPointConfig" begin
                config = Configs.HamiltonianPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], 1.0)
                Test.@test Configs.initial_state(config) == [1.0, 0.0]
            end

            Test.@testset "initial_state for HamiltonianTrajectoryConfig" begin
                config = Configs.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0, 0.0], [0.5, 0.3])
                Test.@test Configs.initial_state(config) == [1.0, 0.0]
            end

            Test.@testset "initial_costate for HamiltonianPointConfig" begin
                config = Configs.HamiltonianPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], 1.0)
                Test.@test Configs.initial_costate(config) == [0.5, 0.3]
            end

            Test.@testset "initial_costate for HamiltonianTrajectoryConfig" begin
                config = Configs.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0, 0.0], [0.5, 0.3])
                Test.@test Configs.initial_costate(config) == [0.5, 0.3]
            end

            Test.@testset "initial_variable_costate is exported" begin
                Test.@test isdefined(Configs, :initial_variable_costate)
            end

            Test.@testset "initial_variable_costate stub throws NotImplemented on bare config" begin
                config = FakeBareConfig()
                Test.@test_throws Exceptions.NotImplemented Configs.initial_variable_costate(config)
            end

            Test.@testset "initial_variable_costate throws NotImplemented on HamiltonianPointConfig" begin
                config = Configs.HamiltonianPointConfig(0.0, [1.0], [0.5], 1.0)
                Test.@test_throws Exceptions.NotImplemented Configs.initial_variable_costate(config)
            end

            Test.@testset "tspan unified dispatch" begin
                sp = Configs.StatePointConfig(0.0, [1.0], 1.0)
                st = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0])
                hp = Configs.HamiltonianPointConfig(0.0, [1.0], [0.5], 1.0)
                ht = Configs.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0], [0.5])

                Test.@test Configs.tspan(sp) == (0.0, 1.0)
                Test.@test Configs.tspan(st) == (0.0, 1.0)
                Test.@test Configs.tspan(hp) == (0.0, 1.0)
                Test.@test Configs.tspan(ht) == (0.0, 1.0)
            end

            Test.@testset "initial_costate throws PreconditionError for non-Hamiltonian configs" begin
                config = Configs.StatePointConfig(0.0, [1.0], 1.0)
                Test.@test_throws Exceptions.PreconditionError Configs.initial_costate(config)

                Test.@testset "PreconditionError message quality" begin
                    config = Configs.StatePointConfig(0.0, [1.0], 1.0)
                    e = try
                        Configs.initial_costate(config)
                    catch err
                        err
                    end
                    Test.@test e isa Exceptions.PreconditionError
                    Test.@test occursin("Hamiltonian", string(e))
                    Test.@test occursin("costate", string(e))
                end
            end

            Test.@testset "initial_condition with StateTrajectoryConfig scalar" begin
                config = Configs.StateTrajectoryConfig((0.0, 1.0), 1.0)
                ic = Configs.initial_condition(config)
                Test.@test ic isa AbstractVector
                Test.@test ic == [1.0]
            end

            Test.@testset "initial_condition with StateTrajectoryConfig vector" begin
                config = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0, 0.0])
                ic = Configs.initial_condition(config)
                Test.@test ic isa AbstractVector
                Test.@test ic == [1.0, 0.0]
            end

            Test.@testset "AbstractConfig is exported" begin
                Test.@test isdefined(Configs, :AbstractConfig)
            end

            Test.@testset "AbstractPointConfig is exported" begin
                Test.@test isdefined(Configs, :AbstractPointConfig)
            end

            Test.@testset "AbstractTrajectoryConfig is exported" begin
                Test.@test isdefined(Configs, :AbstractTrajectoryConfig)
            end

            Test.@testset "StatePointConfig subtypes AbstractConfig" begin
                config = Configs.StatePointConfig(0.0, [1.0], 1.0)
                Test.@test config isa Configs.AbstractConfig
                Test.@test Configs.StatePointConfig <: Configs.AbstractConfig
            end

            Test.@testset "StatePointConfig subtypes AbstractPointConfig" begin
                config = Configs.StatePointConfig(0.0, [1.0], 1.0)
                Test.@test config isa Configs.AbstractPointConfig
                Test.@test Configs.StatePointConfig <: Configs.AbstractPointConfig
            end

            Test.@testset "StateTrajectoryConfig subtypes AbstractConfig" begin
                config = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0])
                Test.@test config isa Configs.AbstractConfig
                Test.@test Configs.StateTrajectoryConfig <: Configs.AbstractConfig
            end

            Test.@testset "StateTrajectoryConfig subtypes AbstractTrajectoryConfig" begin
                config = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0])
                Test.@test config isa Configs.AbstractTrajectoryConfig
                Test.@test Configs.StateTrajectoryConfig <: Configs.AbstractTrajectoryConfig
            end

            Test.@testset "HamiltonianPointConfig subtypes AbstractPointConfig" begin
                config = Configs.HamiltonianPointConfig(0.0, [1.0], [0.5], 1.0)
                Test.@test config isa Configs.AbstractPointConfig
                Test.@test Configs.HamiltonianPointConfig <: Configs.AbstractPointConfig
            end

            Test.@testset "HamiltonianTrajectoryConfig subtypes AbstractTrajectoryConfig" begin
                config = Configs.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0], [0.5])
                Test.@test config isa Configs.AbstractTrajectoryConfig
                Test.@test Configs.HamiltonianTrajectoryConfig <: Configs.AbstractTrajectoryConfig
            end
        end

        # ====================================================================
        # UNIT TESTS - Config Structures
        # ====================================================================

        Test.@testset "Config Structures" begin
            Test.@testset "StatePointConfig construction" begin
                config = Configs.StatePointConfig(0.0, [1.0, 0.0], 1.0)
                Test.@test config isa Configs.StatePointConfig
                Test.@test config.t0 === 0.0
                Test.@test config.x0 == [1.0, 0.0]
                Test.@test config.tf === 1.0
            end

            Test.@testset "StateTrajectoryConfig construction" begin
                config = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0, 0.0])
                Test.@test config isa Configs.StateTrajectoryConfig
                Test.@test config.tspan == (0.0, 1.0)
                Test.@test config.x0 == [1.0, 0.0]
            end

            Test.@testset "HamiltonianPointConfig construction" begin
                config = Configs.HamiltonianPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], 1.0)
                Test.@test config isa Configs.HamiltonianPointConfig
                Test.@test config.t0 === 0.0
                Test.@test config.x0 == [1.0, 0.0]
                Test.@test config.p0 == [0.5, 0.3]
                Test.@test config.tf === 1.0
            end

            Test.@testset "HamiltonianTrajectoryConfig construction" begin
                config = Configs.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0, 0.0], [0.5, 0.3])
                Test.@test config isa Configs.HamiltonianTrajectoryConfig
                Test.@test config.tspan == (0.0, 1.0)
                Test.@test config.x0 == [1.0, 0.0]
                Test.@test config.p0 == [0.5, 0.3]
            end

            Test.@testset "AugmentedHamiltonianPointConfig construction" begin
                config = Configs.AugmentedHamiltonianPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], [0.0, 0.0], 1.0)
                Test.@test config isa Configs.AugmentedHamiltonianPointConfig
                Test.@test config.t0 === 0.0
                Test.@test config.x0 == [1.0, 0.0]
                Test.@test config.p0 == [0.5, 0.3]
                Test.@test config.pv0 == [0.0, 0.0]
                Test.@test config.tf === 1.0
            end

            Test.@testset "AugmentedHamiltonianPointConfig initial_condition" begin
                config = Configs.AugmentedHamiltonianPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], [0.0, 0.0], 1.0)
                ic = Configs.initial_condition(config)
                Test.@test ic == [1.0, 0.0, 0.5, 0.3, 0.0, 0.0]
            end

            Test.@testset "AugmentedHamiltonianPointConfig initial_state" begin
                config = Configs.AugmentedHamiltonianPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], [0.0, 0.0], 1.0)
                Test.@test Configs.initial_state(config) == [1.0, 0.0]
            end

            Test.@testset "AugmentedHamiltonianPointConfig initial_costate" begin
                config = Configs.AugmentedHamiltonianPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], [0.0, 0.0], 1.0)
                Test.@test Configs.initial_costate(config) == [0.5, 0.3]
            end

            Test.@testset "AugmentedHamiltonianPointConfig initial_variable_costate" begin
                config = Configs.AugmentedHamiltonianPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], [0.0, 0.0], 1.0)
                Test.@test Configs.initial_variable_costate(config) == [0.0, 0.0]
            end

            Test.@testset "AugmentedHamiltonianPointConfig tspan" begin
                config = Configs.AugmentedHamiltonianPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], [0.0, 0.0], 1.0)
                Test.@test Configs.tspan(config) == (0.0, 1.0)
            end

            Test.@testset "AugmentedHamiltonianPointConfig subtypes AbstractAugmentedHamiltonianConfig" begin
                config = Configs.AugmentedHamiltonianPointConfig(0.0, [1.0], [0.5], [0.0], 1.0)
                Test.@test config isa Configs.AbstractAugmentedHamiltonianConfig
                Test.@test Configs.AugmentedHamiltonianPointConfig <: Configs.AbstractAugmentedHamiltonianConfig
            end

            Test.@testset "AugmentedHamiltonianPointConfig subtypes AbstractPointConfig" begin
                config = Configs.AugmentedHamiltonianPointConfig(0.0, [1.0], [0.5], [0.0], 1.0)
                Test.@test config isa Configs.AbstractPointConfig
                Test.@test Configs.AugmentedHamiltonianPointConfig <: Configs.AbstractPointConfig
            end

            Test.@testset "Type Stability: AugmentedHamiltonianPointConfig getters" begin
                config = Configs.AugmentedHamiltonianPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], [0.0, 0.0], 1.0)
                Test.@test Test.@inferred(Configs.initial_condition(config)) == [1.0, 0.0, 0.5, 0.3, 0.0, 0.0]
                Test.@test Test.@inferred(Configs.initial_state(config)) == [1.0, 0.0]
                Test.@test Test.@inferred(Configs.initial_costate(config)) == [0.5, 0.3]
                Test.@test Test.@inferred(Configs.initial_variable_costate(config)) == [0.0, 0.0]
                Test.@test Test.@inferred(Configs.tspan(config)) == (0.0, 1.0)
            end
        end

        # ====================================================================
        # UNIT TESTS - tspan Contract
        # ====================================================================

        Test.@testset "tspan Contract" begin
            Test.@testset "StatePointConfig tspan returns tuple" begin
                config = Configs.StatePointConfig(0.0, [1.0, 0.0], 1.0)
                ts = Configs.tspan(config)
                Test.@test ts isa Tuple{Real, Real}
                Test.@test ts == (0.0, 1.0)
            end

            Test.@testset "StateTrajectoryConfig tspan returns tuple" begin
                config = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0, 0.0])
                ts = Configs.tspan(config)
                Test.@test ts isa Tuple{Real, Real}
                Test.@test ts == (0.0, 1.0)
            end

            Test.@testset "HamiltonianPointConfig tspan returns tuple" begin
                config = Configs.HamiltonianPointConfig(0.0, [1.0], [0.5], 1.0)
                ts = Configs.tspan(config)
                Test.@test ts isa Tuple{Real, Real}
                Test.@test ts == (0.0, 1.0)
            end

            Test.@testset "HamiltonianTrajectoryConfig tspan returns tuple" begin
                config = Configs.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0], [0.5])
                ts = Configs.tspan(config)
                Test.@test ts isa Tuple{Real, Real}
                Test.@test ts == (0.0, 1.0)
            end

            Test.@testset "Fake config with tspan contract" begin
                config = FakeConfigWithTspan(0.5, 2.5, 1.0)
                ts = Configs.tspan(config)
                Test.@test ts == (0.5, 2.5)
            end
        end

        # ====================================================================
        # UNIT TESTS - Display Methods
        # ====================================================================

        Test.@testset "Display Methods" begin
            Test.@testset "StatePointConfig show methods" begin
                config = Configs.StatePointConfig(0.0, [1.0, 0.0], 1.0)
                io = IOBuffer()
                show(io, config)
                output = String(take!(io))
                Test.@test occursin("StatePointConfig", output)
                Test.@test occursin("t0:", output)
                Test.@test occursin("x0:", output)
                Test.@test occursin("tf:", output)
            end

            Test.@testset "StatePointConfig text/plain show method" begin
                config = Configs.StatePointConfig(0.0, [1.0, 0.0], 1.0)
                io = IOBuffer()
                show(io, MIME("text/plain"), config)
                output = String(take!(io))
                Test.@test occursin("StatePointConfig", output)
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

            Test.@testset "HamiltonianPointConfig show methods" begin
                config = Configs.HamiltonianPointConfig(0.0, [1.0], [0.5], 1.0)
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
                config = Configs.HamiltonianPointConfig(0.0, [1.0], [0.5], 1.0)
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

            Test.@testset "AugmentedHamiltonianPointConfig show methods" begin
                config = Configs.AugmentedHamiltonianPointConfig(0.0, [1.0], [0.5], [0.0], 1.0)
                io = IOBuffer()
                show(io, config)
                output = String(take!(io))
                Test.@test occursin("AugmentedHamiltonianPointConfig", output)
                Test.@test occursin("t0:", output)
                Test.@test occursin("x0:", output)
                Test.@test occursin("p0:", output)
                Test.@test occursin("pv0:", output)
                Test.@test occursin("tf:", output)
            end

            Test.@testset "AugmentedHamiltonianPointConfig text/plain show method" begin
                config = Configs.AugmentedHamiltonianPointConfig(0.0, [1.0], [0.5], [0.0], 1.0)
                io = IOBuffer()
                show(io, MIME("text/plain"), config)
                output = String(take!(io))
                Test.@test occursin("AugmentedHamiltonianPointConfig", output)
                Test.@test occursin("t0:", output)
                Test.@test occursin("x0:", output)
                Test.@test occursin("p0:", output)
                Test.@test occursin("pv0:", output)
                Test.@test occursin("tf:", output)
            end
        end

        # ====================================================================
        # UNIT TESTS - Exports
        # ====================================================================

        Test.@testset "Exports" begin
            Test.@testset "AugmentedHamiltonianPointConfig is exported" begin
                Test.@test isdefined(Configs, :AugmentedHamiltonianPointConfig)
            end

            Test.@testset "initial_variable_costate is exported" begin
                Test.@test isdefined(Configs, :initial_variable_costate)
            end
        end
    end
end

end # module

test_configs() = TestConfigs.test_configs()
