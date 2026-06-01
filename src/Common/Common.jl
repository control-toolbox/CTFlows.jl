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

import Base: only
import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Exceptions
import CTModels.OCP

# ==============================================================================
# Sibling imports (temporary - will be removed after full refactoring)
# ==============================================================================

import ..Traits: Traits
import ..Configs: Configs

# ==============================================================================
# Includes
# ==============================================================================

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "abstract_tag.jl"))
include(joinpath(@__DIR__, "abstract_cache.jl"))
include(joinpath(@__DIR__, "ode_parameters.jl"))
include(joinpath(@__DIR__, "default.jl"))
include(joinpath(@__DIR__, "internal_norm.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export AbstractTag
export AbstractCache
# Config types moved to Configs module
# export AbstractConfig, AbstractPointConfig, AbstractTrajectoryConfig, AbstractStateConfig, AbstractHamiltonianConfig, AbstractAugmentedHamiltonianConfig
# export StatePointConfig, StateTrajectoryConfig, HamiltonianPointConfig, HamiltonianTrajectoryConfig, AugmentedHamiltonianPointConfig
# export tspan, initial_condition, initial_state, initial_costate, initial_variable_costate, initial_time, final_time
export NotProvided
export ODEParameters, variable
export __is_autonomous, __is_variable, __variable, __unsafe, __is_inplace, __hvf_inplace, _variable_costate
export deepvalue, real_norm, make_coerce

end # module Common
