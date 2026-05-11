"""
    Common

Shared utilities and types for CTFlows.

This module provides fallback implementations for grid invariance (IND) support:
- `deepvalue(x::Real)` — Base case for extracting primal values
- `real_norm(u::Real, t)` — Base case for internal norm computation

ForwardDiff-specific implementations are provided in `CTFlowsForwardDiff` when ForwardDiff is loaded.
"""
module Common
# ==============================================================================
# External package imports
# ==============================================================================

using Reexport
import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Exceptions
import CTModels.OCP

# ==============================================================================
# Includes
# ==============================================================================

include(joinpath(@__DIR__, "abstract_tag.jl"))
include(joinpath(@__DIR__, "configs.jl"))
include(joinpath(@__DIR__, "traits.jl"))
include(joinpath(@__DIR__, "ode_parameters.jl"))
include(joinpath(@__DIR__, "default.jl"))
include(joinpath(@__DIR__, "internal_norm.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

@reexport import CTModels.OCP: Autonomous, NonAutonomous, TimeDependence
@reexport import CTModels.OCP: is_autonomous, is_nonautonomous, is_variable, is_nonvariable, has_variable

export AbstractTag, AbstractModeTag, AbstractContentTag, PointTag, TrajectoryTag, StateTag, HamiltonianTag, AbstractConfig, AbstractPointConfig, AbstractTrajectoryConfig, AbstractStateConfig, AbstractHamiltonianConfig, StatePointConfig, StateTrajectoryConfig, HamiltonianPointConfig, HamiltonianTrajectoryConfig, tspan, initial_condition, initial_state, initial_costate
export VariableDependence, Fixed, NonFixed
export ODEParameters
export has_time_dependence_trait, has_variable_dependence_trait
export time_dependence, variable_dependence
export __is_autonomous, __is_variable, __variable, __unsafe
export deepvalue, real_norm

end # module Common
