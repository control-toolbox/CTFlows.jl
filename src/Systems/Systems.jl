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

using ..Common
using ..Data

# ==============================================================================
# Include files
# ==============================================================================

include(joinpath(@__DIR__, "abstract_system.jl"))
include(joinpath(@__DIR__, "vector_field_system.jl"))
include(joinpath(@__DIR__, "hamiltonian_vector_field_system.jl"))
include(joinpath(@__DIR__, "building.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export AbstractSystem, AbstractStateSystem, AbstractHamiltonianSystem
export rhs
export rhs_oop
export state_dimension
export VectorFieldSystem
export HamiltonianVectorFieldSystem
export build_system

end # module Systems
