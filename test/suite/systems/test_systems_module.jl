"""
# ============================================================================
# Systems Module Exports Tests
# ============================================================================
# This file tests the exports from the `Systems` module. It verifies that
# the expected types, functions, and constructors are properly exported by
# `CTFlows.Systems` and readily accessible to the end user.
"""

module TestSystemsModule

import Test
import CTFlows.Systems
import CTFlows.Data
import CTFlows.Common

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

const CurrentModule = TestSystemsModule

function test_systems_module()
    Test.@testset "Systems Module Exports" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            Test.@testset "AbstractSystem is exported" begin
                Test.@test isdefined(Systems, :AbstractSystem)
                Test.@test isabstracttype(Systems.AbstractSystem)
            end
        end

        # ====================================================================
        # Concrete Types
        # ====================================================================

        Test.@testset "Concrete Types" begin
            Test.@testset "VectorFieldSystem is exported" begin
                Test.@test isdefined(Systems, :VectorFieldSystem)
                Test.@test Systems.VectorFieldSystem <: Systems.AbstractSystem
            end

            Test.@testset "VectorFieldSystem constructor is exported" begin
                Test.@test isdefined(Systems, :VectorFieldSystem)
                vf = Data.VectorField(x -> x; autonomous=true, variable=false)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test sys isa Systems.VectorFieldSystem
                Test.@test sys isa Systems.AbstractSystem
            end
        end

        # ====================================================================
        # Functions
        # ====================================================================

        Test.@testset "Functions" begin
            Test.@testset "rhs! is exported" begin
                Test.@test isdefined(Systems, :rhs!)
            end

            Test.@testset "rhs! returns a callable function" begin
                vf = Data.VectorField(x -> -x; autonomous=true, variable=false)
                sys = Systems.VectorFieldSystem(vf)
                rhs = Systems.rhs!(sys)
                Test.@test isa(rhs, Function)

                du = zeros(2)
                u = [1.0, 2.0]
                rhs(du, u, nothing, 0.0)
                Test.@test du ≈ [-1.0, -2.0]
            end
        end

        # ====================================================================
        # Trait Support
        # ====================================================================

        Test.@testset "Trait Support" begin
            Test.@testset "VectorFieldSystem has time dependence trait" begin
                vf = Data.VectorField(x -> x)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Common.has_time_dependence_trait(sys)
            end

            Test.@testset "VectorFieldSystem has variable dependence trait" begin
                vf = Data.VectorField(x -> x)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Common.has_variable_dependence_trait(sys)
            end

            Test.@testset "time_dependence function works with VectorFieldSystem" begin
                vf_aut = Data.VectorField(x -> x; autonomous=true)
                sys_aut = Systems.VectorFieldSystem(vf_aut)
                Test.@test Common.time_dependence(sys_aut) === Common.Autonomous

                vf_non = Data.VectorField((t, x) -> x; autonomous=false)
                sys_non = Systems.VectorFieldSystem(vf_non)
                Test.@test Common.time_dependence(sys_non) === Common.NonAutonomous
            end

            Test.@testset "variable_dependence function works with VectorFieldSystem" begin
                vf_fixed = Data.VectorField(x -> x; variable=false)
                sys_fixed = Systems.VectorFieldSystem(vf_fixed)
                Test.@test Common.variable_dependence(sys_fixed) === Common.Fixed

                vf_nonfixed = Data.VectorField((x, v) -> x .* v; variable=true)
                sys_nonfixed = Systems.VectorFieldSystem(vf_nonfixed)
                Test.@test Common.variable_dependence(sys_nonfixed) === Common.NonFixed
            end
        end

        # ====================================================================
        # Trait Propagation
        # ====================================================================

        Test.@testset "Trait Propagation" begin
            Test.@testset "Autonomous Fixed traits propagate" begin
                vf = Data.VectorField(x -> x; autonomous=true, variable=false)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Common.time_dependence(sys) === Common.Autonomous
                Test.@test Common.variable_dependence(sys) === Common.Fixed
            end

            Test.@testset "NonAutonomous Fixed traits propagate" begin
                vf = Data.VectorField((t, x) -> t .* x; autonomous=false, variable=false)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Common.time_dependence(sys) === Common.NonAutonomous
                Test.@test Common.variable_dependence(sys) === Common.Fixed
            end

            Test.@testset "Autonomous NonFixed traits propagate" begin
                vf = Data.VectorField((x, v) -> x .* v; autonomous=true, variable=true)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Common.time_dependence(sys) === Common.Autonomous
                Test.@test Common.variable_dependence(sys) === Common.NonFixed
            end

            Test.@testset "NonAutonomous NonFixed traits propagate" begin
                vf = Data.VectorField((t, x, v) -> t .* x .* v; autonomous=false, variable=true)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Common.time_dependence(sys) === Common.NonAutonomous
                Test.@test Common.variable_dependence(sys) === Common.NonFixed
            end
        end

        # ====================================================================
        # Type Hierarchy Verification
        # ====================================================================

        Test.@testset "Type Hierarchy" begin
            Test.@testset "VectorFieldSystem is a subtype of AbstractSystem" begin
                Test.@test Systems.VectorFieldSystem <: Systems.AbstractSystem
            end

            Test.@testset "Concrete VectorFieldSystem instances are AbstractSystem" begin
                vf = Data.VectorField(x -> x)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test sys isa Systems.AbstractSystem
                Test.@test sys isa Systems.VectorFieldSystem
            end
        end
    end
end

end # module TestSystemsModule

# CRITICAL: Redefine in outer scope for TestRunner
test_systems_module() = TestSystemsModule.test_systems_module()
