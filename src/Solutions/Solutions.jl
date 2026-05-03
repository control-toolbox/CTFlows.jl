"""
    Solutions

Solution types and solution building for CTFlows.

This module provides:
- `VectorFieldSolution`: Solution type wrapping raw ODE solutions
- `build_solution`: Solution building functions for different configuration types
- `raw`: Accessor for the underlying ODE solution
- `plot`: Plotting functionality for solutions

See also: [`VectorFieldSolution`](@ref), [`build_solution`](@ref), [`raw`](@ref), [`plot`](@ref).
"""
module Solutions

# ==============================================================================
# External package imports
# ==============================================================================

import DocStringExtensions: TYPEDSIGNATURES, TYPEDEF
import CTBase.Exceptions
import SciMLBase
import RecipesBase: RecipesBase, plot

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
export plot

end # module Solutions
