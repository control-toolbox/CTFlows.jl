module TestAbstractVectorField

import Test
import CTFlows.Data
import CTFlows.Common

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Fake type for contract testing (defined at module top-level per testing-creation.md)
# ==============================================================================

struct FakeVectorField{TD, VD, MD} <: Data.AbstractVectorField{TD, VD, MD} end

# ==============================================================================
# Test function
# ==============================================================================

function test_abstract_vector_field()
    Test.@testset "AbstractVectorField Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Type Definition
        # ====================================================================

        Test.@testset "Abstract Type Definition" begin
            Test.@testset "AbstractVectorField exists" begin
                Test.@test isdefined(Data, :AbstractVectorField)
            end

            Test.@testset "AbstractVectorField is exported" begin
                Test.@test isdefined(Data, :AbstractVectorField)
            end

            Test.@testset "FakeVectorField subtypes AbstractVectorField" begin
                fake = FakeVectorField{Common.Autonomous, Common.Fixed, Common.OutOfPlace}()
                Test.@test fake isa Data.AbstractVectorField
            end
        end

        # ====================================================================
        # UNIT TESTS - Trait Accessors on Abstract Type
        # ====================================================================

        Test.@testset "Trait Accessors on Abstract Type" begin
            Test.@testset "has_time_dependence_trait returns true" begin
                fake = FakeVectorField{Common.Autonomous, Common.Fixed, Common.OutOfPlace}()
                Test.@test Common.has_time_dependence_trait(fake) === true
                Test.@test Base.invokelatest(Common.has_time_dependence_trait, fake) === true
            end

            Test.@testset "has_variable_dependence_trait returns true" begin
                fake = FakeVectorField{Common.Autonomous, Common.Fixed, Common.OutOfPlace}()
                Test.@test Common.has_variable_dependence_trait(fake) === true
                Test.@test Base.invokelatest(Common.has_variable_dependence_trait, fake) === true
            end

            Test.@testset "has_mutability_trait returns true" begin
                fake = FakeVectorField{Common.Autonomous, Common.Fixed, Common.OutOfPlace}()
                Test.@test Common.has_mutability_trait(fake) === true
                Test.@test Base.invokelatest(Common.has_mutability_trait, fake) === true
            end

            Test.@testset "time_dependence returns correct trait" begin
                fake_aut = FakeVectorField{Common.Autonomous, Common.Fixed, Common.OutOfPlace}()
                fake_nonaut = FakeVectorField{Common.NonAutonomous, Common.Fixed, Common.OutOfPlace}()
                Test.@test Common.time_dependence(fake_aut) === Common.Autonomous
                Test.@test Common.time_dependence(fake_nonaut) === Common.NonAutonomous
            end

            Test.@testset "variable_dependence returns correct trait" begin
                fake_fixed = FakeVectorField{Common.Autonomous, Common.Fixed, Common.OutOfPlace}()
                fake_nonfixed = FakeVectorField{Common.Autonomous, Common.NonFixed, Common.OutOfPlace}()
                Test.@test Common.variable_dependence(fake_fixed) === Common.Fixed
                Test.@test Common.variable_dependence(fake_nonfixed) === Common.NonFixed
            end

            Test.@testset "mutability_trait returns correct trait" begin
                fake_oop = FakeVectorField{Common.Autonomous, Common.Fixed, Common.OutOfPlace}()
                fake_ip = FakeVectorField{Common.Autonomous, Common.Fixed, Common.InPlace}()
                Test.@test Common.mutability_trait(fake_oop) === Common.OutOfPlace
                Test.@test Common.mutability_trait(fake_ip) === Common.InPlace
            end

            Test.@testset "explicit dispatch on AbstractVectorField methods" begin
                fake = FakeVectorField{Common.NonAutonomous, Common.NonFixed, Common.InPlace}()

                Test.@test invoke(
                    Common.has_time_dependence_trait,
                    Tuple{Data.AbstractVectorField},
                    fake,
                ) === true

                Test.@test invoke(
                    Common.has_variable_dependence_trait,
                    Tuple{Data.AbstractVectorField},
                    fake,
                ) === true

                Test.@test invoke(
                    Common.has_mutability_trait,
                    Tuple{Data.AbstractVectorField},
                    fake,
                ) === true

                Test.@test invoke(
                    Common.time_dependence,
                    Tuple{Data.AbstractVectorField{Common.NonAutonomous, Common.NonFixed, Common.InPlace}},
                    fake,
                ) === Common.NonAutonomous

                Test.@test invoke(
                    Common.variable_dependence,
                    Tuple{Data.AbstractVectorField{Common.NonAutonomous, Common.NonFixed, Common.InPlace}},
                    fake,
                ) === Common.NonFixed

                Test.@test invoke(
                    Common.mutability_trait,
                    Tuple{Data.AbstractVectorField{Common.NonAutonomous, Common.NonFixed, Common.InPlace}},
                    fake,
                ) === Common.InPlace
            end
        end

        # ====================================================================
        # UNIT TESTS - Liskov Substitution
        # ====================================================================

        Test.@testset "Liskov Substitution" begin
            Test.@testset "VectorField is an AbstractVectorField" begin
                vf = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                Test.@test vf isa Data.AbstractVectorField
            end

            Test.@testset "HamiltonianVectorField is an AbstractVectorField" begin
                hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
                Test.@test hvf isa Data.AbstractVectorField
            end
        end

        # ====================================================================
        # UNIT TESTS - Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "Exported types" begin
                Test.@test isdefined(Data, :AbstractVectorField)
            end
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_abstract_vector_field() = TestAbstractVectorField.test_abstract_vector_field()
