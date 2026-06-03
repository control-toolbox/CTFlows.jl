"""
# ============================================================================
# Systems Module Exports Tests
# ============================================================================
# This file tests the exports from the `Systems` module. It verifies that
# the expected types and functions are properly exported by
# `CTFlows.Systems` and readily accessible to the end user.
#
# Functionality tests are in separate files:
# - test_abstract_system.jl for abstract system types
# - test_vector_field_system.jl for VectorFieldSystem constructor and functionality
# - test_hamiltonian_vector_field_system.jl for HVFSystem constructor and functionality
# - test_hamiltonian_system.jl for HamiltonianSystem constructor and functionality
# - test_building_systems.jl for system building functionality
# - test_hamiltonian_getter.jl for Hamiltonian getter functionality
# - test_rhs_functors.jl for RHS functor functionality
# - test_hvf_rhs_functors.jl for HVF RHS functor functionality
# - test_ham_rhs_functors.jl for Hamiltonian RHS functor functionality
"""

module TestSystemsModule

import Test
import CTFlows
import CTFlows.Systems
using CTFlows.Systems  # For testing exported symbols

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

const CurrentModule = TestSystemsModule

# ============================================================================
# Hardcoded export lists
# ============================================================================
# These lists define the expected public API of the Systems module.

const EXPORTED_ABSTRACT_TYPES = (
    :AbstractSystem,
    :AbstractStateSystem,
    :AbstractHamiltonianSystem,
    :AbstractRHS,
    :AbstractIPRHS,
    :AbstractOoPRHS,
    :AbstractHVFRHS,
    :AbstractIPHVFRHS,
    :AbstractOoPHVFRHS,
    :AbstractHamRHS,
    :AbstractIPHamRHS,
    :AbstractOoPHamRHS,
)

const EXPORTED_CONCRETE_TYPES = (
    :VectorFieldSystem,
    :HamiltonianVectorFieldSystem,
    :HamiltonianSystem,
)

const EXPORTED_FUNCTIONS = (
    :rhs,
    :rhs_oop,
    :build_rhs,
    :build_oop_rhs,
    :hamiltonian_vector_field,
    :build_system,
    :build_rhs_augmented,
    :hamiltonian,
    :backend,
)

# Note: Systems module has no private symbols (after filtering Julia internals)
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

function test_systems_module()
    Test.@testset "Systems Module Exports" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # Module availability
        # ====================================================================

        Test.@testset "Module availability" begin
            Test.@testset "Systems module exists" begin
                Test.@test isdefined(CTFlows, :Systems)
                Test.@test CTFlows.Systems isa Module
            end
        end

        # ====================================================================
        # Exported abstract types verification
        # ====================================================================

        Test.@testset "Exported abstract types" begin
            test_exported_symbols(Systems, EXPORTED_ABSTRACT_TYPES, CurrentModule)
        end

        # ====================================================================
        # Exported concrete types verification
        # ====================================================================

        Test.@testset "Exported concrete types" begin
            test_exported_symbols(Systems, EXPORTED_CONCRETE_TYPES, CurrentModule)
        end

        # ====================================================================
        # Exported functions verification
        # ====================================================================

        Test.@testset "Exported functions" begin
            test_exported_symbols(Systems, EXPORTED_FUNCTIONS, CurrentModule)
        end

        # ====================================================================
        # Type hierarchy tests
        # ====================================================================

        Test.@testset "Type hierarchy" begin
            Test.@testset "Abstract types are abstract" begin
                Test.@test isabstracttype(Systems.AbstractSystem)
                Test.@test isabstracttype(Systems.AbstractStateSystem)
                Test.@test isabstracttype(Systems.AbstractHamiltonianSystem)
                Test.@test isabstracttype(Systems.AbstractRHS)
                Test.@test isabstracttype(Systems.AbstractIPRHS)
                Test.@test isabstracttype(Systems.AbstractOoPRHS)
                Test.@test isabstracttype(Systems.AbstractHVFRHS)
                Test.@test isabstracttype(Systems.AbstractIPHVFRHS)
                Test.@test isabstracttype(Systems.AbstractOoPHVFRHS)
                Test.@test isabstracttype(Systems.AbstractHamRHS)
                Test.@test isabstracttype(Systems.AbstractIPHamRHS)
                Test.@test isabstracttype(Systems.AbstractOoPHamRHS)
            end

            Test.@testset "Concrete types inherit from abstract types" begin
                Test.@test Systems.VectorFieldSystem <: Systems.AbstractStateSystem
                Test.@test Systems.VectorFieldSystem <: Systems.AbstractSystem
                Test.@test Systems.HamiltonianVectorFieldSystem <: Systems.AbstractHamiltonianSystem
                Test.@test Systems.HamiltonianVectorFieldSystem <: Systems.AbstractSystem
                Test.@test Systems.HamiltonianSystem <: Systems.AbstractHamiltonianSystem
                Test.@test Systems.HamiltonianSystem <: Systems.AbstractSystem
            end
        end
    end
end

end # module TestSystemsModule

# CRITICAL: Redefine in outer scope for TestRunner
test_systems_module() = TestSystemsModule.test_systems_module()
