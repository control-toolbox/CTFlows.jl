module TestVectorField

import Test
import CTFlows.Data
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
            vf = Data.VectorField(x -> x; is_autonomous=true, is_variable=false)
            Test.@test vf isa Data.VectorField
        end

        # ====================================================================
        # UNIT TESTS - Construction
        # ====================================================================

        Test.@testset "Construction" begin
            Test.@testset "keyword constructor with defaults" begin
                vf = Data.VectorField(x -> x)
                Test.@test vf isa Data.VectorField
                Test.@test Common.time_dependence(vf) === Common.Autonomous
                Test.@test Common.variable_dependence(vf) === Common.Fixed
            end

            Test.@testset "keyword constructor with explicit flags" begin
                vf_autonomous = Data.VectorField(x -> x; is_autonomous=true, is_variable=false)
                Test.@test Common.time_dependence(vf_autonomous) === Common.Autonomous
                Test.@test Common.variable_dependence(vf_autonomous) === Common.Fixed

                vf_nonautonomous = Data.VectorField((t, x) -> t .* x; is_autonomous=false, is_variable=false)
                Test.@test Common.time_dependence(vf_nonautonomous) === Common.NonAutonomous
                Test.@test Common.variable_dependence(vf_nonautonomous) === Common.Fixed

                vf_nonfixed = Data.VectorField((x, v) -> x .+ v; is_autonomous=true, is_variable=true)
                Test.@test Common.time_dependence(vf_nonfixed) === Common.Autonomous
                Test.@test Common.variable_dependence(vf_nonfixed) === Common.NonFixed

                vf_full = Data.VectorField((t, x, v) -> t .* x .+ v; is_autonomous=false, is_variable=true)
                Test.@test Common.time_dependence(vf_full) === Common.NonAutonomous
                Test.@test Common.variable_dependence(vf_full) === Common.NonFixed
            end
        end

        # ====================================================================
        # UNIT TESTS - Trait Methods
        # ====================================================================

        Test.@testset "Trait Methods" begin
            vf_aut = Data.VectorField(x -> x; is_autonomous=true, is_variable=false)
            vf_nonaut = Data.VectorField((t, x) -> t .* x; is_autonomous=false, is_variable=false)
            vf_fixed = Data.VectorField(x -> x; is_autonomous=true, is_variable=false)
            vf_nonfixed = Data.VectorField((x, v) -> x .+ v; is_autonomous=true, is_variable=true)

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
                vf = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                
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
                vf = Data.VectorField((t, x) -> t .* x; is_autonomous=false, is_variable=false)
                
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
                vf = Data.VectorField((x, v) -> x .+ v; is_autonomous=true, is_variable=true)
                
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
                vf = Data.VectorField((t, x, v) -> t .* x .+ v; is_autonomous=false, is_variable=true)
                
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
                vf = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                
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
                vf = Data.VectorField((t, x) -> t .* x; is_autonomous=false, is_variable=false)
                
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
                vf = Data.VectorField((x, v) -> x .+ v; is_autonomous=true, is_variable=true)
                
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
            vf_aut = Data.VectorField(x -> x; is_autonomous=true, is_variable=false)
            vf_nonaut = Data.VectorField((t, x) -> t .* x; is_autonomous=false, is_variable=false)
            vf_fixed = Data.VectorField(x -> x; is_autonomous=true, is_variable=false)
            vf_nonfixed = Data.VectorField((x, v) -> x .+ v; is_autonomous=true, is_variable=true)

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
        # UNIT TESTS - Show Methods
        # ====================================================================

        Test.@testset "Show Methods" begin
            vf = Data.VectorField(x -> x; is_autonomous=true, is_variable=false)
            
            Test.@testset "Base.show (compact)" begin
                io = IOBuffer()
                show(io, vf)
                str = String(take!(io))
                Test.@test occursin("VectorField", str)
                Test.@test occursin("time_dependence: Autonomous", str)
                Test.@test occursin("variable_dependence: Fixed", str)
                Test.@test occursin("function:", str)
            end
            
            Test.@testset "Base.show (text/plain)" begin
                io = IOBuffer()
                show(io, MIME("text/plain"), vf)
                str = String(take!(io))
                Test.@test occursin("VectorField", str)
                Test.@test occursin("time_dependence: Autonomous", str)
                Test.@test occursin("variable_dependence: Fixed", str)
            end
        end

        # ====================================================================
        # UNIT TESTS - Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "Exported types" begin
                Test.@test isdefined(Data, :VectorField)
            end
        end
    end
end

end # module

test_vector_field() = TestVectorField.test_vector_field()
