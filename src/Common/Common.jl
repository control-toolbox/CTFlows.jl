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
include(joinpath(@__DIR__, "abstract_trait.jl"))
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

export AbstractTag
export AbstractTrait, AbstractModeTrait, AbstractContentTrait, AbstractMutabilityTrait
export PointTrait, TrajectoryTrait, StateTrait, HamiltonianTrait
export InPlace, OutOfPlace
export AbstractConfig, AbstractPointConfig, AbstractTrajectoryConfig, AbstractStateConfig, AbstractHamiltonianConfig
export StatePointConfig, StateTrajectoryConfig, HamiltonianPointConfig, HamiltonianTrajectoryConfig
export tspan, initial_condition, initial_state, initial_costate
export VariableDependence, Fixed, NonFixed
export ODEParameters, variable
export has_time_dependence_trait, has_variable_dependence_trait, has_mutability_trait
export time_dependence, variable_dependence, mutability_trait
export is_inplace, is_outofplace
export __is_autonomous, __is_variable, __variable, __unsafe, __is_inplace, __state_dimension
export deepvalue, real_norm

end # module Common
