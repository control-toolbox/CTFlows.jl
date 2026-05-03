"""
    Solutions

Solution types and solution building for CTFlows.

This module provides:
- `AbstractIntegrationResult`: Abstraction for raw ODE integration results
- `VectorFieldSolution`: Solution type wrapping integration results
- `build_solution`: Solution building functions for different configuration types
- `final_state`, `times`, `evaluate_at`: Semantic accessors for integration results
- `state`, `time_grid`: Semantic accessors for VectorFieldSolution
- `plot`: Plotting functionality for solutions

See also: [`CTFlows.Solutions.AbstractIntegrationResult`](@ref), [`CTFlows.Solutions.VectorFieldSolution`](@ref), [`CTFlows.Solutions.build_solution`](@ref), [`CTFlows.Solutions.plot`](@ref).
"""
module Solutions

# ==============================================================================
# External package imports
# ==============================================================================

import DocStringExtensions: TYPEDSIGNATURES, TYPEDEF
import CTBase.Exceptions
import RecipesBase: RecipesBase, plot

# ==============================================================================
# Internal submodule imports
# ==============================================================================

using ..Common
using ..Systems

# ==============================================================================
# Include files
# ==============================================================================

include(joinpath(@__DIR__, "integration_result.jl"))
include(joinpath(@__DIR__, "vector_field_solution.jl"))
include(joinpath(@__DIR__, "building.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export AbstractIntegrationResult, final_state, times, evaluate_at
export state, time_grid
export VectorFieldSolution
export build_solution
export plot

end # module Solutions
