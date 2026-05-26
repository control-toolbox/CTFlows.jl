"""
    Systems

System types and contracts for CTFlows.

This module defines the `AbstractSystem` type and its required methods:
- `rhs`: returns the right-hand side function for integration
- `dimensions`: returns dimensional information (state, costate, control, variable)
"""
module Systems

# 1. External-package imports (qualified, pollution-free)
import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Exceptions

# ==============================================================================
# Internal sibling-submodule imports
# ==============================================================================

import ..Common: Common
import ..Traits: Traits
import ..Data: Data
import ..Differentiation: Differentiation

# ==============================================================================
# Include files
# ==============================================================================

include(joinpath(@__DIR__, "abstract_system.jl"))
include(joinpath(@__DIR__, "vector_field_system.jl"))
include(joinpath(@__DIR__, "hamiltonian_vector_field_system.jl"))
include(joinpath(@__DIR__, "hamiltonian_system.jl"))
include(joinpath(@__DIR__, "building.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export AbstractSystem, AbstractStateSystem, AbstractHamiltonianSystem
export rhs
export build_rhs
export build_oop_rhs
export VectorFieldSystem
export HamiltonianVectorFieldSystem
export HamiltonianSystem
export build_system
export build_rhs_augmented

end # module Systems
