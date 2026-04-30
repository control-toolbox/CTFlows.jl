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
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            vf = Systems.VectorField(x -> x; autonomous=true, variable=false)
            Test.@test vf isa Systems.VectorField
        end

        # ====================================================================
        # UNIT TESTS - Construction
        # ====================================================================

        Test.@testset "Construction" begin
            Test.@testset "keyword constructor with defaults" begin
                vf = Systems.VectorField(x -> x)
                Test.@test vf isa Systems.VectorField
                Test.@test Common.time_dependence(vf) === Common.Autonomous
                Test.@test Common.variable_dependence(vf) === Common.Fixed
            end

            Test.@testset "keyword constructor with explicit flags" begin
                vf_autonomous = Systems.VectorField(x -> x; autonomous=true, variable=false)
                Test.@test Common.time_dependence(vf_autonomous) === Common.Autonomous
                Test.@test Common.variable_dependence(vf_autonomous) === Common.Fixed

                vf_nonautonomous = Systems.VectorField((t, x) -> t .* x; autonomous=false, variable=false)
                Test.@test Common.time_dependence(vf_nonautonomous) === Common.NonAutonomous
                Test.@test Common.variable_dependence(vf_nonautonomous) === Common.Fixed

                vf_nonfixed = Systems.VectorField((x, v) -> x .+ v; autonomous=true, variable=true)
                Test.@test Common.time_dependence(vf_nonfixed) === Common.Autonomous
                Test.@test Common.variable_dependence(vf_nonfixed) === Common.NonFixed

                vf_full = Systems.VectorField((t, x, v) -> t .* x .+ v; autonomous=false, variable=true)
                Test.@test Common.time_dependence(vf_full) === Common.NonAutonomous
                Test.@test Common.variable_dependence(vf_full) === Common.NonFixed
            end
        end

        # ====================================================================
        # UNIT TESTS - Trait Methods
        # ====================================================================

        Test.@testset "Trait Methods" begin
            vf_aut = Systems.VectorField(x -> x; autonomous=true, variable=false)
            vf_nonaut = Systems.VectorField((t, x) -> t .* x; autonomous=false, variable=false)
            vf_fixed = Systems.VectorField(x -> x; autonomous=true, variable=false)
            vf_nonfixed = Systems.VectorField((x, v) -> x .+ v; autonomous=true, variable=true)

            Test.@testset "has_time_dependence_trait returns true" begin
                Test.@test Common.has_time_dependence_trait(vf_aut) === true
                Test.@test Common.has_time_dependence_trait(vf_nonaut) === true
            end

            Test.@testset "has_variable_dependence_trait returns true" begin
                Test.@test Common.has_variable_dependence_trait(vf_fixed) === true
                Test.@test Common.has_variable_dependence_trait(vf_nonfixed) === true
            end

            Test.@testset "time_dependence returns correct trait" begin
                Test.@test Common.time_dependence(vf_aut) === Common.Autonomous
                Test.@test Common.time_dependence(vf_nonaut) === Common.NonAutonomous
            end

            Test.@testset "variable_dependence returns correct trait" begin
                Test.@test Common.variable_dependence(vf_fixed) === Common.Fixed
                Test.@test Common.variable_dependence(vf_nonfixed) === Common.NonFixed
            end
        end

        # ====================================================================
        # UNIT TESTS - Natural Call Signatures
        # ====================================================================

        Test.@testset "Natural Call Signatures" begin
            Test.@testset "Autonomous Fixed - (x)" begin
                vf = Systems.VectorField(x -> -x; autonomous=true, variable=false)
                
                Test.@testset "scalar" begin
                    Test.@test vf(3.0) == -3.0
                end
                
                Test.@testset "vector" begin
                    Test.@test vf([1.0, 2.0]) == [-1.0, -2.0]
                end
                
                Test.@testset "matrix" begin
                    x0 = [1.0 2.0; 3.0 4.0]
                    result = vf(x0)
                    Test.@test result == -x0
                end
            end

            Test.@testset "NonAutonomous Fixed - (t, x)" begin
                vf = Systems.VectorField((t, x) -> t .* x; autonomous=false, variable=false)
                
                Test.@testset "scalar" begin
                    Test.@test vf(2.0, 3.0) == 6.0
                end
                
                Test.@testset "vector" begin
                    Test.@test vf(2.0, [1.0, 2.0]) == [2.0, 4.0]
                end
                
                Test.@testset "matrix" begin
                    x0 = [1.0 2.0; 3.0 4.0]
                    result = vf(2.0, x0)
                    Test.@test result == 2 .* x0
                end
            end

            Test.@testset "Autonomous NonFixed - (x, v)" begin
                vf = Systems.VectorField((x, v) -> x .+ v; autonomous=true, variable=true)
                
                Test.@testset "scalar" begin
                    Test.@test vf(3.0, 0.5) == 3.5
                end
                
                Test.@testset "vector" begin
                    Test.@test vf([1.0, 2.0], 0.5) == [1.5, 2.5]
                end
                
                Test.@testset "matrix" begin
                    x0 = [1.0 2.0; 3.0 4.0]
                    result = vf(x0, 0.5)
                    Test.@test result == x0 .+ 0.5
                end
            end

            Test.@testset "NonAutonomous NonFixed - (t, x, v)" begin
                vf = Systems.VectorField((t, x, v) -> t .* x .+ v; autonomous=false, variable=true)
                
                Test.@testset "scalar" begin
                    Test.@test vf(2.0, 3.0, 0.5) == 6.5
                end
                
                Test.@testset "vector" begin
                    Test.@test vf(2.0, [1.0, 2.0], 0.5) == [2.5, 4.5]
                end
                
                Test.@testset "matrix" begin
                    x0 = [1.0 2.0; 3.0 4.0]
                    result = vf(2.0, x0, 0.5)
                    Test.@test result == 2 .* x0 .+ 0.5
                end
            end
        end

        # ====================================================================
        # UNIT TESTS - Uniform Call Signature (t, x, v)
        # ====================================================================

        Test.@testset "Uniform Call Signature" begin
            Test.@testset "Autonomous Fixed ignores t and v" begin
                vf = Systems.VectorField(x -> -x; autonomous=true, variable=false)
                
                Test.@testset "scalar" begin
                    Test.@test vf(0.0, 3.0, 0.0) == -3.0
                end
                
                Test.@testset "vector" begin
                    Test.@test vf(0.0, [1.0, 2.0], 0.0) == [-1.0, -2.0]
                end
                
                Test.@testset "matrix" begin
                    x0 = [1.0 2.0; 3.0 4.0]
                    result = vf(0.0, x0, 0.0)
                    Test.@test result == -x0
                end
            end

            Test.@testset "NonAutonomous Fixed uses t, ignores v" begin
                vf = Systems.VectorField((t, x) -> t .* x; autonomous=false, variable=false)
                
                Test.@testset "scalar" begin
                    Test.@test vf(2.0, 3.0, 0.0) == 6.0
                end
                
                Test.@testset "vector" begin
                    Test.@test vf(2.0, [1.0, 2.0], 0.0) == [2.0, 4.0]
                end
                
                Test.@testset "matrix" begin
                    x0 = [1.0 2.0; 3.0 4.0]
                    result = vf(2.0, x0, 0.0)
                    Test.@test result == 2 .* x0
                end
            end

            Test.@testset "Autonomous NonFixed ignores t, uses v" begin
                vf = Systems.VectorField((x, v) -> x .+ v; autonomous=true, variable=true)
                
                Test.@testset "scalar" begin
                    Test.@test vf(0.0, 3.0, 0.5) == 3.5
                end
                
                Test.@testset "vector" begin
                    Test.@test vf(0.0, [1.0, 2.0], 0.5) == [1.5, 2.5]
                end
                
                Test.@testset "matrix" begin
                    x0 = [1.0 2.0; 3.0 4.0]
                    result = vf(0.0, x0, 0.5)
                    Test.@test result == x0 .+ 0.5
                end
            end
        end

        # ====================================================================
        # UNIT TESTS - Common Trait Predicates
        # ====================================================================

        Test.@testset "Common Trait Predicates" begin
            vf_aut = Systems.VectorField(x -> x; autonomous=true, variable=false)
            vf_nonaut = Systems.VectorField((t, x) -> t .* x; autonomous=false, variable=false)
            vf_fixed = Systems.VectorField(x -> x; autonomous=true, variable=false)
            vf_nonfixed = Systems.VectorField((x, v) -> x .+ v; autonomous=true, variable=true)

            Test.@testset "is_autonomous / is_nonautonomous" begin
                Test.@test Common.is_autonomous(vf_aut) === true
                Test.@test Common.is_nonautonomous(vf_aut) === false
                Test.@test Common.is_autonomous(vf_nonaut) === false
                Test.@test Common.is_nonautonomous(vf_nonaut) === true
            end

            Test.@testset "is_variable / is_nonvariable" begin
                Test.@test Common.is_variable(vf_fixed) === false
                Test.@test Common.is_nonvariable(vf_fixed) === true
                Test.@test Common.is_variable(vf_nonfixed) === true
                Test.@test Common.is_nonvariable(vf_nonfixed) === false
            end
        end

        # ====================================================================
        # UNIT TESTS - Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "Exported types" begin
                Test.@test isdefined(Systems, :VectorField)
            end
        end
    end
end

end # module

test_vector_field() = TestVectorField.test_vector_field()
