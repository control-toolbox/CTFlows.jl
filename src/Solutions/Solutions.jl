"""
    Pipelines

Pipeline functions for CTFlows.

This module provides high-level pipeline functions that operate on abstract types:
- `build_system`: Build a system from a vector field
- `build_flow`: Build a flow from a system and integrator
- `integrate`: Integrate a flow using a configuration object
- `solve`: Solve an ODE problem using a flow (alias for integrate)
- `Flow`: High-level constructor for Flow from vector field data

All pipelines are written using only the abstract types, allowing concrete implementations
to plug in without changing the pipeline logic.

See also: [`build_system`](@ref), [`build_flow`](@ref), [`integrate`](@ref), [`solve`](@ref), [`Flow`](@ref).
"""
module Solutions

# ==============================================================================
# External package imports
# ==============================================================================

import DocStringExtensions: TYPEDSIGNATURES, TYPEDEF
import CTBase.Exceptions
import SciMLBase
import RecipesBase

# ==============================================================================
# Internal submodule imports
# ==============================================================================

using ..Common
using ..Systems

# ==============================================================================
# Include files
# ==============================================================================

include(joinpath(@__DIR__, "vector_field_solution.jl"))
include(joinpath(@__DIR__, "building.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export VectorFieldSolution
export build_solution
export raw

end # module Solutions
