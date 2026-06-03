"""
# ============================================================================
# Solutions Module Exports Tests
# ============================================================================
# This file tests the exports from the `Solutions` module. It verifies that
# the expected types and functions are properly exported by
# `CTFlows.Solutions` and readily accessible to the end user.
#
# Functionality tests are in separate files:
# - test_building_solutions.jl for solution building functionality
"""

module TestSolutionsModule

import Test
import CTFlows
import CTFlows.Solutions
using CTFlows.Solutions  # For testing exported symbols

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

const CurrentModule = TestSolutionsModule

# ============================================================================
# Hardcoded export lists
# ============================================================================
# These lists define the expected public API of the Solutions module.

const EXPORTED_ABSTRACT_TYPES = (
    :AbstractVectorFieldSolution,
    :AbstractHamiltonianVectorFieldSolution,
)

const EXPORTED_CONCRETE_TYPES = (
    :VectorFieldSolution,
    :HamiltonianVectorFieldSolution,
)

const EXPORTED_FUNCTIONS = (
    :state,
    :time_grid,
    :costate,
    :build_solution,
    :plot,
)

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

function test_solutions_module()
    Test.@testset "Solutions Module Exports" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # Module availability
        # ====================================================================

        Test.@testset "Module availability" begin
            Test.@testset "Solutions module exists" begin
                Test.@test isdefined(CTFlows, :Solutions)
                Test.@test CTFlows.Solutions isa Module
            end
        end

        # ====================================================================
        # Exported abstract types verification
        # ====================================================================

        Test.@testset "Exported abstract types" begin
            test_exported_symbols(Solutions, EXPORTED_ABSTRACT_TYPES, CurrentModule)
        end

        # ====================================================================
        # Exported concrete types verification
        # ====================================================================

        Test.@testset "Exported concrete types" begin
            test_exported_symbols(Solutions, EXPORTED_CONCRETE_TYPES, CurrentModule)
        end

        # ====================================================================
        # Exported functions verification
        # ====================================================================

        Test.@testset "Exported functions" begin
            test_exported_symbols(Solutions, EXPORTED_FUNCTIONS, CurrentModule)
        end

        # ====================================================================
        # Type hierarchy tests
        # ====================================================================

        Test.@testset "Type hierarchy" begin
            Test.@testset "Abstract types are abstract" begin
                Test.@test isabstracttype(Solutions.AbstractVectorFieldSolution)
                Test.@test isabstracttype(Solutions.AbstractHamiltonianVectorFieldSolution)
            end

            Test.@testset "Concrete types inherit from abstract types" begin
                Test.@test Solutions.VectorFieldSolution <: Solutions.AbstractVectorFieldSolution
                Test.@test Solutions.HamiltonianVectorFieldSolution <: Solutions.AbstractHamiltonianVectorFieldSolution
            end
        end
    end
end

end # module

test_solutions_module() = TestSolutionsModule.test_solutions_module()