"""
# ============================================================================
# Configs Module Exports Tests
# ============================================================================
# This file tests the exports from the `Configs` module. It verifies that
# the expected types and functions are properly exported by
# `CTFlows.Configs` and readily accessible to the end user.
#
# Functionality tests are in separate files:
# - test_abstract_configs.jl for abstract config types
# - test_concrete_configs.jl for concrete config types
# - test_implementations_configs.jl for config implementations
# - test_interface_configs.jl for config interface
# - test_show_configs.jl for show methods
"""

module TestConfigsModule

import Test
import CTFlows
import CTFlows.Configs
using CTFlows.Configs  # For testing exported symbols

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const CurrentModule = TestConfigsModule

# ============================================================================
# Hardcoded export lists
# ============================================================================
# These lists define the expected public API of the Configs module.

const EXPORTED_ABSTRACT_TYPES = (
    :AbstractConfig,
    :AbstractConfigWithMaC,
    :AbstractEndPointConfig,
    :AbstractTrajectoryConfig,
    :AbstractStateConfig,
    :AbstractHamiltonianConfig,
    :AbstractAugmentedHamiltonianConfig,
)

const EXPORTED_CONCRETE_TYPES = (
    :StateEndPointConfig,
    :StateTrajectoryConfig,
    :HamiltonianEndPointConfig,
    :HamiltonianTrajectoryConfig,
    :AugmentedHamiltonianEndPointConfig,
)

const EXPORTED_FUNCTIONS = (
    :tspan,
    :initial_condition,
    :initial_state,
    :initial_costate,
    :initial_variable_costate,
    :initial_time,
    :final_time,
    :mode_trait,
    :dynamics_trait,
)

# Note: Configs module has no private symbols (after filtering Julia internals)
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

function test_configs_module()
    Test.@testset "Configs Module Exports" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # Module availability
        # ====================================================================

        Test.@testset "Module availability" begin
            Test.@testset "Configs module exists" begin
                Test.@test isdefined(CTFlows, :Configs)
                Test.@test CTFlows.Configs isa Module
            end
        end

        # ====================================================================
        # Exported abstract types verification
        # ====================================================================

        Test.@testset "Exported abstract types" begin
            test_exported_symbols(Configs, EXPORTED_ABSTRACT_TYPES, CurrentModule)
        end

        # ====================================================================
        # Exported concrete types verification
        # ====================================================================

        Test.@testset "Exported concrete types" begin
            test_exported_symbols(Configs, EXPORTED_CONCRETE_TYPES, CurrentModule)
        end

        # ====================================================================
        # Exported functions verification
        # ====================================================================

        Test.@testset "Exported functions" begin
            test_exported_symbols(Configs, EXPORTED_FUNCTIONS, CurrentModule)
        end

        # ====================================================================
        # Type hierarchy tests
        # ====================================================================

        Test.@testset "Type hierarchy" begin
            Test.@testset "Abstract types are abstract" begin
                Test.@test isabstracttype(Configs.AbstractConfig)
                Test.@test isabstracttype(Configs.AbstractConfigWithMaC)
                Test.@test isabstracttype(Configs.AbstractEndPointConfig)
                Test.@test isabstracttype(Configs.AbstractTrajectoryConfig)
                Test.@test isabstracttype(Configs.AbstractStateConfig)
                Test.@test isabstracttype(Configs.AbstractHamiltonianConfig)
                Test.@test isabstracttype(Configs.AbstractAugmentedHamiltonianConfig)
            end

            Test.@testset "Concrete types inherit from abstract types" begin
                Test.@test Configs.StateEndPointConfig <: Configs.AbstractEndPointConfig
                Test.@test Configs.StateEndPointConfig <: Configs.AbstractStateConfig
                Test.@test Configs.StateTrajectoryConfig <: Configs.AbstractTrajectoryConfig
                Test.@test Configs.StateTrajectoryConfig <: Configs.AbstractStateConfig
                Test.@test Configs.HamiltonianEndPointConfig <: Configs.AbstractEndPointConfig
                Test.@test Configs.HamiltonianEndPointConfig <: Configs.AbstractHamiltonianConfig
                Test.@test Configs.HamiltonianTrajectoryConfig <: Configs.AbstractTrajectoryConfig
                Test.@test Configs.HamiltonianTrajectoryConfig <: Configs.AbstractHamiltonianConfig
                Test.@test Configs.AugmentedHamiltonianEndPointConfig <: Configs.AbstractEndPointConfig
                Test.@test Configs.AugmentedHamiltonianEndPointConfig <: Configs.AbstractAugmentedHamiltonianConfig
            end
        end
    end
end

end # module

test_configs_module() = TestConfigsModule.test_configs_module()
