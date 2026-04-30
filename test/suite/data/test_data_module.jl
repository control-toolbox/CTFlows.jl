"""
# ============================================================================
# Data Module Exports Tests
# ============================================================================
# This file tests the exports from the `Data` module. It verifies that
# the expected types and constructors are properly exported by
# `CTFlows.Data` and readily accessible to the end user.
"""

module TestDataModule

import Test
import CTFlows.Data
import CTFlows.Common

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

const CurrentModule = TestDataModule

function test_data_module()
    Test.@testset "Data Module Exports" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # VectorField Type
        # ====================================================================

        Test.@testset "VectorField Type" begin
            Test.@testset "VectorField is exported" begin
                Test.@test isdefined(Data, :VectorField)
                Test.@test Data.VectorField <: Data.VectorField
            end

            Test.@testset "VectorField constructor is exported" begin
                Test.@test isdefined(Data, :VectorField)
                vf = Data.VectorField(x -> x; autonomous=true, variable=false)
                Test.@test vf isa Data.VectorField
            end

            Test.@testset "VectorField with Autonomous trait" begin
                vf = Data.VectorField(x -> x; autonomous=true, variable=false)
                Test.@test Common.time_dependence(vf) === Common.Autonomous
                Test.@test Common.variable_dependence(vf) === Common.Fixed
            end

            Test.@testset "VectorField with NonAutonomous trait" begin
                vf = Data.VectorField((t, x) -> t .* x; autonomous=false, variable=false)
                Test.@test Common.time_dependence(vf) === Common.NonAutonomous
                Test.@test Common.variable_dependence(vf) === Common.Fixed
            end

            Test.@testset "VectorField with NonFixed trait" begin
                vf = Data.VectorField((x, v) -> x .* v; autonomous=true, variable=true)
                Test.@test Common.time_dependence(vf) === Common.Autonomous
                Test.@test Common.variable_dependence(vf) === Common.NonFixed
            end

            Test.@testset "VectorField with NonAutonomous and NonFixed traits" begin
                vf = Data.VectorField((t, x, v) -> t .* x .* v; autonomous=false, variable=true)
                Test.@test Common.time_dependence(vf) === Common.NonAutonomous
                Test.@test Common.variable_dependence(vf) === Common.NonFixed
            end
        end

        # ====================================================================
        # Trait Support
        # ====================================================================

        Test.@testset "Trait Support" begin
            Test.@testset "VectorField has time dependence trait" begin
                vf = Data.VectorField(x -> x)
                Test.@test Common.has_time_dependence_trait(vf)
            end

            Test.@testset "VectorField has variable dependence trait" begin
                vf = Data.VectorField(x -> x)
                Test.@test Common.has_variable_dependence_trait(vf)
            end

            Test.@testset "time_dependence function works with VectorField" begin
                vf_aut = Data.VectorField(x -> x; autonomous=true)
                Test.@test Common.time_dependence(vf_aut) === Common.Autonomous

                vf_non = Data.VectorField((t, x) -> x; autonomous=false)
                Test.@test Common.time_dependence(vf_non) === Common.NonAutonomous
            end

            Test.@testset "variable_dependence function works with VectorField" begin
                vf_fixed = Data.VectorField(x -> x; variable=false)
                Test.@test Common.variable_dependence(vf_fixed) === Common.Fixed

                vf_nonfixed = Data.VectorField((x, v) -> x .* v; variable=true)
                Test.@test Common.variable_dependence(vf_nonfixed) === Common.NonFixed
            end
        end

        # ====================================================================
        # Call Signatures
        # ====================================================================

        Test.@testset "Call Signatures" begin
            Test.@testset "Autonomous Fixed signature" begin
                vf = Data.VectorField(x -> -x; autonomous=true, variable=false)
                result = vf([1.0, 2.0])
                Test.@test result ≈ [-1.0, -2.0]
            end

            Test.@testset "NonAutonomous Fixed signature" begin
                vf = Data.VectorField((t, x) -> t .* x; autonomous=false, variable=false)
                result = vf(2.0, [1.0, 2.0])
                Test.@test result ≈ [2.0, 4.0]
            end

            Test.@testset "Autonomous NonFixed signature" begin
                vf = Data.VectorField((x, v) -> x .* v; autonomous=true, variable=true)
                result = vf([1.0, 2.0], 3.0)
                Test.@test result ≈ [3.0, 6.0]
            end

            Test.@testset "NonAutonomous NonFixed signature" begin
                vf = Data.VectorField((t, x, v) -> t .* x .* v; autonomous=false, variable=true)
                result = vf(2.0, [1.0, 2.0], 3.0)
                Test.@test result ≈ [6.0, 12.0]
            end

            Test.@testset "Uniform (t, x, v) signature works for all traits" begin
                # Autonomous Fixed - ignores t and v
                vf1 = Data.VectorField(x -> -x; autonomous=true, variable=false)
                result1 = vf1(0.0, [1.0, 2.0], nothing)
                Test.@test result1 ≈ [-1.0, -2.0]

                # NonAutonomous Fixed - ignores v
                vf2 = Data.VectorField((t, x) -> t .* x; autonomous=false, variable=false)
                result2 = vf2(2.0, [1.0, 2.0], nothing)
                Test.@test result2 ≈ [2.0, 4.0]

                # Autonomous NonFixed - ignores t
                vf3 = Data.VectorField((x, v) -> x .* v; autonomous=true, variable=true)
                result3 = vf3(0.0, [1.0, 2.0], 3.0)
                Test.@test result3 ≈ [3.0, 6.0]

                # NonAutonomous NonFixed - uses all
                vf4 = Data.VectorField((t, x, v) -> t .* x .* v; autonomous=false, variable=true)
                result4 = vf4(2.0, [1.0, 2.0], 3.0)
                Test.@test result4 ≈ [6.0, 12.0]
            end
        end
    end
end

end # module TestDataModule

# CRITICAL: Redefine in outer scope for TestRunner
test_data_module() = TestDataModule.test_data_module()
