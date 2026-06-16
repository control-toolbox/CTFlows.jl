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
using ADTypes: ADTypes

# ==============================================================================
# Sibling imports (temporary - will be removed after full refactoring)
# ==============================================================================

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
export NotProvided
export ODEParameters, variable
export __is_autonomous, __is_variable, __variable, __unsafe, __is_inplace, __hvf_inplace, __variable_costate, __ad_backend
export deepvalue, real_norm, make_coerce

end # module Common
