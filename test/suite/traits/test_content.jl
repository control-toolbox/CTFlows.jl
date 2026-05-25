module TestContent

import Test
import CTFlows.Traits

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_content()
    Test.@testset "Content Trait Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "UNIT TESTS - Abstract Types" begin
            Test.@testset "AbstractContentTrait" begin
                Test.@testset "AbstractContentTrait is exported" begin
                    Test.@test isdefined(Traits, :AbstractContentTrait)
                end

                Test.@testset "AbstractContentTrait is abstract" begin
                    Test.@test isabstracttype(Traits.AbstractContentTrait)
                end

                Test.@testset "AbstractContentTrait subtypes AbstractTrait" begin
                    Test.@test Traits.AbstractContentTrait <: Traits.AbstractTrait
                end
            end
        end

        # ====================================================================
        # UNIT TESTS - Concrete Trait Types
        # ====================================================================

        Test.@testset "UNIT TESTS - Concrete Trait Types" begin
            Test.@testset "StateTrait" begin
                Test.@testset "StateTrait is exported" begin
                    Test.@test isdefined(Traits, :StateTrait)
                end

                Test.@testset "StateTrait is concrete" begin
                    Test.@test !isabstracttype(Traits.StateTrait)
                end

                Test.@testset "StateTrait instantiates" begin
                    st = Traits.StateTrait()
                    Test.@test st isa Traits.StateTrait
                end

                Test.@testset "StateTrait subtypes AbstractContentTrait" begin
                    Test.@test Traits.StateTrait <: Traits.AbstractContentTrait
                end
            end

            Test.@testset "HamiltonianTrait" begin
                Test.@testset "HamiltonianTrait is exported" begin
                    Test.@test isdefined(Traits, :HamiltonianTrait)
                end

                Test.@testset "HamiltonianTrait is concrete" begin
                    Test.@test !isabstracttype(Traits.HamiltonianTrait)
                end

                Test.@testset "HamiltonianTrait instantiates" begin
                    ham = Traits.HamiltonianTrait()
                    Test.@test ham isa Traits.HamiltonianTrait
                end

                Test.@testset "HamiltonianTrait subtypes AbstractContentTrait" begin
                    Test.@test Traits.HamiltonianTrait <: Traits.AbstractContentTrait
                end
            end

            Test.@testset "AugmentedHamiltonianTrait" begin
                Test.@testset "AugmentedHamiltonianTrait is exported" begin
                    Test.@test isdefined(Traits, :AugmentedHamiltonianTrait)
                end

                Test.@testset "AugmentedHamiltonianTrait is concrete" begin
                    Test.@test !isabstracttype(Traits.AugmentedHamiltonianTrait)
                end

                Test.@testset "AugmentedHamiltonianTrait instantiates" begin
                    aug = Traits.AugmentedHamiltonianTrait()
                    Test.@test aug isa Traits.AugmentedHamiltonianTrait
                end

                Test.@testset "AugmentedHamiltonianTrait subtypes AbstractContentTrait" begin
                    Test.@test Traits.AugmentedHamiltonianTrait <: Traits.AbstractContentTrait
                end
            end
        end

        # ====================================================================
        # UNIT TESTS - Type Hierarchy
        # ====================================================================

        Test.@testset "UNIT TESTS - Type Hierarchy" begin
            Test.@testset "All content traits subtype AbstractTrait" begin
                Test.@test Traits.StateTrait <: Traits.AbstractTrait
                Test.@test Traits.HamiltonianTrait <: Traits.AbstractTrait
                Test.@test Traits.AugmentedHamiltonianTrait <: Traits.AbstractTrait
            end

            Test.@testset "Content traits are distinct from mode traits" begin
                Test.@test !(Traits.StateTrait <: Traits.AbstractModeTrait)
                Test.@test !(Traits.HamiltonianTrait <: Traits.AbstractModeTrait)
                Test.@test !(Traits.AugmentedHamiltonianTrait <: Traits.AbstractModeTrait)
            end
        end

        # ====================================================================
        # Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "Exported content trait types" begin
                for sym in (:AbstractContentTrait, :StateTrait, :HamiltonianTrait, :AugmentedHamiltonianTrait)
                    Test.@test isdefined(Traits, sym)
                end
            end
        end
    end
end

end # module

test_content() = TestContent.test_content()
