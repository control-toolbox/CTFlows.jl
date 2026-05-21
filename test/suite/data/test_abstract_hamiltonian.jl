module TestAbstractHamiltonian

import Test
import CTFlows.Data
import CTFlows.Common

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Fake type for contract testing (defined at module top-level per testing-creation.md)
# ==============================================================================

struct FakeHamiltonian{TD, VD} <: Data.AbstractHamiltonian{TD, VD} end

# ==============================================================================
# Test function
# ==============================================================================

function test_abstract_hamiltonian()
    Test.@testset "AbstractHamiltonian Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Type Definition
        # ====================================================================

        Test.@testset "Abstract Type Definition" begin
            Test.@testset "AbstractHamiltonian exists" begin
                Test.@test isdefined(Data, :AbstractHamiltonian)
            end

            Test.@testset "AbstractHamiltonian is exported" begin
                Test.@test isdefined(Data, :AbstractHamiltonian)
            end

            Test.@testset "FakeHamiltonian subtypes AbstractHamiltonian" begin
                fake = FakeHamiltonian{Common.Autonomous, Common.Fixed}()
                Test.@test fake isa Data.AbstractHamiltonian
            end
        end

        # ====================================================================
        # UNIT TESTS - Trait Accessors on Abstract Type
        # ====================================================================

        Test.@testset "Trait Accessors on Abstract Type" begin
            Test.@testset "has_time_dependence_trait returns true" begin
                fake = FakeHamiltonian{Common.Autonomous, Common.Fixed}()
                Test.@test Common.has_time_dependence_trait(fake) === true
                Test.@test Base.invokelatest(Common.has_time_dependence_trait, fake) === true
            end

            Test.@testset "has_variable_dependence_trait returns true" begin
                fake = FakeHamiltonian{Common.Autonomous, Common.Fixed}()
                Test.@test Common.has_variable_dependence_trait(fake) === true
                Test.@test Base.invokelatest(Common.has_variable_dependence_trait, fake) === true
            end

            Test.@testset "time_dependence returns correct trait" begin
                fake_aut = FakeHamiltonian{Common.Autonomous, Common.Fixed}()
                fake_nonaut = FakeHamiltonian{Common.NonAutonomous, Common.Fixed}()
                Test.@test Common.time_dependence(fake_aut) === Common.Autonomous
                Test.@test Common.time_dependence(fake_nonaut) === Common.NonAutonomous
            end

            Test.@testset "variable_dependence returns correct trait" begin
                fake_fixed = FakeHamiltonian{Common.Autonomous, Common.Fixed}()
                fake_nonfixed = FakeHamiltonian{Common.Autonomous, Common.NonFixed}()
                Test.@test Common.variable_dependence(fake_fixed) === Common.Fixed
                Test.@test Common.variable_dependence(fake_nonfixed) === Common.NonFixed
            end

            Test.@testset "explicit dispatch on AbstractHamiltonian methods" begin
                fake = FakeHamiltonian{Common.NonAutonomous, Common.NonFixed}()

                Test.@test invoke(
                    Common.has_time_dependence_trait,
                    Tuple{Data.AbstractHamiltonian},
                    fake,
                ) === true

                Test.@test invoke(
                    Common.has_variable_dependence_trait,
                    Tuple{Data.AbstractHamiltonian},
                    fake,
                ) === true

                Test.@test invoke(
                    Common.time_dependence,
                    Tuple{Data.AbstractHamiltonian{Common.NonAutonomous, Common.NonFixed}},
                    fake,
                ) === Common.NonAutonomous

                Test.@test invoke(
                    Common.variable_dependence,
                    Tuple{Data.AbstractHamiltonian{Common.NonAutonomous, Common.NonFixed}},
                    fake,
                ) === Common.NonFixed
            end
        end

        # ====================================================================
        # UNIT TESTS - Liskov Substitution
        # ====================================================================

        Test.@testset "Liskov Substitution" begin
            Test.@testset "Hamiltonian is an AbstractHamiltonian" begin
                h = Data.Hamiltonian((x, p) -> x + p; is_autonomous=true, is_variable=false)
                Test.@test h isa Data.AbstractHamiltonian
            end
        end

        # ====================================================================
        # UNIT TESTS - Type Stability
        # ====================================================================

        Test.@testset "Type Stability" begin
            Test.@testset "Trait accessors are type-stable" begin
                fake = FakeHamiltonian{Common.Autonomous, Common.Fixed}()
                Test.@test Test.@inferred(Common.has_time_dependence_trait(fake)) === true
                Test.@test Test.@inferred(Common.has_variable_dependence_trait(fake)) === true
                Test.@test Test.@inferred(Common.time_dependence(fake)) === Common.Autonomous
                Test.@test Test.@inferred(Common.variable_dependence(fake)) === Common.Fixed
            end
        end

        # ====================================================================
        # UNIT TESTS - Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "Exported types" begin
                Test.@test isdefined(Data, :AbstractHamiltonian)
            end
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_abstract_hamiltonian() = TestAbstractHamiltonian.test_abstract_hamiltonian()
