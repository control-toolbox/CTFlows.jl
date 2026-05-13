module TestHamiltonianVectorField

import Test
import CTFlows.Data: Data
import CTFlows.Common: Common
import CTBase.Exceptions

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# TOP-LEVEL: Fake function with multiple methods for testing
_multi_method_hvf(x::Int, p) = (x, -p)
_multi_method_hvf(x::Float64, p) = (x, -p)
_multi_method_hvf(x::AbstractVector, p) = (x, -p)

function test_hamiltonian_vector_field()
    Test.@testset "Hamiltonian Vector Field Tests" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # ====================================================================
        # UNIT TESTS - Construction
        # ====================================================================
        
        Test.@testset "Construction" begin
            # Autonomous, Fixed
            hvf_autonomous_fixed = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
            Test.@test hvf_autonomous_fixed isa Data.HamiltonianVectorField
            Test.@test Common.time_dependence(hvf_autonomous_fixed) == Common.Autonomous
            Test.@test Common.variable_dependence(hvf_autonomous_fixed) == Common.Fixed
            
            # NonAutonomous, Fixed
            hvf_nonautonomous_fixed = Data.HamiltonianVectorField((t, x, p) -> (x, -p); is_autonomous=false, is_variable=false)
            Test.@test hvf_nonautonomous_fixed isa Data.HamiltonianVectorField
            Test.@test Common.time_dependence(hvf_nonautonomous_fixed) == Common.NonAutonomous
            Test.@test Common.variable_dependence(hvf_nonautonomous_fixed) == Common.Fixed
            
            # Autonomous, NonFixed
            hvf_autonomous_nonfixed = Data.HamiltonianVectorField((x, p, v) -> (x .* v, -p); is_autonomous=true, is_variable=true)
            Test.@test hvf_autonomous_nonfixed isa Data.HamiltonianVectorField
            Test.@test Common.time_dependence(hvf_autonomous_nonfixed) == Common.Autonomous
            Test.@test Common.variable_dependence(hvf_autonomous_nonfixed) == Common.NonFixed
            
            # NonAutonomous, NonFixed
            hvf_nonautonomous_nonfixed = Data.HamiltonianVectorField((t, x, p, v) -> (x .* v, -p); is_autonomous=false, is_variable=true)
            Test.@test hvf_nonautonomous_nonfixed isa Data.HamiltonianVectorField
            Test.@test Common.time_dependence(hvf_nonautonomous_nonfixed) == Common.NonAutonomous
            Test.@test Common.variable_dependence(hvf_nonautonomous_nonfixed) == Common.NonFixed
        end
        
        # ====================================================================
        # UNIT TESTS - Natural signatures
        # ====================================================================
        
        Test.@testset "Natural Signatures" begin
            # (x, p) for Autonomous, Fixed
            hvf1 = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
            dx, dp = hvf1([1.0, 2.0], [3.0, 4.0])
            Test.@test dx == [1.0, 2.0]
            Test.@test dp == [-3.0, -4.0]
            
            # (t, x, p) for NonAutonomous, Fixed
            hvf2 = Data.HamiltonianVectorField((t, x, p) -> (t .* x, -p); is_autonomous=false, is_variable=false)
            dx, dp = hvf2(2.0, [1.0, 2.0], [3.0, 4.0])
            Test.@test dx == [2.0, 4.0]
            Test.@test dp == [-3.0, -4.0]
            
            # (x, p, v) for Autonomous, NonFixed
            hvf3 = Data.HamiltonianVectorField((x, p, v) -> (x .* v, -p); is_autonomous=true, is_variable=true)
            dx, dp = hvf3([1.0, 2.0], [3.0, 4.0], 2.0)
            Test.@test dx == [2.0, 4.0]
            Test.@test dp == [-3.0, -4.0]
            
            # (t, x, p, v) for NonAutonomous, NonFixed
            hvf4 = Data.HamiltonianVectorField((t, x, p, v) -> (t .* x .* v, -p); is_autonomous=false, is_variable=true)
            dx, dp = hvf4(2.0, [1.0, 2.0], [3.0, 4.0], 2.0)
            Test.@test dx == [4.0, 8.0]
            Test.@test dp == [-3.0, -4.0]
        end
        
        # ====================================================================
        # UNIT TESTS - Uniform signature
        # ====================================================================
        
        Test.@testset "Uniform Signature" begin
            # All combinations should work with (t, x, p, v)
            hvf_autonomous_fixed = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
            dx, dp = hvf_autonomous_fixed(0.0, [1.0, 2.0], [3.0, 4.0], nothing)
            Test.@test dx == [1.0, 2.0]
            Test.@test dp == [-3.0, -4.0]
            
            hvf_nonautonomous_fixed = Data.HamiltonianVectorField((t, x, p) -> (t .* x, -p); is_autonomous=false, is_variable=false)
            dx, dp = hvf_nonautonomous_fixed(2.0, [1.0, 2.0], [3.0, 4.0], nothing)
            Test.@test dx == [2.0, 4.0]
            Test.@test dp == [-3.0, -4.0]
            
            hvf_autonomous_nonfixed = Data.HamiltonianVectorField((x, p, v) -> (x .* v, -p); is_autonomous=true, is_variable=true)
            dx, dp = hvf_autonomous_nonfixed(0.0, [1.0, 2.0], [3.0, 4.0], 2.0)
            Test.@test dx == [2.0, 4.0]
            Test.@test dp == [-3.0, -4.0]
        end
        
        # ====================================================================
        # UNIT TESTS - Trait accessors
        # ====================================================================
        
        Test.@testset "Trait Accessors" begin
            hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
            Test.@test Common.has_time_dependence_trait(hvf) == true
            Test.@test Common.has_variable_dependence_trait(hvf) == true
            Test.@test Common.time_dependence(hvf) == Common.Autonomous
            Test.@test Common.variable_dependence(hvf) == Common.Fixed
        end
        
        # ====================================================================
        # UNIT TESTS - Subtyping
        # ====================================================================

        Test.@testset "Subtyping" begin
            Test.@testset "HamiltonianVectorField is an AbstractVectorField" begin
                hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
                Test.@test hvf isa Data.AbstractVectorField
            end
        end

        # ====================================================================
        # UNIT TESTS - Base.show
        # ====================================================================

        Test.@testset "Base.show" begin
            hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
            # Just check that show doesn't throw
            Test.@test_nowarn sprint(show, hvf)
        end

        # ====================================================================
        # UNIT TESTS - Explicit is_inplace parameter
        # ====================================================================

        Test.@testset "Explicit is_inplace parameter" begin
            Test.@testset "is_inplace=true creates InPlace HamiltonianVectorField" begin
                # Define an out-of-place function but force InPlace
                f(x, p) = (x, -p)
                hvf = Data.HamiltonianVectorField(f; is_inplace=true)
                Test.@test Common.mutability_trait(hvf) === Common.InPlace
            end

            Test.@testset "is_inplace=false creates OutOfPlace HamiltonianVectorField" begin
                # Define an in-place function but force OutOfPlace
                f(x, p) = (x, -p)
                hvf = Data.HamiltonianVectorField(f; is_inplace=false)
                Test.@test Common.mutability_trait(hvf) === Common.OutOfPlace
            end
        end

        # ====================================================================
        # UNIT TESTS - PreconditionError for multiple methods
        # ====================================================================

        Test.@testset "PreconditionError for multiple methods" begin
            Test.@testset "Throws PreconditionError when is_inplace is not specified" begin
                Test.@test_throws Exceptions.PreconditionError Data.HamiltonianVectorField(_multi_method_hvf)
            end

            Test.@testset "No error when is_inplace is explicitly specified" begin
                hvf = Data.HamiltonianVectorField(_multi_method_hvf; is_inplace=false)
                Test.@test Common.mutability_trait(hvf) === Common.OutOfPlace
            end
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_hamiltonian_vector_field() = TestHamiltonianVectorField.test_hamiltonian_vector_field()
