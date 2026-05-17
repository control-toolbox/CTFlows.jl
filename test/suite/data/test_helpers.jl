module TestHelpers

import Test
import CTFlows.Data
import CTFlows.Common

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Test function
# ==============================================================================

function test_helpers()
    Test.@testset "Helpers Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Label Helpers
        # ====================================================================

        Test.@testset "Label Helpers" begin
            Test.@testset "_td_label" begin
                Test.@test Data._td_label(Common.Autonomous) == "autonomous"
                Test.@test Data._td_label(Common.NonAutonomous) == "non-autonomous"
            end

            Test.@testset "_vd_label" begin
                Test.@test Data._vd_label(Common.Fixed) == "fixed (no variable)"
                Test.@test Data._vd_label(Common.NonFixed) == "variable"
            end

            Test.@testset "_md_label" begin
                Test.@test Data._md_label(Common.OutOfPlace) == "out-of-place"
                Test.@test Data._md_label(Common.InPlace) == "in-place"
            end
        end

        # ====================================================================
        # UNIT TESTS - VectorField Signature Helpers
        # ====================================================================

        Test.@testset "VectorField Signature Helpers" begin
            Test.@testset "_natural_sig_vf - OutOfPlace" begin
                Test.@test Data._natural_sig_vf(Common.Autonomous, Common.Fixed, Common.OutOfPlace) == "f(x)"
                Test.@test Data._natural_sig_vf(Common.NonAutonomous, Common.Fixed, Common.OutOfPlace) == "f(t, x)"
                Test.@test Data._natural_sig_vf(Common.Autonomous, Common.NonFixed, Common.OutOfPlace) == "f(x, v)"
                Test.@test Data._natural_sig_vf(Common.NonAutonomous, Common.NonFixed, Common.OutOfPlace) == "f(t, x, v)"
            end

            Test.@testset "_natural_sig_vf - InPlace" begin
                Test.@test Data._natural_sig_vf(Common.Autonomous, Common.Fixed, Common.InPlace) == "f(dx, x)"
                Test.@test Data._natural_sig_vf(Common.NonAutonomous, Common.Fixed, Common.InPlace) == "f(dx, t, x)"
                Test.@test Data._natural_sig_vf(Common.Autonomous, Common.NonFixed, Common.InPlace) == "f(dx, x, v)"
                Test.@test Data._natural_sig_vf(Common.NonAutonomous, Common.NonFixed, Common.InPlace) == "f(dx, t, x, v)"
            end

            Test.@testset "_uniform_sig_vf" begin
                Test.@test Data._uniform_sig_vf(Common.OutOfPlace) == "f(t, x, v)"
                Test.@test Data._uniform_sig_vf(Common.InPlace) == "f(dx, t, x, v)"
            end
        end

        # ====================================================================
        # UNIT TESTS - HamiltonianVectorField Signature Helpers
        # ====================================================================

        Test.@testset "HamiltonianVectorField Signature Helpers" begin
            Test.@testset "_natural_sig_hvf - OutOfPlace" begin
                Test.@test Data._natural_sig_hvf(Common.Autonomous, Common.Fixed, Common.OutOfPlace) == "f(x, p)"
                Test.@test Data._natural_sig_hvf(Common.NonAutonomous, Common.Fixed, Common.OutOfPlace) == "f(t, x, p)"
                Test.@test Data._natural_sig_hvf(Common.Autonomous, Common.NonFixed, Common.OutOfPlace) == "f(x, p, v)"
                Test.@test Data._natural_sig_hvf(Common.NonAutonomous, Common.NonFixed, Common.OutOfPlace) == "f(t, x, p, v)"
            end

            Test.@testset "_natural_sig_hvf - InPlace" begin
                Test.@test Data._natural_sig_hvf(Common.Autonomous, Common.Fixed, Common.InPlace) == "f(dx, dp, x, p)"
                Test.@test Data._natural_sig_hvf(Common.NonAutonomous, Common.Fixed, Common.InPlace) == "f(dx, dp, t, x, p)"
                Test.@test Data._natural_sig_hvf(Common.Autonomous, Common.NonFixed, Common.InPlace) == "f(dx, dp, x, p, v)"
                Test.@test Data._natural_sig_hvf(Common.NonAutonomous, Common.NonFixed, Common.InPlace) == "f(dx, dp, t, x, p, v)"
            end

            Test.@testset "_uniform_sig_hvf" begin
                Test.@test Data._uniform_sig_hvf(Common.OutOfPlace) == "f(t, x, p, v)"
                Test.@test Data._uniform_sig_hvf(Common.InPlace) == "f(dx, dp, t, x, p, v)"
            end

            Test.@testset "Uniform signatures" begin
                Test.@testset "VectorField uniform signatures" begin
                    Test.@test Data._uniform_sig_vf(Common.OutOfPlace) == "f(t, x, v)"
                    Test.@test Data._uniform_sig_vf(Common.InPlace) == "f(dx, t, x, v)"
                end

                Test.@testset "HamiltonianVectorField uniform signatures" begin
                    Test.@test Data._uniform_sig_hvf(Common.OutOfPlace) == "f(t, x, p, v)"
                    Test.@test Data._uniform_sig_hvf(Common.InPlace) == "f(dx, dp, t, x, p, v)"
                end
            end

            Test.@testset "Direct label calls" begin
                Test.@testset "Time dependence labels" begin
                    Test.@test Data._td_label(Common.Autonomous) == "autonomous"
                    Test.@test Data._td_label(Common.NonAutonomous) == "non-autonomous"
                end

                Test.@testset "Variable dependence labels" begin
                    Test.@test Data._vd_label(Common.Fixed) == "fixed (no variable)"
                    Test.@test Data._vd_label(Common.NonFixed) == "variable"
                end

                Test.@testset "Mutability labels" begin
                    Test.@test Data._md_label(Common.OutOfPlace) == "out-of-place"
                    Test.@test Data._md_label(Common.InPlace) == "in-place"
                end
            end
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_helpers() = TestHelpers.test_helpers()
