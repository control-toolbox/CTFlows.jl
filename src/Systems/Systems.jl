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
# Internal submodule imports
# ==============================================================================

using ..Core

# ==============================================================================
# Include files
# ==============================================================================

include(joinpath(@__DIR__, "abstract_system.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export AbstractSystem
export rhs!, dimensions, build_solution

end # module Systems
