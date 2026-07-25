module TestBuildingSystems

using Test: Test
import CTFlows.Systems
import CTFlows.Configs
import CTBase.Data
import CTBase.Traits

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Test function
# ==============================================================================

function test_building_systems()
    Test.@testset "Building Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - build_system function
        # ====================================================================

        Test.@testset "build_system" begin
            Test.@testset "build_system returns VectorFieldSystem" begin
                vf = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.build_system(vf)
                Test.@test sys isa Systems.VectorFieldSystem
                Test.@test sys isa Systems.AbstractSystem
            end

            Test.@testset "build_system preserves traits - Autonomous Fixed" begin
                vf = Data.VectorField(x -> x; is_autonomous=true, is_variable=false)
                sys = Systems.build_system(vf)
                Test.@test Traits.time_dependence(sys) === Traits.Autonomous
                Test.@test Traits.variable_dependence(sys) === Traits.Fixed
            end

            Test.@testset "build_system preserves traits - NonAutonomous Fixed" begin
                vf = Data.VectorField(
                    (t, x) -> t .* x; is_autonomous=false, is_variable=false
                )
                sys = Systems.build_system(vf)
                Test.@test Traits.time_dependence(sys) === Traits.NonAutonomous
                Test.@test Traits.variable_dependence(sys) === Traits.Fixed
            end

            Test.@testset "build_system preserves traits - Autonomous NonFixed" begin
                vf = Data.VectorField(
                    (x, v) -> x .+ v; is_autonomous=true, is_variable=true
                )
                sys = Systems.build_system(vf)
                Test.@test Traits.time_dependence(sys) === Traits.Autonomous
                Test.@test Traits.variable_dependence(sys) === Traits.NonFixed
            end

            Test.@testset "build_system preserves traits - NonAutonomous NonFixed" begin
                vf = Data.VectorField(
                    (t, x, v) -> t .* x .+ v; is_autonomous=false, is_variable=true
                )
                sys = Systems.build_system(vf)
                Test.@test Traits.time_dependence(sys) === Traits.NonAutonomous
                Test.@test Traits.variable_dependence(sys) === Traits.NonFixed
            end
        end

        # ====================================================================
        # UNIT TESTS - Integration with get_ip_rhs
        # ====================================================================

        Test.@testset "Integration with get_ip_rhs" begin
            config = Configs.StateEndPointConfig(0.0, [1.0, 2.0], 1.0)
            Test.@testset "built system has working get_ip_rhs" begin
                vf = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.build_system(vf)
                rhs = Systems.get_ip_rhs(sys, config)
                Test.@test rhs isa Systems.AbstractRHS
            end

            Test.@testset "built system get_ip_rhs computes correctly" begin
                vf = Data.VectorField(x -> 2 .* x; is_autonomous=true, is_variable=false)
                sys = Systems.build_system(vf)
                rhs = Systems.get_ip_rhs(sys, config)
                du = zeros(2)
                p = Systems.ODEParameters(nothing)
                rhs(du, [1.0, 2.0], p, 0.0)
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

test_building_systems() = TestBuildingSystems.test_building_systems()
