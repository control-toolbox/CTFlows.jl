module TestAbstractConfigs

import Test
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
struct FakeConfig{X0} <: Configs.AbstractConfigWithMaC{X0, Traits.PointTrait, Traits.StateDynamics}
    x0::X0
end

function test_abstract_configs()
    Test.@testset "Abstract Configs Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "UNIT TESTS - Abstract Types" begin
            Test.@testset "AbstractConfig" begin
                Test.@testset "AbstractConfig is exported" begin
                    Test.@test isdefined(Configs, :AbstractConfig)
                end

                Test.@testset "AbstractConfig is abstract" begin
                    Test.@test isabstracttype(Configs.AbstractConfig)
                end
            end

            Test.@testset "AbstractConfigWithMaC" begin
                Test.@testset "AbstractConfigWithMaC is exported" begin
                    Test.@test isdefined(Configs, :AbstractConfigWithMaC)
                end

                Test.@testset "AbstractConfigWithMaC is abstract" begin
                    Test.@test isabstracttype(Configs.AbstractConfigWithMaC)
                end
            end

            Test.@testset "Type Aliases" begin
                Test.@testset "AbstractPointConfig is exported" begin
                    Test.@test isdefined(Configs, :AbstractPointConfig)
                end

                Test.@testset "AbstractTrajectoryConfig is exported" begin
                    Test.@test isdefined(Configs, :AbstractTrajectoryConfig)
                end

                Test.@testset "AbstractStateConfig is exported" begin
                    Test.@test isdefined(Configs, :AbstractStateConfig)
                end

                Test.@testset "AbstractHamiltonianConfig is exported" begin
                    Test.@test isdefined(Configs, :AbstractHamiltonianConfig)
                end

                Test.@testset "AbstractAugmentedHamiltonianConfig is exported" begin
                    Test.@test isdefined(Configs, :AbstractAugmentedHamiltonianConfig)
                end
            end

            Test.@testset "Trait Alias Hierarchy" begin
                Test.@testset "StatePointConfig subtypes" begin
                    Test.@test Configs.StatePointConfig <: Configs.AbstractPointConfig
                    Test.@test Configs.StatePointConfig <: Configs.AbstractStateConfig
                end

                Test.@testset "HamiltonianPointConfig subtypes" begin
                    Test.@test Configs.HamiltonianPointConfig <: Configs.AbstractPointConfig
                    Test.@test Configs.HamiltonianPointConfig <: Configs.AbstractHamiltonianConfig
                end

                Test.@testset "StateTrajectoryConfig subtypes" begin
                    Test.@test Configs.StateTrajectoryConfig <: Configs.AbstractTrajectoryConfig
                    Test.@test Configs.StateTrajectoryConfig <: Configs.AbstractStateConfig
                end

                Test.@testset "HamiltonianTrajectoryConfig subtypes" begin
                    Test.@test Configs.HamiltonianTrajectoryConfig <: Configs.AbstractTrajectoryConfig
                    Test.@test Configs.HamiltonianTrajectoryConfig <: Configs.AbstractHamiltonianConfig
                end

                Test.@testset "Negative checks" begin
                    Test.@test !(Configs.StatePointConfig <: Configs.AbstractHamiltonianConfig)
                    Test.@test !(Configs.HamiltonianPointConfig <: Configs.AbstractStateConfig)
                    Test.@test !(Configs.StatePointConfig <: Configs.AbstractTrajectoryConfig)
                end
            end
        end

        # ====================================================================
        # UNIT TESTS - Trait Accessors
        # ====================================================================

        Test.@testset "UNIT TESTS - Trait Accessors" begin
            Test.@testset "mode_trait" begin
                Test.@testset "mode_trait for StatePointConfig" begin
                    config = Configs.StatePointConfig(0.0, [1.0], 1.0)
                    Test.@test Configs.mode_trait(config) === Traits.PointTrait
                end

                Test.@testset "mode_trait for StateTrajectoryConfig" begin
                    config = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0])
                    Test.@test Configs.mode_trait(config) === Traits.TrajectoryTrait
                end

                Test.@testset "mode_trait for HamiltonianPointConfig" begin
                    config = Configs.HamiltonianPointConfig(0.0, [1.0], [0.5], 1.0)
                    Test.@test Configs.mode_trait(config) === Traits.PointTrait
                end

                Test.@testset "mode_trait for HamiltonianTrajectoryConfig" begin
                    config = Configs.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0], [0.5])
                    Test.@test Configs.mode_trait(config) === Traits.TrajectoryTrait
                end
            end

            Test.@testset "dynamics_trait" begin
                Test.@testset "dynamics_trait for StatePointConfig" begin
                    config = Configs.StatePointConfig(0.0, [1.0], 1.0)
                    Test.@test Configs.dynamics_trait(config) === Traits.StateDynamics
                end

                Test.@testset "dynamics_trait for HamiltonianPointConfig" begin
                    config = Configs.HamiltonianPointConfig(0.0, [1.0], [0.5], 1.0)
                    Test.@test Configs.dynamics_trait(config) === Traits.HamiltonianDynamics
                end
            end
        end
    end
end

end # module

test_abstract_configs() = TestAbstractConfigs.test_abstract_configs()
