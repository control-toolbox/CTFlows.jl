module TestConfigsModule

import Test
import CTFlows.Configs
import CTFlows.Traits

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_configs_module()
    Test.@testset "Configs Module Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Module Structure
        # ====================================================================

        Test.@testset "UNIT TESTS - Module Structure" begin
            Test.@testset "Configs module is defined" begin
                Test.@test isdefined(Configs, :Configs)
            end

            Test.@testset "Configs module has expected imports" begin
                Test.@test isdefined(Configs, :Exceptions)
                Test.@test isdefined(Configs, :Traits)
            end
        end

        # ====================================================================
        # Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "Exported abstract types" begin
                for sym in (:AbstractConfig, :AbstractConfigWithMaC,
                           :AbstractPointConfig, :AbstractTrajectoryConfig,
                           :AbstractStateConfig, :AbstractHamiltonianConfig,
                           :AbstractAugmentedHamiltonianConfig)
                    Test.@test isdefined(Configs, sym)
                end
            end

            Test.@testset "Exported concrete types" begin
                for sym in (:StatePointConfig, :StateTrajectoryConfig,
                           :HamiltonianPointConfig, :HamiltonianTrajectoryConfig,
                           :AugmentedHamiltonianPointConfig)
                    Test.@test isdefined(Configs, sym)
                end
            end

            Test.@testset "Exported functions" begin
                for sym in (:tspan, :initial_condition, :initial_state, :initial_costate,
                           :initial_variable_costate, :initial_time, :final_time,
                           :mode_trait, :content_trait)
                    Test.@test isdefined(Configs, sym)
                end
            end
        end
    end
end

end # module

test_configs_module() = TestConfigsModule.test_configs_module()
