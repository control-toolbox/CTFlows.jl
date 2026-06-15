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
            Test.@testset "StateEndPointConfig construction" begin
                config = Configs.StateEndPointConfig(0.0, [1.0, 0.0], 1.0)
                Test.@test config isa Configs.StateEndPointConfig
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

            Test.@testset "HamiltonianEndPointConfig construction" begin
                config = Configs.HamiltonianEndPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], 1.0)
                Test.@test config isa Configs.HamiltonianEndPointConfig
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

            Test.@testset "AugmentedHamiltonianEndPointConfig construction" begin
                config = Configs.AugmentedHamiltonianEndPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], [0.0, 0.0], 1.0)
                Test.@test config isa Configs.AugmentedHamiltonianEndPointConfig
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
            Test.@testset "StateEndPointConfig subtypes" begin
                config = Configs.StateEndPointConfig(0.0, [1.0], 1.0)
                Test.@test config isa Configs.AbstractConfig
                Test.@test config isa Configs.AbstractEndPointConfig
                Test.@test config isa Configs.AbstractStateConfig
                Test.@test Configs.StateEndPointConfig <: Configs.AbstractConfig
                Test.@test Configs.StateEndPointConfig <: Configs.AbstractEndPointConfig
                Test.@test Configs.StateEndPointConfig <: Configs.AbstractStateConfig
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

            Test.@testset "HamiltonianEndPointConfig subtypes" begin
                config = Configs.HamiltonianEndPointConfig(0.0, [1.0], [0.5], 1.0)
                Test.@test config isa Configs.AbstractConfig
                Test.@test config isa Configs.AbstractEndPointConfig
                Test.@test config isa Configs.AbstractHamiltonianConfig
                Test.@test Configs.HamiltonianEndPointConfig <: Configs.AbstractConfig
                Test.@test Configs.HamiltonianEndPointConfig <: Configs.AbstractEndPointConfig
                Test.@test Configs.HamiltonianEndPointConfig <: Configs.AbstractHamiltonianConfig
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

            Test.@testset "AugmentedHamiltonianEndPointConfig subtypes" begin
                config = Configs.AugmentedHamiltonianEndPointConfig(0.0, [1.0], [0.5], [0.0], 1.0)
                Test.@test config isa Configs.AbstractAugmentedHamiltonianConfig
                Test.@test config isa Configs.AbstractEndPointConfig
                Test.@test Configs.AugmentedHamiltonianEndPointConfig <: Configs.AbstractAugmentedHamiltonianConfig
                Test.@test Configs.AugmentedHamiltonianEndPointConfig <: Configs.AbstractEndPointConfig
            end
        end

        # ====================================================================
        # UNIT TESTS - AugmentedHamiltonianEndPointConfig Specific Methods
        # ====================================================================

        Test.@testset "UNIT TESTS - AugmentedHamiltonianEndPointConfig Specific Methods" begin
            Test.@testset "AugmentedHamiltonianEndPointConfig initial_condition" begin
                config = Configs.AugmentedHamiltonianEndPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], [0.0, 0.0], 1.0)
                ic = Configs.initial_condition(config)
                Test.@test ic == [1.0, 0.0, 0.5, 0.3, 0.0, 0.0]
            end

            Test.@testset "AugmentedHamiltonianEndPointConfig initial_state" begin
                config = Configs.AugmentedHamiltonianEndPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], [0.0, 0.0], 1.0)
                Test.@test Configs.initial_state(config) == [1.0, 0.0]
            end

            Test.@testset "AugmentedHamiltonianEndPointConfig initial_costate" begin
                config = Configs.AugmentedHamiltonianEndPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], [0.0, 0.0], 1.0)
                Test.@test Configs.initial_costate(config) == [0.5, 0.3]
            end

            Test.@testset "AugmentedHamiltonianEndPointConfig initial_variable_costate" begin
                config = Configs.AugmentedHamiltonianEndPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], [0.0, 0.0], 1.0)
                Test.@test Configs.initial_variable_costate(config) == [0.0, 0.0]
            end

            Test.@testset "AugmentedHamiltonianEndPointConfig tspan" begin
                config = Configs.AugmentedHamiltonianEndPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], [0.0, 0.0], 1.0)
                Test.@test Configs.tspan(config) == (0.0, 1.0)
            end
        end

        # ====================================================================
        # TYPE STABILITY TESTS
        # ====================================================================

        Test.@testset "TYPE STABILITY TESTS" begin
            Test.@testset "Type Stability: AugmentedHamiltonianEndPointConfig getters" begin
                config = Configs.AugmentedHamiltonianEndPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], [0.0, 0.0], 1.0)
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
