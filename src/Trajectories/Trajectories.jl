"""
    Trajectories

Trajectory types and trajectory building for CTFlows.

This module provides:
- `AbstractIntegrationResult`: Abstraction for raw ODE integration results
- `VectorFieldSolution`: Trajectory type wrapping integration results
- `build_solution`: Trajectory building functions for different configuration types
- `final_state`, `times`, `evaluate_at`: Semantic accessors for integration results
- `state`, `time_grid`: Semantic accessors for VectorFieldSolution
- `plot`: Plotting functionality for trajectories

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Trajectories.VectorFieldSolution`](@ref), [`CTFlows.Trajectories.build_solution`](@ref), `plot`.
"""
module Trajectories

# ==============================================================================
# External package imports
# ==============================================================================

import DocStringExtensions: TYPEDSIGNATURES, TYPEDEF
import CTBase.Exceptions
import RecipesBase: RecipesBase, plot

# ==============================================================================
# Internal submodule imports
# ==============================================================================

import ..Common: Common
import ..Configs: Configs
import ..Systems: Systems
import ..Integrators: Integrators
import ..Traits: Traits

# ==============================================================================
# Include files
# ==============================================================================

include(joinpath(@__DIR__, "vector_field_solution.jl"))
include(joinpath(@__DIR__, "hamiltonian_vector_field_solution.jl"))
include(joinpath(@__DIR__, "building.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export AbstractVectorFieldSolution, VectorFieldSolution
export AbstractHamiltonianVectorFieldSolution, HamiltonianVectorFieldSolution
export StateProjection, CostateProjection
export state, time_grid
export costate
export build_solution
export plot

end # module Trajectories
