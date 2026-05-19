module TestAbstractTrait

import Test
import CTFlows.Common

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Test function
# ==============================================================================

function test_abstract_trait()
    Test.@testset "Abstract Trait Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "UNIT TESTS - Abstract Types" begin
            Test.@testset "AbstractTrait" begin
                Test.@testset "AbstractTrait is exported" begin
                    Test.@test isdefined(Common, :AbstractTrait)
                end

                Test.@testset "AbstractTrait is abstract" begin
                    Test.@test isabstracttype(Common.AbstractTrait)
                end
            end

            Test.@testset "AbstractModeTrait" begin
                Test.@testset "AbstractModeTrait is exported" begin
                    Test.@test isdefined(Common, :AbstractModeTrait)
                end

                Test.@testset "AbstractModeTrait is abstract" begin
                    Test.@test isabstracttype(Common.AbstractModeTrait)
                end

                Test.@testset "AbstractModeTrait subtypes AbstractTrait" begin
                    Test.@test Common.AbstractModeTrait <: Common.AbstractTrait
                end
            end

            Test.@testset "AbstractContentTrait" begin
                Test.@testset "AbstractContentTrait is exported" begin
                    Test.@test isdefined(Common, :AbstractContentTrait)
                end

                Test.@testset "AbstractContentTrait is abstract" begin
                    Test.@test isabstracttype(Common.AbstractContentTrait)
                end

                Test.@testset "AbstractContentTrait subtypes AbstractTrait" begin
                    Test.@test Common.AbstractContentTrait <: Common.AbstractTrait
                end
            end

            Test.@testset "AbstractMutabilityTrait" begin
                Test.@testset "AbstractMutabilityTrait is exported" begin
                    Test.@test isdefined(Common, :AbstractMutabilityTrait)
                end

                Test.@testset "AbstractMutabilityTrait is abstract" begin
                    Test.@test isabstracttype(Common.AbstractMutabilityTrait)
                end

                Test.@testset "AbstractMutabilityTrait subtypes AbstractTrait" begin
                    Test.@test Common.AbstractMutabilityTrait <: Common.AbstractTrait
                end
            end

            Test.@testset "AbstractADTrait" begin
                Test.@testset "AbstractADTrait is exported" begin
                    Test.@test isdefined(Common, :AbstractADTrait)
                end

                Test.@testset "AbstractADTrait is abstract" begin
                    Test.@test isabstracttype(Common.AbstractADTrait)
                end

                Test.@testset "AbstractADTrait subtypes AbstractTrait" begin
                    Test.@test Common.AbstractADTrait <: Common.AbstractTrait
                end
            end

            Test.@testset "AbstractCache" begin
                Test.@testset "AbstractCache is exported" begin
                    Test.@test isdefined(Common, :AbstractCache)
                end

                Test.@testset "AbstractCache is abstract" begin
                    Test.@test isabstracttype(Common.AbstractCache)
                end
            end
        end

        # ====================================================================
        # UNIT TESTS - Concrete Trait Types
        # ====================================================================

        Test.@testset "UNIT TESTS - Concrete Trait Types" begin
            Test.@testset "PointTrait" begin
                Test.@testset "PointTrait is exported" begin
                    Test.@test isdefined(Common, :PointTrait)
                end

                Test.@testset "PointTrait is concrete" begin
                    Test.@test !isabstracttype(Common.PointTrait)
                end

                Test.@testset "PointTrait instantiates" begin
                    pt = Common.PointTrait()
                    Test.@test pt isa Common.PointTrait
                end

                Test.@testset "PointTrait subtypes AbstractModeTrait" begin
                    Test.@test Common.PointTrait <: Common.AbstractModeTrait
                end
            end

            Test.@testset "TrajectoryTrait" begin
                Test.@testset "TrajectoryTrait is exported" begin
                    Test.@test isdefined(Common, :TrajectoryTrait)
                end

                Test.@testset "TrajectoryTrait is concrete" begin
                    Test.@test !isabstracttype(Common.TrajectoryTrait)
                end

                Test.@testset "TrajectoryTrait instantiates" begin
                    traj = Common.TrajectoryTrait()
                    Test.@test traj isa Common.TrajectoryTrait
                end

                Test.@testset "TrajectoryTrait subtypes AbstractModeTrait" begin
                    Test.@test Common.TrajectoryTrait <: Common.AbstractModeTrait
                end
            end

            Test.@testset "StateTrait" begin
                Test.@testset "StateTrait is exported" begin
                    Test.@test isdefined(Common, :StateTrait)
                end

                Test.@testset "StateTrait is concrete" begin
                    Test.@test !isabstracttype(Common.StateTrait)
                end

                Test.@testset "StateTrait instantiates" begin
                    st = Common.StateTrait()
                    Test.@test st isa Common.StateTrait
                end

                Test.@testset "StateTrait subtypes AbstractContentTrait" begin
                    Test.@test Common.StateTrait <: Common.AbstractContentTrait
                end
            end

            Test.@testset "HamiltonianTrait" begin
                Test.@testset "HamiltonianTrait is exported" begin
                    Test.@test isdefined(Common, :HamiltonianTrait)
                end

                Test.@testset "HamiltonianTrait is concrete" begin
                    Test.@test !isabstracttype(Common.HamiltonianTrait)
                end

                Test.@testset "HamiltonianTrait instantiates" begin
                    ham = Common.HamiltonianTrait()
                    Test.@test ham isa Common.HamiltonianTrait
                end

                Test.@testset "HamiltonianTrait subtypes AbstractContentTrait" begin
                    Test.@test Common.HamiltonianTrait <: Common.AbstractContentTrait
                end
            end

            Test.@testset "InPlace" begin
                Test.@testset "InPlace is exported" begin
                    Test.@test isdefined(Common, :InPlace)
                end

                Test.@testset "InPlace is concrete" begin
                    Test.@test !isabstracttype(Common.InPlace)
                end

                Test.@testset "InPlace instantiates" begin
                    ip = Common.InPlace()
                    Test.@test ip isa Common.InPlace
                end

                Test.@testset "InPlace subtypes AbstractMutabilityTrait" begin
                    Test.@test Common.InPlace <: Common.AbstractMutabilityTrait
                end
            end

            Test.@testset "OutOfPlace" begin
                Test.@testset "OutOfPlace is exported" begin
                    Test.@test isdefined(Common, :OutOfPlace)
                end

                Test.@testset "OutOfPlace is concrete" begin
                    Test.@test !isabstracttype(Common.OutOfPlace)
                end

                Test.@testset "OutOfPlace instantiates" begin
                    oop = Common.OutOfPlace()
                    Test.@test oop isa Common.OutOfPlace
                end

                Test.@testset "OutOfPlace subtypes AbstractMutabilityTrait" begin
                    Test.@test Common.OutOfPlace <: Common.AbstractMutabilityTrait
                end
            end

            Test.@testset "WithAD" begin
                Test.@testset "WithAD is exported" begin
                    Test.@test isdefined(Common, :WithAD)
                end

                Test.@testset "WithAD is concrete" begin
                    Test.@test !isabstracttype(Common.WithAD)
                end

                Test.@testset "WithAD instantiates" begin
                    with = Common.WithAD()
                    Test.@test with isa Common.WithAD
                end

                Test.@testset "WithAD subtypes AbstractADTrait" begin
                    Test.@test Common.WithAD <: Common.AbstractADTrait
                end
            end

            Test.@testset "WithoutAD" begin
                Test.@testset "WithoutAD is exported" begin
                    Test.@test isdefined(Common, :WithoutAD)
                end

                Test.@testset "WithoutAD is concrete" begin
                    Test.@test !isabstracttype(Common.WithoutAD)
                end

                Test.@testset "WithoutAD instantiates" begin
                    without = Common.WithoutAD()
                    Test.@test without isa Common.WithoutAD
                end

                Test.@testset "WithoutAD subtypes AbstractADTrait" begin
                    Test.@test Common.WithoutAD <: Common.AbstractADTrait
                end
            end
        end

        # ====================================================================
        # UNIT TESTS - Type Hierarchy
        # ====================================================================

        Test.@testset "UNIT TESTS - Type Hierarchy" begin
            Test.@testset "All concrete traits subtype AbstractTrait" begin
                Test.@test Common.PointTrait <: Common.AbstractTrait
                Test.@test Common.TrajectoryTrait <: Common.AbstractTrait
                Test.@test Common.StateTrait <: Common.AbstractTrait
                Test.@test Common.HamiltonianTrait <: Common.AbstractTrait
                Test.@test Common.InPlace <: Common.AbstractTrait
                Test.@test Common.OutOfPlace <: Common.AbstractTrait
                Test.@test Common.WithAD <: Common.AbstractTrait
                Test.@test Common.WithoutAD <: Common.AbstractTrait
            end

            Test.@testset "Mode traits are distinct from content traits" begin
                Test.@test !(Common.PointTrait <: Common.AbstractContentTrait)
                Test.@test !(Common.TrajectoryTrait <: Common.AbstractContentTrait)
                Test.@test !(Common.StateTrait <: Common.AbstractModeTrait)
                Test.@test !(Common.HamiltonianTrait <: Common.AbstractModeTrait)
            end
        end

        # ====================================================================
        # Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "Exported trait types" begin
                for sym in (:AbstractTrait, :AbstractModeTrait, :AbstractContentTrait, :AbstractMutabilityTrait, :AbstractADTrait,
                           :PointTrait, :TrajectoryTrait, :StateTrait, :HamiltonianTrait,
                           :InPlace, :OutOfPlace, :WithAD, :WithoutAD, :AbstractCache)
                    Test.@test isdefined(Common, sym)
                end
            end
        end
    end
end

end # module

test_abstract_trait() = TestAbstractTrait.test_abstract_trait()
