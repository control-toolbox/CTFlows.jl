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
include(joinpath(@__DIR__, "helpers.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

@reexport import CTModels.OCP: Autonomous, NonAutonomous, TimeDependence
@reexport import CTModels.OCP: is_autonomous, is_nonautonomous, is_variable, is_nonvariable, has_variable

export AbstractTag
export AbstractTrait, AbstractModeTrait, AbstractContentTrait, AbstractMutabilityTrait, AbstractADTrait, AbstractVariableCostateCapability
export PointTrait, TrajectoryTrait, StateTrait, HamiltonianTrait, AugmentedHamiltonianTrait, content_trait, mode_trait
export InPlace, OutOfPlace
export WithAD, WithoutAD, SupportsVariableCostate, NoVariableCostate
export AbstractCache
export AbstractConfig, AbstractPointConfig, AbstractTrajectoryConfig, AbstractStateConfig, AbstractHamiltonianConfig, AbstractAugmentedHamiltonianConfig
export StatePointConfig, StateTrajectoryConfig, HamiltonianPointConfig, HamiltonianTrajectoryConfig, AugmentedHamiltonianPointConfig
export tspan, initial_condition, initial_state, initial_costate, initial_variable_costate, initial_time, final_time
export VariableDependence, Fixed, NonFixed, NotProvided
export ODEParameters, variable, cache
export has_time_dependence_trait, has_variable_dependence_trait, has_mutability_trait
export time_dependence, variable_dependence, mutability_trait
export ad_trait, variable_costate_trait
export is_inplace, is_outofplace
export __is_autonomous, __is_variable, __variable, __unsafe, __is_inplace, __state_dimension, _variable_costate
export deepvalue, real_norm, scalarize

end # module Common
