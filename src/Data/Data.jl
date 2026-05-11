"""
    Data

Data structures for CTFlows including vector fields and Hamiltonian vector fields with traits.

This module defines the `VectorField` and `HamiltonianVectorField` types which encapsulate
vector-field functions together with their time-dependence and variable-dependence traits.
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
include(joinpath(@__DIR__, "hamiltonian_vector_field.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export VectorField
export HamiltonianVectorField

end # module Data
