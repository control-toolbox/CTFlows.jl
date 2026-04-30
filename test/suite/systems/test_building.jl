module TestBuilding

import Test
import CTFlows.Systems
import CTFlows.Data
import CTFlows.Common

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Test function
# ==============================================================================

function test_building()
    Test.@testset "Building Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - build_system function
        # ====================================================================

        Test.@testset "build_system" begin
            Test.@testset "build_system returns VectorFieldSystem" begin
                vf = Data.VectorField(x -> -x; autonomous=true, variable=false)
                sys = Systems.build_system(vf)
                Test.@test sys isa Systems.VectorFieldSystem
                Test.@test sys isa Systems.AbstractSystem
            end

            Test.@testset "build_system preserves traits - Autonomous Fixed" begin
                vf = Data.VectorField(x -> x; autonomous=true, variable=false)
                sys = Systems.build_system(vf)
                Test.@test Common.time_dependence(sys) === Common.Autonomous
                Test.@test Common.variable_dependence(sys) === Common.Fixed
            end

            Test.@testset "build_system preserves traits - NonAutonomous Fixed" begin
                vf = Data.VectorField((t, x) -> t .* x; autonomous=false, variable=false)
                sys = Systems.build_system(vf)
                Test.@test Common.time_dependence(sys) === Common.NonAutonomous
                Test.@test Common.variable_dependence(sys) === Common.Fixed
            end

            Test.@testset "build_system preserves traits - Autonomous NonFixed" begin
                vf = Data.VectorField((x, v) -> x .+ v; autonomous=true, variable=true)
                sys = Systems.build_system(vf)
                Test.@test Common.time_dependence(sys) === Common.Autonomous
                Test.@test Common.variable_dependence(sys) === Common.NonFixed
            end

            Test.@testset "build_system preserves traits - NonAutonomous NonFixed" begin
                vf = Data.VectorField((t, x, v) -> t .* x .+ v; autonomous=false, variable=true)
                sys = Systems.build_system(vf)
                Test.@test Common.time_dependence(sys) === Common.NonAutonomous
                Test.@test Common.variable_dependence(sys) === Common.NonFixed
            end
        end

        # ====================================================================
        # UNIT TESTS - Integration with rhs!
        # ====================================================================

        Test.@testset "Integration with rhs!" begin
            Test.@testset "built system has working rhs!" begin
                vf = Data.VectorField(x -> -x; autonomous=true, variable=false)
                sys = Systems.build_system(vf)
                rhs = Systems.rhs!(sys)
                Test.@test rhs isa Function
            end

            Test.@testset "built system rhs! computes correctly" begin
                vf = Data.VectorField(x -> 2 .* x; autonomous=true, variable=false)
                sys = Systems.build_system(vf)
                rhs = Systems.rhs!(sys)
                du = zeros(2)
                rhs(du, [1.0, 2.0], nothing, 0.0)
                Test.@test du ≈ [2.0, 4.0] atol=1e-10
            end
        end

        # ====================================================================
        # UNIT TESTS - Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "Exported function" begin
                Test.@test isdefined(Systems, :build_system)
            end
        end
    end
end

end # module

test_building() = TestBuilding.test_building()