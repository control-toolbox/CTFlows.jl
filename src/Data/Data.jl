"""
    Data

Data structures for CTFlows including vector fields with traits.

This module defines the `VectorField` type which encapsulates a vector-field
function together with its time-dependence and variable-dependence traits.
"""
module Data

# 1. External-package imports (qualified, pollution-free)
import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES

# ==============================================================================
# Internal sibling-submodule imports
# ==============================================================================

using ..Common

# ==============================================================================
# Include files
# ==============================================================================

include(joinpath(@__DIR__, "vector_field.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export VectorField

end # module Data
