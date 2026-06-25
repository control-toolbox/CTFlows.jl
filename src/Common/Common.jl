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
using ADTypes: ADTypes

# ==============================================================================
# Includes
# ==============================================================================

include(joinpath(@__DIR__, "ode_parameters.jl"))
include(joinpath(@__DIR__, "default.jl"))
include(joinpath(@__DIR__, "internal_norm.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export NotProvided
export ODEParameters, variable
export __variable, __unsafe, __hvf_inplace, __variable_costate, __ad_backend
export deepvalue, real_norm

end # module Common
