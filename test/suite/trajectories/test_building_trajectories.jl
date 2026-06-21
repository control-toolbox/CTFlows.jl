module TestBuildingTrajectories

import Test
import CTFlows.Trajectories
import CTFlows.Systems
import CTFlows.Common
import CTFlows.Configs
import CTFlows.Data
import CTFlows.Integrators

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for testing
# ==============================================================================

"""
Fake integration result for testing build_trajectory.
"""
struct FakeIntegrationResult <: Integrators.AbstractIntegrationResult
    u::Vector{Vector{Float64}}
end

Integrators.final_state(r::FakeIntegrationResult) = r.u[end]

# ==============================================================================
# Test function
# ==============================================================================

function test_building_trajectories()
    Test.@testset "Building Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - build_trajectory for StateEndPointConfig
        # ====================================================================

        Test.@testset "build_trajectory - StateEndPointConfig" begin
            Test.@testset "vector initial condition returns final state" begin
                sys = Systems.VectorFieldSystem(Data.VectorField(x -> -x; is_autonomous=true, is_variable=false))
                result = FakeIntegrationResult([[1.0, 2.0], [0.5, 1.0]])
                config = Configs.StateEndPointConfig(0.0, [1.0, 2.0], 1.0)
                
                output = Trajectories.build_trajectory(Configs.mode_trait(config), Configs.dynamics_trait(config), config, result)
                Test.@test output == [0.5, 1.0]
                Test.@test typeof(config) <: Configs.StateEndPointConfig{Float64, <:AbstractVector, Float64}
            end

            Test.@testset "scalar initial condition unwraps length-1 vector" begin
                sys = Systems.VectorFieldSystem(Data.VectorField(x -> -x; is_autonomous=true, is_variable=false))
                result = FakeIntegrationResult([[3.0], [1.5]])
                config = Configs.StateEndPointConfig(0.0, 3.0, 1.0)
                
                output = Trajectories.build_trajectory(Configs.mode_trait(config), Configs.dynamics_trait(config), config, result)
                Test.@test output == 1.5
                Test.@test typeof(config) == Configs.StateEndPointConfig{Float64, Float64, Float64}
            end
        end

        # ====================================================================
        # UNIT TESTS - build_trajectory for StateTrajectoryConfig
        # ====================================================================

        Test.@testset "build_trajectory - StateTrajectoryConfig" begin
            Test.@testset "returns VectorFieldTrajectory wrapping result" begin
                sys = Systems.VectorFieldSystem(Data.VectorField(x -> -x; is_autonomous=true, is_variable=false))
                result = FakeIntegrationResult([[1.0, 2.0], [0.5, 1.0]])
                config = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0, 2.0])
                
                output = Trajectories.build_trajectory(Configs.mode_trait(config), Configs.dynamics_trait(config), config, result)
                Test.@test output isa Trajectories.VectorFieldTrajectory
            end

            Test.@testset "VectorFieldTrajectory contains correct result" begin
                sys = Systems.VectorFieldSystem(Data.VectorField(x -> -x; is_autonomous=true, is_variable=false))
                result = FakeIntegrationResult([[1.0, 2.0], [0.5, 1.0]])
                config = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0, 2.0])
                
                output = Trajectories.build_trajectory(Configs.mode_trait(config), Configs.dynamics_trait(config), config, result)
                Test.@test output.result === result
            end
        end

        # ====================================================================
        # UNIT TESTS - build_trajectory for HamiltonianEndPointConfig
        # ====================================================================

        Test.@testset "build_trajectory - HamiltonianEndPointConfig" begin
            Test.@testset "scalar initial condition returns tuple of scalars" begin
                sys = Systems.HamiltonianVectorFieldSystem(
                    Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
                )
                result = FakeIntegrationResult([[1.0, 0.5], [0.5, 0.25]])
                config = Configs.HamiltonianEndPointConfig(0.0, 1.0, 0.5, 1.0)
                
                output = Trajectories.build_trajectory(Configs.mode_trait(config), Configs.dynamics_trait(config), config, result)
                Test.@test output == (0.5, 0.25)
                Test.@test typeof(config) == Configs.HamiltonianEndPointConfig{Float64, Float64, Float64, Float64}
            end

            Test.@testset "vector initial condition returns tuple of vectors" begin
                sys = Systems.HamiltonianVectorFieldSystem(
                    Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
                )
                result = FakeIntegrationResult([[1.0, 2.0, 0.5, 0.3], [0.5, 1.0, 0.25, 0.15]])
                config = Configs.HamiltonianEndPointConfig(0.0, [1.0, 2.0], [0.5, 0.3], 1.0)
                
                output = Trajectories.build_trajectory(Configs.mode_trait(config), Configs.dynamics_trait(config), config, result)
                Test.@test output == ([0.5, 1.0], [0.25, 0.15])
                Test.@test typeof(config) <: Configs.HamiltonianEndPointConfig{Float64, <:AbstractVector, <:AbstractVector, Float64}
            end

            Test.@testset "vector initial condition uses correct dimension split" begin
                # Test the bug fix: should use length(initial_state) not length(initial_condition)
                sys = Systems.HamiltonianVectorFieldSystem(
                    Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
                )
                # Final state has 6 elements: 3 state + 3 costate
                result = FakeIntegrationResult([[1.0, 2.0, 3.0, 0.5, 0.6, 0.7], [0.5, 1.0, 1.5, 0.25, 0.3, 0.35]])
                config = Configs.HamiltonianEndPointConfig(0.0, [1.0, 2.0, 3.0], [0.5, 0.6, 0.7], 1.0)
                
                output = Trajectories.build_trajectory(Configs.mode_trait(config), Configs.dynamics_trait(config), config, result)
                # Should split into first 3 (state) and last 3 (costate)
                Test.@test output == ([0.5, 1.0, 1.5], [0.25, 0.3, 0.35])
            end
        end

        # ====================================================================
        # UNIT TESTS - build_trajectory for HamiltonianTrajectoryConfig
        # ====================================================================

        Test.@testset "build_trajectory - HamiltonianTrajectoryConfig" begin
            Test.@testset "returns HamiltonianVectorFieldTrajectory wrapping result" begin
                sys = Systems.HamiltonianVectorFieldSystem(
                    Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
                )
                result = FakeIntegrationResult([[1.0, 2.0, 0.5, 0.3], [0.5, 1.0, 0.25, 0.15]])
                config = Configs.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0, 2.0], [0.5, 0.3])
                
                output = Trajectories.build_trajectory(Configs.mode_trait(config), Configs.dynamics_trait(config), config, result)
                Test.@test output isa Trajectories.HamiltonianVectorFieldTrajectory
            end

            Test.@testset "HamiltonianVectorFieldTrajectory contains correct result" begin
                sys = Systems.HamiltonianVectorFieldSystem(
                    Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
                )
                result = FakeIntegrationResult([[1.0, 2.0, 0.5, 0.3], [0.5, 1.0, 0.25, 0.15]])
                config = Configs.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0, 2.0], [0.5, 0.3])
                
                output = Trajectories.build_trajectory(Configs.mode_trait(config), Configs.dynamics_trait(config), config, result)
                Test.@test output.result === result
            end
        end

        # ====================================================================
        # UNIT TESTS - Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "build_trajectory is exported" begin
                Test.@test isdefined(Trajectories, :build_trajectory)
            end

            Test.@testset "HamiltonianVectorFieldTrajectory is exported" begin
                Test.@test isdefined(Trajectories, :HamiltonianVectorFieldTrajectory)
            end
        end
    end
end

end # module

test_building_trajectories() = TestBuildingTrajectories.test_building_trajectories()