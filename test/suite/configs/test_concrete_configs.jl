module TestConcreteConfigs

import Test
import CTFlows.Configs
import CTFlows.Traits

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_concrete_configs()
    Test.@testset "Concrete Configs Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Concrete Type Construction
        # ====================================================================

        Test.@testset "UNIT TESTS - Concrete Type Construction" begin
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
        end

        # ====================================================================
        # UNIT TESTS - Concrete Type Subtype Relationships
        # ====================================================================

        Test.@testset "UNIT TESTS - Concrete Type Subtype Relationships" begin
            Test.@testset "StatePointConfig subtypes" begin
                config = Configs.StatePointConfig(0.0, [1.0], 1.0)
                Test.@test config isa Configs.AbstractConfig
                Test.@test config isa Configs.AbstractPointConfig
                Test.@test config isa Configs.AbstractStateConfig
                Test.@test Configs.StatePointConfig <: Configs.AbstractConfig
                Test.@test Configs.StatePointConfig <: Configs.AbstractPointConfig
                Test.@test Configs.StatePointConfig <: Configs.AbstractStateConfig
            end

            Test.@testset "StateTrajectoryConfig subtypes" begin
                config = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0])
                Test.@test config isa Configs.AbstractConfig
                Test.@test config isa Configs.AbstractTrajectoryConfig
                Test.@test config isa Configs.AbstractStateConfig
                Test.@test Configs.StateTrajectoryConfig <: Configs.AbstractConfig
                Test.@test Configs.StateTrajectoryConfig <: Configs.AbstractTrajectoryConfig
                Test.@test Configs.StateTrajectoryConfig <: Configs.AbstractStateConfig
            end

            Test.@testset "HamiltonianPointConfig subtypes" begin
                config = Configs.HamiltonianPointConfig(0.0, [1.0], [0.5], 1.0)
                Test.@test config isa Configs.AbstractConfig
                Test.@test config isa Configs.AbstractPointConfig
                Test.@test config isa Configs.AbstractHamiltonianConfig
                Test.@test Configs.HamiltonianPointConfig <: Configs.AbstractConfig
                Test.@test Configs.HamiltonianPointConfig <: Configs.AbstractPointConfig
                Test.@test Configs.HamiltonianPointConfig <: Configs.AbstractHamiltonianConfig
            end

            Test.@testset "HamiltonianTrajectoryConfig subtypes" begin
                config = Configs.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0], [0.5])
                Test.@test config isa Configs.AbstractConfig
                Test.@test config isa Configs.AbstractTrajectoryConfig
                Test.@test config isa Configs.AbstractHamiltonianConfig
                Test.@test Configs.HamiltonianTrajectoryConfig <: Configs.AbstractConfig
                Test.@test Configs.HamiltonianTrajectoryConfig <: Configs.AbstractTrajectoryConfig
                Test.@test Configs.HamiltonianTrajectoryConfig <: Configs.AbstractHamiltonianConfig
            end

            Test.@testset "AugmentedHamiltonianPointConfig subtypes" begin
                config = Configs.AugmentedHamiltonianPointConfig(0.0, [1.0], [0.5], [0.0], 1.0)
                Test.@test config isa Configs.AbstractAugmentedHamiltonianConfig
                Test.@test config isa Configs.AbstractPointConfig
                Test.@test Configs.AugmentedHamiltonianPointConfig <: Configs.AbstractAugmentedHamiltonianConfig
                Test.@test Configs.AugmentedHamiltonianPointConfig <: Configs.AbstractPointConfig
            end
        end

        # ====================================================================
        # UNIT TESTS - AugmentedHamiltonianPointConfig Specific Methods
        # ====================================================================

        Test.@testset "UNIT TESTS - AugmentedHamiltonianPointConfig Specific Methods" begin
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
        end

        # ====================================================================
        # TYPE STABILITY TESTS
        # ====================================================================

        Test.@testset "TYPE STABILITY TESTS" begin
            Test.@testset "Type Stability: AugmentedHamiltonianPointConfig getters" begin
                config = Configs.AugmentedHamiltonianPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], [0.0, 0.0], 1.0)
                Test.@test_nowarn Test.@inferred(Configs.initial_condition(config)) == [1.0, 0.0, 0.5, 0.3, 0.0, 0.0]
                Test.@test_nowarn Test.@inferred(Configs.initial_state(config)) == [1.0, 0.0]
                Test.@test_nowarn Test.@inferred(Configs.initial_costate(config)) == [0.5, 0.3]
                Test.@test_nowarn Test.@inferred(Configs.initial_variable_costate(config)) == [0.0, 0.0]
                Test.@test_nowarn Test.@inferred(Configs.tspan(config)) == (0.0, 1.0)
            end
        end
    end
end

end # module

test_concrete_configs() = TestConcreteConfigs.test_concrete_configs()
