module TestTraitsModule

import Test
import CTFlows.Traits

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_traits_module()
    Test.@testset "Traits Module Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Module Structure
        # ====================================================================

        Test.@testset "UNIT TESTS - Module Structure" begin
            Test.@testset "Traits module is defined" begin
                Test.@test isdefined(Traits, :Traits)
            end

            Test.@testset "Traits module has expected imports" begin
                Test.@test isdefined(Traits, :Exceptions)
                Test.@test isdefined(Traits, :OCP)
            end
        end

        # ====================================================================
        # Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "Exported abstract types" begin
                for sym in (:AbstractTrait, :AbstractModeTrait, :AbstractContentTrait,
                           :AbstractMutabilityTrait, :AbstractADTrait,
                           :AbstractVariableCostateCapability)
                    Test.@test isdefined(Traits, sym)
                end
            end

            Test.@testset "Exported concrete trait types" begin
                for sym in (:PointTrait, :TrajectoryTrait, :StateTrait, :HamiltonianTrait,
                           :AugmentedHamiltonianTrait, :InPlace, :OutOfPlace, :WithAD,
                           :WithoutAD, :SupportsVariableCostate, :NoVariableCostate,
                           :VariableDependence, :Fixed, :NonFixed)
                    Test.@test isdefined(Traits, sym)
                end
            end

            Test.@testset "Exported trait functions" begin
                for sym in (:ad_trait, :variable_costate_trait, :is_inplace, :is_outofplace,
                           :has_time_dependence_trait, :time_dependence, :has_mutability_trait,
                           :mutability_trait, :has_variable_dependence_trait, :variable_dependence)
                    Test.@test isdefined(Traits, sym)
                end
            end
        end
    end
end

end # module

test_traits_module() = TestTraitsModule.test_traits_module()
