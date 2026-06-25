"""
# ============================================================================
# Common Module Exports Tests
# ============================================================================
# This file tests the exports from the `Common` module. It verifies that
# the expected types, functions, and constants are properly exported by
# `CTFlows.Common` and readily accessible to the end user.
#
# Functionality tests are in separate files:
# - test_ode_parameters.jl for ODEParameters
# - test_internal_norm.jl for deepvalue/real_norm
"""

module TestCommonModule

import Test
import CTFlows
import CTFlows.Common
using CTFlows.Common  # For testing exported symbols

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const CurrentModule = TestCommonModule

# ============================================================================
# Hardcoded export lists
# ============================================================================
# These lists define the expected public API of the Common module.
# For other modules, create similar lists with their specific exports.

const EXPORTED_TYPES = (
    :NotProvided,
    :ODEParameters,
)

const EXPORTED_FUNCTIONS = (
    :variable,
    :deepvalue,
    :real_norm,
    # Shared default values (exported for use across modules)
    :__variable,
    :__unsafe,
    :__hvf_inplace,
    :__variable_costate,
)

# Note: Common module has no private symbols (after filtering Julia internals)
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

function test_common_module()
    Test.@testset "Common Module Exports" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # Module availability
        # ====================================================================

        Test.@testset "Module availability" begin
            Test.@testset "Common module exists" begin
                Test.@test isdefined(CTFlows, :Common)
                Test.@test CTFlows.Common isa Module
            end
        end

        # ====================================================================
        # Exported types verification
        # ====================================================================

        Test.@testset "Exported types" begin
            test_exported_symbols(Common, EXPORTED_TYPES, CurrentModule)
        end

        # ====================================================================
        # Exported functions verification
        # ====================================================================

        Test.@testset "Exported functions" begin
            test_exported_symbols(Common, EXPORTED_FUNCTIONS, CurrentModule)
        end

        # ====================================================================
        # Type hierarchy tests
        # ====================================================================

        Test.@testset "Type hierarchy" begin
            Test.@testset "NotProvided is concrete" begin
                Test.@test !isabstracttype(Common.NotProvided)
            end

            Test.@testset "ODEParameters is concrete" begin
                Test.@test !isabstracttype(Common.ODEParameters)
            end
        end
    end
end

end # module

test_common_module() = TestCommonModule.test_common_module()
