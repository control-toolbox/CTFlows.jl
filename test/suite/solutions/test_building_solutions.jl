module TestBuildingSolutions

import Test
import CTFlows.Solutions
import CTFlows.Systems
import CTFlows.Common
import CTFlows.Data

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for testing
# ==============================================================================

"""
Fake integration result for testing build_solution.
"""
struct FakeIntegrationResult <: Solutions.AbstractIntegrationResult
    u::Vector{Vector{Float64}}
end

Solutions.final_state(r::FakeIntegrationResult) = r.u[end]

# ==============================================================================
# Test function
# ==============================================================================

function test_building_solutions()
    Test.@testset "Building Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - build_solution for PointConfig
        # ====================================================================

        Test.@testset "build_solution - PointConfig" begin
            Test.@testset "vector initial condition returns final state" begin
                sys = Systems.VectorFieldSystem(Data.VectorField(x -> -x; is_autonomous=false, is_variable=false))
                result = FakeIntegrationResult([[1.0, 2.0], [0.5, 1.0]])
                config = Common.PointConfig(0.0, [1.0, 2.0], 1.0)
                
                output = Solutions.build_solution(result, sys, config)
                Test.@test output == [0.5, 1.0]
                Test.@test typeof(config) <: Common.PointConfig{Float64, <:AbstractVector, Float64}
            end

            Test.@testset "scalar initial condition unwraps length-1 vector" begin
                sys = Systems.VectorFieldSystem(Data.VectorField(x -> -x; is_autonomous=false, is_variable=false))
                result = FakeIntegrationResult([[3.0], [1.5]])
                config = Common.PointConfig(0.0, 3.0, 1.0)
                
                output = Solutions.build_solution(result, sys, config)
                Test.@test output == 1.5
                Test.@test typeof(config) == Common.PointConfig{Float64, Float64, Float64}
            end
        end

        # ====================================================================
        # UNIT TESTS - build_solution for TrajectoryConfig
        # ====================================================================

        Test.@testset "build_solution - TrajectoryConfig" begin
            Test.@testset "returns VectorFieldSolution wrapping result" begin
                sys = Systems.VectorFieldSystem(Data.VectorField(x -> -x; is_autonomous=false, is_variable=false))
                result = FakeIntegrationResult([[1.0, 2.0], [0.5, 1.0]])
                config = Common.TrajectoryConfig((0.0, 1.0), [1.0, 2.0])
                
                output = Solutions.build_solution(result, sys, config)
                Test.@test output isa Solutions.VectorFieldSolution
            end

            Test.@testset "VectorFieldSolution contains correct result" begin
                sys = Systems.VectorFieldSystem(Data.VectorField(x -> -x; is_autonomous=false, is_variable=false))
                result = FakeIntegrationResult([[1.0, 2.0], [0.5, 1.0]])
                config = Common.TrajectoryConfig((0.0, 1.0), [1.0, 2.0])
                
                output = Solutions.build_solution(result, sys, config)
                Test.@test output.result === result
            end
        end

        # ====================================================================
        # UNIT TESTS - Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "build_solution is exported" begin
                Test.@test isdefined(Solutions, :build_solution)
            end
        end
    end
end

end # module

test_building_solutions() = TestBuildingSolutions.test_building_solutions()