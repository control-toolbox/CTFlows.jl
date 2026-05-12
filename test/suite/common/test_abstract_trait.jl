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
                for sym in (:AbstractTrait, :AbstractModeTrait, :AbstractContentTrait,
                           :PointTrait, :TrajectoryTrait, :StateTrait, :HamiltonianTrait)
                    Test.@test isdefined(Common, sym)
                end
            end
        end
    end
end

end # module

test_abstract_trait() = TestAbstractTrait.test_abstract_trait()
