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

import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Exceptions
using ADTypes: ADTypes

# ==============================================================================
# Re-exported from CTBase.Core (moved out of CTFlows)
# ==============================================================================

# `AbstractTag`, `AbstractCache` and `make_coerce` now live in CTBase.Core.
# They are re-exported here so existing `Common.<symbol>` call sites are unchanged.
import CTBase.Core: AbstractTag, AbstractCache, make_coerce

# ==============================================================================
# Includes
# ==============================================================================

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
