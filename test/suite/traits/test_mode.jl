module TestMode

import Test
import CTFlows.Traits

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_mode()
    Test.@testset "Mode Trait Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "UNIT TESTS - Abstract Types" begin
            Test.@testset "AbstractModeTrait" begin
                Test.@testset "AbstractModeTrait is exported" begin
                    Test.@test isdefined(Traits, :AbstractModeTrait)
                end

                Test.@testset "AbstractModeTrait is abstract" begin
                    Test.@test isabstracttype(Traits.AbstractModeTrait)
                end

                Test.@testset "AbstractModeTrait subtypes AbstractTrait" begin
                    Test.@test Traits.AbstractModeTrait <: Traits.AbstractTrait
                end
            end
        end

        # ====================================================================
        # UNIT TESTS - Concrete Trait Types
        # ====================================================================

        Test.@testset "UNIT TESTS - Concrete Trait Types" begin
            Test.@testset "PointTrait" begin
                Test.@testset "PointTrait is exported" begin
                    Test.@test isdefined(Traits, :PointTrait)
                end

                Test.@testset "PointTrait is concrete" begin
                    Test.@test !isabstracttype(Traits.PointTrait)
                end

                Test.@testset "PointTrait instantiates" begin
                    pt = Traits.PointTrait()
                    Test.@test pt isa Traits.PointTrait
                end

                Test.@testset "PointTrait subtypes AbstractModeTrait" begin
                    Test.@test Traits.PointTrait <: Traits.AbstractModeTrait
                end
            end

            Test.@testset "TrajectoryTrait" begin
                Test.@testset "TrajectoryTrait is exported" begin
                    Test.@test isdefined(Traits, :TrajectoryTrait)
                end

                Test.@testset "TrajectoryTrait is concrete" begin
                    Test.@test !isabstracttype(Traits.TrajectoryTrait)
                end

                Test.@testset "TrajectoryTrait instantiates" begin
                    traj = Traits.TrajectoryTrait()
                    Test.@test traj isa Traits.TrajectoryTrait
                end

                Test.@testset "TrajectoryTrait subtypes AbstractModeTrait" begin
                    Test.@test Traits.TrajectoryTrait <: Traits.AbstractModeTrait
                end
            end
        end

        # ====================================================================
        # UNIT TESTS - Type Hierarchy
        # ====================================================================

        Test.@testset "UNIT TESTS - Type Hierarchy" begin
            Test.@testset "All mode traits subtype AbstractTrait" begin
                Test.@test Traits.PointTrait <: Traits.AbstractTrait
                Test.@test Traits.TrajectoryTrait <: Traits.AbstractTrait
            end
        end

        # ====================================================================
        # Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "Exported mode trait types" begin
                for sym in (:AbstractModeTrait, :PointTrait, :TrajectoryTrait)
                    Test.@test isdefined(Traits, sym)
                end
            end
        end
    end
end

end # module

test_mode() = TestMode.test_mode()
