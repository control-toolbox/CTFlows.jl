module TestTraits

import Test
import CTBase.Exceptions
import CTFlows.Common

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for contract testing
# ==============================================================================

"""
Fake type for testing time-dependence trait pattern.
Implements both required methods: has_time_dependence_trait and time_dependence.
"""
struct FakeAutonomous end

Common.has_time_dependence_trait(::FakeAutonomous; kwargs...) = true
Common.time_dependence(::FakeAutonomous) = Common.Autonomous

"""
Fake type for testing time-dependence trait pattern with NonAutonomous.
"""
struct FakeNonAutonomous end

Common.has_time_dependence_trait(::FakeNonAutonomous) = true
Common.time_dependence(::FakeNonAutonomous) = Common.NonAutonomous

"""
Fake type for testing variable-dependence trait pattern.
Implements both required methods: has_variable_dependence_trait and variable_dependence.
"""
struct FakeFixed end

Common.has_variable_dependence_trait(::FakeFixed) = true
Common.variable_dependence(::FakeFixed) = Common.Fixed

"""
Fake type for testing variable-dependence trait pattern with NonFixed.
"""
struct FakeNonFixed end

Common.has_variable_dependence_trait(::FakeNonFixed) = true
Common.variable_dependence(::FakeNonFixed) = Common.NonFixed

# ==============================================================================
# Test function
# ==============================================================================

"""
Helper function to test that an error message contains the caller function name.

# Arguments
- `func`: The function to call.
- `obj`: The object to pass to the function.
- `expected_name`: The expected function name in the error message.
- `error_type`: The expected error type (default: Exceptions.IncorrectArgument).
"""
function test_error_contains_caller(func, obj, expected_name, error_type=Exceptions.IncorrectArgument)
    try
        func(obj)
        Test.@test false  # Should not reach here
    catch err
        Test.@test err isa error_type
        Test.@test occursin(expected_name, err.msg)
    end
end

function test_traits()
    Test.@testset "Trait Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Trait Types
        # ====================================================================

        Test.@testset "Trait Types" begin
            Test.@testset "TimeDependence abstract type" begin
                Test.@test isdefined(Common, :TimeDependence)
                Test.@test Common.Autonomous <: Common.TimeDependence
                Test.@test Common.NonAutonomous <: Common.TimeDependence
            end

            Test.@testset "VariableDependence abstract type" begin
                Test.@test isdefined(Common, :VariableDependence)
                Test.@test Common.Fixed <: Common.VariableDependence
                Test.@test Common.NonFixed <: Common.VariableDependence
            end

            Test.@testset "Concrete trait types" begin
                Test.@test Common.Autonomous() isa Common.Autonomous
                Test.@test Common.NonAutonomous() isa Common.NonAutonomous
                Test.@test Common.Fixed() isa Common.Fixed
                Test.@test Common.NonFixed() isa Common.NonFixed
            end
        end

        # ====================================================================
        # UNIT TESTS - Trait Fallback Methods
        # ====================================================================

        Test.@testset "Trait Fallback Methods" begin
            Test.@testset "has_time_dependence_trait throws IncorrectArgument" begin
                obj = "not a trait object"
                Test.@test_throws Exceptions.IncorrectArgument Common.has_time_dependence_trait(obj)
            end

            Test.@testset "time_dependence throws NotImplemented" begin
                obj = "not a trait object"
                Test.@test_throws Exceptions.NotImplemented Common.time_dependence(obj)
            end

            Test.@testset "has_variable_dependence_trait throws IncorrectArgument" begin
                obj = "not a trait object"
                Test.@test_throws Exceptions.IncorrectArgument Common.has_variable_dependence_trait(obj)
            end

            Test.@testset "variable_dependence throws NotImplemented" begin
                obj = "not a trait object"
                Test.@test_throws Exceptions.NotImplemented Common.variable_dependence(obj)
            end

            Test.@testset "_caller_function_name detects caller in error messages" begin
                obj = "not a trait object"

                # Test is_autonomous error contains function name
                test_error_contains_caller(Common.is_autonomous, obj, "is_autonomous")

                # Test is_nonautonomous error contains function name
                test_error_contains_caller(Common.is_nonautonomous, obj, "is_nonautonomous")

                # Test is_variable error contains function name
                test_error_contains_caller(Common.is_variable, obj, "is_variable")

                # Test is_nonvariable error contains function name
                test_error_contains_caller(Common.is_nonvariable, obj, "is_nonvariable")

                # Test has_variable error contains function name
                test_error_contains_caller(Common.has_variable, obj, "has_variable")
            end
        end

        # ====================================================================
        # UNIT TESTS - Time-Dependence Trait Pattern
        # ====================================================================

        Test.@testset "Time-Dependence Trait Pattern" begin
            Test.@testset "FakeAutonomous trait implementation" begin
                obj = FakeAutonomous()
                Test.@test Common.has_time_dependence_trait(obj) === true
                Test.@test Common.time_dependence(obj) === Common.Autonomous
                Test.@test Common.is_autonomous(obj) === true
                Test.@test Common.is_nonautonomous(obj) === false
            end

            Test.@testset "FakeNonAutonomous trait implementation" begin
                obj = FakeNonAutonomous()
                Test.@test Common.has_time_dependence_trait(obj) === true
                Test.@test Common.time_dependence(obj) === Common.NonAutonomous
                Test.@test Common.is_autonomous(obj) === false
                Test.@test Common.is_nonautonomous(obj) === true
            end

            Test.@testset "is_autonomous dispatches on trait value" begin
                Test.@test Common.is_autonomous(Common.Autonomous) === true
                Test.@test Common.is_autonomous(Common.NonAutonomous) === false
            end

            Test.@testset "is_nonautonomous dispatches on trait value" begin
                Test.@test Common.is_nonautonomous(Common.Autonomous) === false
                Test.@test Common.is_nonautonomous(Common.NonAutonomous) === true
            end
        end

        # ====================================================================
        # UNIT TESTS - Variable-Dependence Trait Pattern
        # ====================================================================

        Test.@testset "Variable-Dependence Trait Pattern" begin
            Test.@testset "FakeFixed trait implementation" begin
                obj = FakeFixed()
                Test.@test Common.has_variable_dependence_trait(obj) === true
                Test.@test Common.variable_dependence(obj) === Common.Fixed
                Test.@test Common.is_variable(obj) === false
                Test.@test Common.is_nonvariable(obj) === true
                Test.@test Common.has_variable(obj) === false
            end

            Test.@testset "FakeNonFixed trait implementation" begin
                obj = FakeNonFixed()
                Test.@test Common.has_variable_dependence_trait(obj) === true
                Test.@test Common.variable_dependence(obj) === Common.NonFixed
                Test.@test Common.is_variable(obj) === true
                Test.@test Common.is_nonvariable(obj) === false
                Test.@test Common.has_variable(obj) === true
            end

            Test.@testset "is_variable dispatches on trait value" begin
                Test.@test Common.is_variable(Common.Fixed) === false
                Test.@test Common.is_variable(Common.NonFixed) === true
            end

            Test.@testset "is_nonvariable dispatches on trait value" begin
                Test.@test Common.is_nonvariable(Common.Fixed) === true
                Test.@test Common.is_nonvariable(Common.NonFixed) === false
            end

            Test.@testset "has_variable alias for CTModels compatibility" begin
                Test.@test Common.has_variable(Common.Fixed) === false
                Test.@test Common.has_variable(Common.NonFixed) === true
            end
        end
    end
end

end # module

test_traits() = TestTraits.test_traits()
