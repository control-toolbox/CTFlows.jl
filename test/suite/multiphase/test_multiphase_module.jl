"""
# ============================================================================
# MultiPhase Module Exports Tests
# ============================================================================
# This file tests the exports from the `MultiPhase` module. It verifies that
# the expected types and functions are properly exported by
# `CTFlows.MultiPhase` and readily accessible to the end user.
#
# Functionality tests are in separate files:
# - test_multiphase_flow.jl for multiphase flow functionality
# - test_calling_multiphase.jl for calling multiphase flows
"""

module TestMultiPhaseModule

import Test
import CTFlows
import CTFlows.MultiPhase
using CTFlows.MultiPhase  # For testing exported symbols

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const CurrentModule = TestMultiPhaseModule

# ============================================================================
# Hardcoded export lists
# ============================================================================
# These lists define the expected public API of the MultiPhase module.

const EXPORTED_ABSTRACT_TYPES = ()

const EXPORTED_CONCRETE_TYPES = (
    :MultiPhaseStateFlow,
    :MultiPhaseHamiltonianFlow,
    :AnyMultiPhaseFlow,
)

const EXPORTED_FUNCTIONS = (
    :n_phases,
    :get_flow,
    :get_switching_time,
    :get_jump,
    :get_flows,
    :get_switching_times,
    :get_jumps,
)

# Note: MultiPhase module has no private symbols (after filtering Julia internals)
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

function test_multiphase_module()
    Test.@testset "MultiPhase Module Exports" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # Module availability
        # ====================================================================

        Test.@testset "Module availability" begin
            Test.@testset "MultiPhase module exists" begin
                Test.@test isdefined(CTFlows, :MultiPhase)
                Test.@test CTFlows.MultiPhase isa Module
            end
        end

        # ====================================================================
        # Exported abstract types verification
        # ====================================================================

        Test.@testset "Exported abstract types" begin
            test_exported_symbols(MultiPhase, EXPORTED_ABSTRACT_TYPES, CurrentModule)
        end

        # ====================================================================
        # Exported concrete types verification
        # ====================================================================

        Test.@testset "Exported concrete types" begin
            test_exported_symbols(MultiPhase, EXPORTED_CONCRETE_TYPES, CurrentModule)
        end

        # ====================================================================
        # Exported functions verification
        # ====================================================================

        Test.@testset "Exported functions" begin
            test_exported_symbols(MultiPhase, EXPORTED_FUNCTIONS, CurrentModule)
        end

        # ====================================================================
        # Type hierarchy tests
        # ====================================================================

        Test.@testset "Type hierarchy" begin
            Test.@testset "AnyMultiPhaseFlow is MultiPhaseFlow (not a Union)" begin
                Test.@test MultiPhase.AnyMultiPhaseFlow === MultiPhase.MultiPhaseFlow
            end

            Test.@testset "Aliases exist and are distinct from each other" begin
                Test.@test isdefined(MultiPhase, :MultiPhaseFlow)
                Test.@test isdefined(MultiPhase, :MultiPhaseStateFlow)
                Test.@test isdefined(MultiPhase, :MultiPhaseHamiltonianFlow)
                # The two aliases are not the same type
                Test.@test MultiPhase.MultiPhaseStateFlow !== MultiPhase.MultiPhaseHamiltonianFlow
            end
        end
    end
end

end # module

test_multiphase_module() = TestMultiPhaseModule.test_multiphase_module()
