module TestBuildingSolutions

import Test
import CTFlows.Solutions
import CTFlows.Systems
import CTFlows.Common
import CTFlows.Data
import SciMLBase: SciMLBase

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for testing
# ==============================================================================

"""
Fake ODE solution for testing build_solution.
"""
struct FakeODESolution <: SciMLBase.AbstractODESolution{Any, Any, Any}
    u::Vector{Vector{Float64}}
end

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
                sys = Systems.VectorFieldSystem(Data.VectorField(x -> -x; autonomous=true, variable=false))
                ode_sol = FakeODESolution([[1.0, 2.0], [0.5, 1.0]])
                config = Common.PointConfig(0.0, [1.0, 2.0], 1.0)
                
                result = Solutions.build_solution(ode_sol, sys, config)
                Test.@test result == [0.5, 1.0]
            end

            Test.@testset "scalar initial condition unwraps length-1 vector" begin
                sys = Systems.VectorFieldSystem(Data.VectorField(x -> -x; autonomous=true, variable=false))
                ode_sol = FakeODESolution([[3.0], [1.5]])
                config = Common.PointConfig(0.0, 3.0, 1.0)
                
                result = Solutions.build_solution(ode_sol, sys, config)
                Test.@test result == 1.5
            end
        end

        # ====================================================================
        # UNIT TESTS - build_solution for TrajectoryConfig
        # ====================================================================

        Test.@testset "build_solution - TrajectoryConfig" begin
            Test.@testset "returns VectorFieldSolution wrapping raw ODE solution" begin
                sys = Systems.VectorFieldSystem(Data.VectorField(x -> -x; autonomous=true, variable=false))
                ode_sol = FakeODESolution([[1.0, 2.0], [0.5, 1.0]])
                config = Common.TrajectoryConfig((0.0, 1.0), [1.0, 2.0])
                
                result = Solutions.build_solution(ode_sol, sys, config)
                Test.@test result isa Solutions.VectorFieldSolution
            end

            Test.@testset "VectorFieldSolution contains correct ODE solution" begin
                sys = Systems.VectorFieldSystem(Data.VectorField(x -> -x; autonomous=true, variable=false))
                ode_sol = FakeODESolution([[1.0, 2.0], [0.5, 1.0]])
                config = Common.TrajectoryConfig((0.0, 1.0), [1.0, 2.0])
                
                result = Solutions.build_solution(ode_sol, sys, config)
                Test.@test Solutions.raw(result) === ode_sol
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

test_building_solutions() = TestBuilding.test_building_solutions()