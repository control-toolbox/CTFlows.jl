"""
# ============================================================================
# Integrators Module Exports Tests
# ============================================================================
# This file tests the exports from the `Integrators` module. It verifies that
# the expected types and functions are properly exported by
# `CTFlows.Integrators` and readily accessible to the end user.
#
# Functionality tests are in separate files:
# - test_building_integrators.jl for integrator building functionality
"""

module TestIntegratorsModule

import Test
import CTFlows
import CTFlows.Integrators
using CTFlows.Integrators  # For testing exported symbols

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const CurrentModule = TestIntegratorsModule

# ============================================================================
# Hardcoded export lists
# ============================================================================
# These lists define the expected public API of the Integrators module.

const EXPORTED_ABSTRACT_TYPES = (
    :AbstractIntegrator,
    :AbstractSciMLIntegrator,
    :AbstractIntegrationResult,
)

const EXPORTED_CONCRETE_TYPES = (
    :SciML,
    :SciMLTag,
    :Tsit5Tag,
)

const EXPORTED_FUNCTIONS = (
    :build_sciml_integrator,
    :build_integrator,
    :build_problem,
    :solve_problem,
    :final_state,
    :times,
    :evaluate_at,
)

# Note: Integrators module has no private symbols (after filtering Julia internals)
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

function test_integrators_module()
    Test.@testset "Integrators Module Exports" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # Module availability
        # ====================================================================

        Test.@testset "Module availability" begin
            Test.@testset "Integrators module exists" begin
                Test.@test isdefined(CTFlows, :Integrators)
                Test.@test CTFlows.Integrators isa Module
            end
        end

        # ====================================================================
        # Exported abstract types verification
        # ====================================================================

        Test.@testset "Exported abstract types" begin
            test_exported_symbols(Integrators, EXPORTED_ABSTRACT_TYPES, CurrentModule)
        end

        # ====================================================================
        # Exported concrete types verification
        # ====================================================================

        Test.@testset "Exported concrete types" begin
            test_exported_symbols(Integrators, EXPORTED_CONCRETE_TYPES, CurrentModule)
        end

        # ====================================================================
        # Exported functions verification
        # ====================================================================

        Test.@testset "Exported functions" begin
            test_exported_symbols(Integrators, EXPORTED_FUNCTIONS, CurrentModule)
        end

        # ====================================================================
        # Type hierarchy tests
        # ====================================================================

        Test.@testset "Type hierarchy" begin
            Test.@testset "Abstract types are abstract" begin
                Test.@test isabstracttype(Integrators.AbstractIntegrator)
                Test.@test isabstracttype(Integrators.AbstractSciMLIntegrator)
                Test.@test isabstracttype(Integrators.AbstractIntegrationResult)
            end

            Test.@testset "Concrete types inherit from abstract types" begin
                Test.@test Integrators.SciML <: Integrators.AbstractSciMLIntegrator
                Test.@test Integrators.SciML <: Integrators.AbstractIntegrator
            end
        end
    end
end

end # module

test_integrators_module() = TestIntegratorsModule.test_integrators_module()