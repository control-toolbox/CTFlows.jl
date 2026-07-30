"""
# ============================================================================
# Flows Module Exports Tests
# ============================================================================
# This file tests the exports from the `Flows` module. It verifies that
# the expected types and functions are properly exported by
# `CTFlows.Flows` and readily accessible to the end user.
#
# Functionality tests are in separate files:
# - test_abstract_flow.jl for abstract flow types
# - test_flow.jl for Flow constructor and functionality
# - test_building_flows.jl for flow building functionality
# - test_calling_flows.jl for calling flows
# - test_flow_routing.jl for flow routing
# - test_variable_costate_flows.jl for variable costate flows
# - test_hamiltonian_getter_flows.jl for Hamiltonian getter flows
"""

module TestFlowModule

using Test: Test
using CTFlows: CTFlows
using CTFlows: Flows
using CTFlows.Flows  # For testing exported symbols

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const CurrentModule = TestFlowModule

# ============================================================================
# Hardcoded export lists
# ============================================================================
# These lists define the expected public API of the Flows module.

const EXPORTED_ABSTRACT_TYPES = (
    :AbstractFlow, :AbstractStateFlow, :AbstractHamiltonianFlow
)

const EXPORTED_CONCRETE_TYPES = (:Flow, :StateFlow, :HamiltonianFlow)

const EXPORTED_FUNCTIONS = (
    :system, :integrator, :build_flow, :hamiltonian_vector_field, :flow_registry
)

# Note: Flows module has no private symbols (after filtering Julia internals)
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

function test_flow_module()
    Test.@testset "Flows Module Exports" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # Module availability
        # ====================================================================

        Test.@testset "Module availability" begin
            Test.@testset "Flows module exists" begin
                Test.@test isdefined(CTFlows, :Flows)
                Test.@test CTFlows.Flows isa Module
            end
        end

        # ====================================================================
        # Exported abstract types verification
        # ====================================================================

        Test.@testset "Exported abstract types" begin
            test_exported_symbols(Flows, EXPORTED_ABSTRACT_TYPES, CurrentModule)
        end

        # ====================================================================
        # Exported concrete types verification
        # ====================================================================

        Test.@testset "Exported concrete types" begin
            test_exported_symbols(Flows, EXPORTED_CONCRETE_TYPES, CurrentModule)
        end

        # ====================================================================
        # Exported functions verification
        # ====================================================================

        Test.@testset "Exported functions" begin
            test_exported_symbols(Flows, EXPORTED_FUNCTIONS, CurrentModule)
        end

        # ====================================================================
        # Type hierarchy tests
        # ====================================================================

        Test.@testset "Type hierarchy" begin
            Test.@testset "Abstract types are abstract" begin
                Test.@test isabstracttype(Flows.AbstractFlow)
                Test.@test isabstracttype(Flows.AbstractStateFlow)
                Test.@test isabstracttype(Flows.AbstractHamiltonianFlow)
            end

            Test.@testset "Concrete types inherit from abstract types" begin
                Test.@test Flows.StateFlow <: Flows.AbstractStateFlow
                Test.@test Flows.HamiltonianFlow <: Flows.AbstractHamiltonianFlow
            end
        end
    end
end

end # module TestFlowModule

# CRITICAL: Redefine in outer scope for TestRunner
test_flow_module() = TestFlowModule.test_flow_module()
