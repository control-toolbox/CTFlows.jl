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
                vf = Systems.VectorField(x -> x, Common.Autonomous, Common.Fixed)
                Test.@test vf isa Systems.VectorField
            end

            Test.@testset "keyword constructor with defaults" begin
                vf = Systems.VectorField(x -> x)
                Test.@test vf isa Systems.VectorField
                Test.@test Systems.time_dependence(vf) === Common.Autonomous
                Test.@test Systems.variable_dependence(vf) === Common.Fixed
            end

            Test.@testset "keyword constructor with explicit flags" begin
                vf_autonomous = Systems.VectorField(x -> x; autonomous=true, variable=false)
                Test.@test Systems.time_dependence(vf_autonomous) === Common.Autonomous
                Test.@test Systems.variable_dependence(vf_autonomous) === Common.Fixed

                vf_nonautonomous = Systems.VectorField((t, x) -> t .* x; autonomous=false, variable=false)
                Test.@test Systems.time_dependence(vf_nonautonomous) === Common.NonAutonomous
                Test.@test Systems.variable_dependence(vf_nonautonomous) === Common.Fixed

                vf_nonfixed = Systems.VectorField((x, v) -> x .+ v; autonomous=true, variable=true)
                Test.@test Systems.time_dependence(vf_nonfixed) === Common.Autonomous
                Test.@test Systems.variable_dependence(vf_nonfixed) === Common.NonFixed
            end
        end

        # ====================================================================
        # UNIT TESTS - Uniform Dispatch
        # ====================================================================

        Test.@testset "Uniform Dispatch" begin
            Test.@testset "Scalar case" begin
                vf = Systems.VectorField(x -> -2x, Common.Autonomous, Common.Fixed)
                result = vf(3.0)
                Test.@test result == -6.0
            end

            Test.@testset "Vector case" begin
                vf = Systems.VectorField(x -> -x, Common.Autonomous, Common.Fixed)
                result = vf([1.0, 2.0])
                Test.@test result == [-1.0, -2.0]
            end

            Test.@testset "Matrix case" begin
                vf = Systems.VectorField(x -> -x, Common.Autonomous, Common.Fixed)
                x0 = [1.0 2.0; 3.0 4.0]
                result = vf(x0)
                Test.@test result == -x0
            end

            Test.@testset "NonAutonomous Fixed" begin
                vf = Systems.VectorField((t, x) -> t .* x, Common.NonAutonomous, Common.Fixed)
                result = vf(2.0, [1.0, 2.0])
                Test.@test result == [2.0, 4.0]
            end

            Test.@testset "Autonomous NonFixed" begin
                vf = Systems.VectorField((x, v) -> x .+ v, Common.Autonomous, Common.NonFixed)
                result = vf([1.0, 2.0], 0.5)
                Test.@test result == [1.5, 2.5]
            end

            Test.@testset "NonAutonomous NonFixed" begin
                vf = Systems.VectorField((t, x, v) -> t .* x .+ v, Common.NonAutonomous, Common.NonFixed)
                result = vf(2.0, [1.0, 2.0], 0.5)
                Test.@test result == [2.5, 4.5]
            end
        end

        # ====================================================================
        # UNIT TESTS - VectorFieldSystem
        # ====================================================================

        Test.@testset "VectorFieldSystem" begin
            Test.@testset "constructs from VectorField" begin
                vf = Systems.VectorField(x -> x, Common.Autonomous, Common.Fixed)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test sys isa Systems.VectorFieldSystem
                Test.@test sys isa Systems.AbstractSystem
            end

            Test.@testset "trait propagation - Autonomous Fixed" begin
                vf = Systems.VectorField(x -> x, Common.Autonomous, Common.Fixed)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Systems.time_dependence(sys) === Common.Autonomous
                Test.@test Systems.variable_dependence(sys) === Common.Fixed
            end

            Test.@testset "trait propagation - NonAutonomous Fixed" begin
                vf = Systems.VectorField((t, x) -> t .* x, Common.NonAutonomous, Common.Fixed)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Systems.time_dependence(sys) === Common.NonAutonomous
                Test.@test Systems.variable_dependence(sys) === Common.Fixed
            end

            Test.@testset "trait propagation - Autonomous NonFixed" begin
                vf = Systems.VectorField((x, v) -> x .+ v, Common.Autonomous, Common.NonFixed)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Systems.time_dependence(sys) === Common.Autonomous
                Test.@test Systems.variable_dependence(sys) === Common.NonFixed
            end

            Test.@testset "trait propagation - NonAutonomous NonFixed" begin
                vf = Systems.VectorField((t, x, v) -> t .* x .+ v, Common.NonAutonomous, Common.NonFixed)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Systems.time_dependence(sys) === Common.NonAutonomous
                Test.@test Systems.variable_dependence(sys) === Common.NonFixed
            end
        end

        # ====================================================================
        # UNIT TESTS - CTModels-style predicates
        # ====================================================================

        Test.@testset "CTModels-style predicates" begin
            Test.@testset "is_autonomous" begin
                vf_aut = Systems.VectorField(x -> x, Common.Autonomous, Common.Fixed)
                Test.@test Systems.is_autonomous(vf_aut) === true
                Test.@test Systems.is_nonautonomous(vf_aut) === false

                vf_nonaut = Systems.VectorField((t, x) -> t .* x, Common.NonAutonomous, Common.Fixed)
                Test.@test Systems.is_autonomous(vf_nonaut) === false
                Test.@test Systems.is_nonautonomous(vf_nonaut) === true
            end

            Test.@testset "is_variable / has_variable" begin
                vf_fixed = Systems.VectorField(x -> x, Common.Autonomous, Common.Fixed)
                Test.@test Systems.is_variable(vf_fixed) === false
                Test.@test Systems.has_variable(vf_fixed) === false
                Test.@test Systems.is_nonvariable(vf_fixed) === true

                vf_nonfixed = Systems.VectorField((x, v) -> x .+ v, Common.Autonomous, Common.NonFixed)
                Test.@test Systems.is_variable(vf_nonfixed) === true
                Test.@test Systems.has_variable(vf_nonfixed) === true
                Test.@test Systems.is_nonvariable(vf_nonfixed) === false
            end
        end
    end
end

end # module

test_vector_field() = TestVectorField.test_vector_field()
