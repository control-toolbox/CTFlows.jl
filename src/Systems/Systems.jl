"""
    Systems

System types and contracts for CTFlows.

This module defines the `AbstractSystem` type and its required methods:
- `rhs!`: returns the right-hand side function for integration
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

# ==============================================================================
# Module exports
# ==============================================================================

export AbstractSystem
export rhs!
export VectorFieldSystem

end # module Systems
