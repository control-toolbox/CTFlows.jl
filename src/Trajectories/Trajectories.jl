"""
    Trajectories

Trajectory types and trajectory building for CTFlows.

This module provides:
- `AbstractIntegrationResult`: Abstraction for raw ODE integration results
- `VectorFieldTrajectory`: Trajectory type wrapping integration results
- `build_trajectory`: Trajectory building functions for different configuration types
- `final_state`, `times`, `evaluate_at`: Semantic accessors for integration results
- `state`, `time_grid`: Semantic accessors for VectorFieldTrajectory
- `plot`: Plotting functionality for trajectories

See also: [`CTSolvers.Integrators.AbstractIntegrationResult`](@extref), [`CTFlows.Trajectories.VectorFieldTrajectory`](@ref), [`CTFlows.Trajectories.build_trajectory`](@ref), `plot`.
"""
module Trajectories

# ==============================================================================
# External package imports
# ==============================================================================

import DocStringExtensions: TYPEDSIGNATURES, TYPEDEF
import CTBase.Core
import CTBase.Data
import CTBase.Exceptions
import CTBase.Traits
import RecipesBase: RecipesBase, plot

# ==============================================================================
# Internal submodule imports
# ==============================================================================

import ..Display: Display
import ..Configs: Configs
import ..Systems: Systems
import ..Integrators: Integrators

# ==============================================================================
# Include files
# ==============================================================================

include(joinpath(@__DIR__, "vector_field_trajectory.jl"))
include(joinpath(@__DIR__, "hamiltonian_vector_field_trajectory.jl"))
include(joinpath(@__DIR__, "controlled_trajectory.jl"))
include(joinpath(@__DIR__, "building.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export AbstractVectorFieldTrajectory, VectorFieldTrajectory
export AbstractHamiltonianVectorFieldTrajectory, HamiltonianVectorFieldTrajectory
export ControlledTrajectory, ControlProjection
export StateProjection, CostateProjection
export state, time_grid
export costate
export control, objective
export build_trajectory
export plot

end # module Trajectories
