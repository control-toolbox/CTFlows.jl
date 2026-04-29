module TestVectorField

import Test
import CTFlows.Systems
import CTFlows.Common

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Test function
# ==============================================================================

function test_vector_field()
    Test.@testset "VectorField Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - VectorField Construction
        # ====================================================================

        Test.@testset "VectorField Construction" begin
            Test.@testset "constructs with traits" begin
                vf = Systems.VectorField(x -> x, Systems.Autonomous, Systems.Fixed)
                Test.@test vf isa Systems.VectorField
            end
        end

        # ====================================================================
        # UNIT TESTS - Uniform Dispatch
        # ====================================================================

        Test.@testset "Uniform Dispatch" begin
            Test.@testset "Autonomous Fixed" begin
                vf = Systems.VectorField(x -> x, Systems.Autonomous, Systems.Fixed)
                result = vf([1.0, 2.0])
                Test.@test result == [1.0, 2.0]
            end

            Test.@testset "NonAutonomous Fixed" begin
                vf = Systems.VectorField((t, x) -> t .* x, Systems.NonAutonomous, Systems.Fixed)
                result = vf(2.0, [1.0, 2.0])
                Test.@test result == [2.0, 4.0]
            end

            Test.@testset "Autonomous NonFixed" begin
                vf = Systems.VectorField((x, v) -> x .+ v, Systems.Autonomous, Systems.NonFixed)
                result = vf([1.0, 2.0], 0.5)
                Test.@test result == [1.5, 2.5]
            end

            Test.@testset "NonAutonomous NonFixed" begin
                vf = Systems.VectorField((t, x, v) -> t .* x .+ v, Systems.NonAutonomous, Systems.NonFixed)
                result = vf(2.0, [1.0, 2.0], 0.5)
                Test.@test result == [2.5, 4.5]
            end
        end

        # ====================================================================
        # UNIT TESTS - VectorFieldSystem
        # ====================================================================

        Test.@testset "VectorFieldSystem" begin
            Test.@testset "constructs from VectorField" begin
                vf = Systems.VectorField(x -> x, Systems.Autonomous, Systems.Fixed)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test sys isa Systems.VectorFieldSystem
                Test.@test sys isa Systems.AbstractSystem
            end

            Test.@testset "variable_dependence returns Fixed" begin
                vf = Systems.VectorField(x -> x, Systems.Autonomous, Systems.Fixed)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Systems.variable_dependence(sys) === Systems.Fixed
            end

            Test.@testset "variable_dependence returns NonFixed" begin
                vf = Systems.VectorField((x, v) -> x .+ v, Systems.Autonomous, Systems.NonFixed)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Systems.variable_dependence(sys) === Systems.NonFixed
            end
        end
    end
end

end # module

test_vector_field() = TestVectorField.test_vector_field()
