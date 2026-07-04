"""
# ============================================================================
# Solutions Module Exports Tests
# ============================================================================
# This file tests the exports from the `Solutions` module. It verifies that
# the expected types and functions are properly exported by
# `CTFlows.Trajectories` and readily accessible to the end user.
#
# Functionality tests are in separate files:
# - test_building_solutions.jl for solution building functionality
"""

module TestTrajectoriesModule

using Test: Test
using CTFlows: CTFlows
import CTFlows.Trajectories
using CTFlows.Trajectories  # For testing exported symbols

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const CurrentModule = TestTrajectoriesModule

# ============================================================================
# Hardcoded export lists
# ============================================================================
# These lists define the expected public API of the Solutions module.

const EXPORTED_ABSTRACT_TYPES = (
    :AbstractVectorFieldTrajectory, :AbstractHamiltonianVectorFieldTrajectory
)

const EXPORTED_CONCRETE_TYPES = (:VectorFieldTrajectory, :HamiltonianVectorFieldTrajectory)

const EXPORTED_FUNCTIONS = (:state, :time_grid, :costate, :build_trajectory, :plot)

# Note: Solutions module has no private symbols (after filtering Julia internals)
# All symbols are exported

# ============================================================================
# Helper functions (generic for reuse in other modules)
# ============================================================================

"""
    test_exported_symbols(module_ref::Module, symbols::Tuple, test_module::Module)

Test that symbols are exported from a module and available via `using`.
"""
function test_exported_symbols(module_ref::Module, symbols::Tuple, test_module::Module)
    for sym in symbols
        Test.@testset "$(sym)" begin
            Test.@test isdefined(module_ref, sym)
            Test.@test isdefined(test_module, sym)
        end
    end
end

"""
    test_internal_symbols(module_ref::Module, symbols::Tuple, test_module::Module)

Test that symbols are defined in a module but NOT exported (not available via `using`).
Generic helper for modules with private symbols.
"""
function test_internal_symbols(module_ref::Module, symbols::Tuple, test_module::Module)
    for sym in symbols
        Test.@testset "$(sym)" begin
            Test.@test isdefined(module_ref, sym)
            Test.@test !isdefined(test_module, sym)
        end
    end
end

# ============================================================================
# Test function
# ============================================================================

function test_trajectories_module()
    Test.@testset "Trajectories Module Exports" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # Module availability
        # ====================================================================

        Test.@testset "Module availability" begin
            Test.@testset "Trajectories module exists" begin
                Test.@test isdefined(CTFlows, :Trajectories)
                Test.@test CTFlows.Trajectories isa Module
            end
        end

        # ====================================================================
        # Exported abstract types verification
        # ====================================================================

        Test.@testset "Exported abstract types" begin
            test_exported_symbols(Trajectories, EXPORTED_ABSTRACT_TYPES, CurrentModule)
        end

        # ====================================================================
        # Exported concrete types verification
        # ====================================================================

        Test.@testset "Exported concrete types" begin
            test_exported_symbols(Trajectories, EXPORTED_CONCRETE_TYPES, CurrentModule)
        end

        # ====================================================================
        # Exported functions verification
        # ====================================================================

        Test.@testset "Exported functions" begin
            test_exported_symbols(Trajectories, EXPORTED_FUNCTIONS, CurrentModule)
        end

        # ====================================================================
        # Type hierarchy tests
        # ====================================================================

        Test.@testset "Type hierarchy" begin
            Test.@testset "Abstract types are abstract" begin
                Test.@test isabstracttype(Trajectories.AbstractVectorFieldTrajectory)
                Test.@test isabstracttype(
                    Trajectories.AbstractHamiltonianVectorFieldTrajectory
                )
            end

            Test.@testset "Concrete types inherit from abstract types" begin
                Test.@test Trajectories.VectorFieldTrajectory <:
                    Trajectories.AbstractVectorFieldTrajectory
                Test.@test Trajectories.HamiltonianVectorFieldTrajectory <:
                    Trajectories.AbstractHamiltonianVectorFieldTrajectory
            end
        end
    end
end

end # module

test_trajectories_module() = TestTrajectoriesModule.test_trajectories_module()
