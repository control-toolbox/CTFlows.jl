"""
    Trajectories

Trajectory types and trajectory building for CTFlows.

This module provides:
- `AbstractIntegrationResult`: Abstraction for raw ODE integration results
- `VectorFieldTrajectory`: Trajectory type wrapping integration results
- `build_trajectory`: Trajectory building functions for different configuration types
- `final_state`, `times`, `evaluate_at`: Semantic accessors for integration results
- `state`, `control`, `costate`, `objective`, `time_grid`: methods on the
  [`CTModels.Components`](@extref) generics, contributed here for `VectorFieldTrajectory`,
  `HamiltonianVectorFieldTrajectory` and `StateFlowTrajectory`
- `Trajectories.plot`: plotting for trajectories via the Plots extension (a `RecipesBase.plot`
  method; not re-exported — call it qualified or load `Plots`)

See also: [`CTSolvers.Integrators.AbstractIntegrationResult`](@extref), [`CTFlows.Trajectories.VectorFieldTrajectory`](@extref), [`CTFlows.Trajectories.build_trajectory`](@extref).
"""
module Trajectories

# ==============================================================================
# External package imports
# ==============================================================================

using DocStringExtensions: TYPEDSIGNATURES, TYPEDEF
using CTBase: Core
using CTBase: Data
using CTBase: Exceptions
using CTBase: Traits
using CTModels: Components
using RecipesBase: RecipesBase, plot

# `Components.state`/`control`/`costate`/`objective`/`time_grid` are re-homed here
# (const-bound) so that `Trajectories.<symbol>` resolves and can be exported below;
# methods are contributed for VectorFieldTrajectory / HamiltonianVectorFieldTrajectory /
# StateFlowTrajectory in the included files.
const state = Components.state
const control = Components.control
const costate = Components.costate
const objective = Components.objective
const time_grid = Components.time_grid

# ==============================================================================
# Internal submodule imports
# ==============================================================================

using ..Display: Display
using ..Configs: Configs
using ..Systems: Systems
using ..Integrators: Integrators

# ==============================================================================
# Include files
# ==============================================================================

include(joinpath(@__DIR__, "vector_field_trajectory.jl"))
include(joinpath(@__DIR__, "hamiltonian_vector_field_trajectory.jl"))
include(joinpath(@__DIR__, "state_flow_trajectory.jl"))
include(joinpath(@__DIR__, "building.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export AbstractVectorFieldTrajectory, VectorFieldTrajectory
export AbstractHamiltonianVectorFieldTrajectory, HamiltonianVectorFieldTrajectory
export StateFlowTrajectory, ControlProjection
export StateProjection, CostateProjection
export state, time_grid
export costate
export control, objective
export build_trajectory

end # module Trajectories
