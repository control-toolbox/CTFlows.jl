"""
    Common

Shared utilities and types for CTFlows.

This module provides:
- `ODEParameters` and its `variable` accessor — the wrapper transiting in SciML's parameter
  slot, read by the system right-hand-side functors;
- package-local default values for flow-call keyword arguments (`__variable`, `__unsafe`,
  `__hvf_inplace`, `__variable_costate`).

The grid-invariance helpers (`deepvalue`/`real_norm`) now live in
[`CTSolvers.Integrators`](@extref) and are no longer part of this module.
"""
module Common
# ==============================================================================
# External package imports
# ==============================================================================

import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Core

# ==============================================================================
# Includes
# ==============================================================================

include(joinpath(@__DIR__, "ode_parameters.jl"))
include(joinpath(@__DIR__, "default.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export ODEParameters, variable
export __variable, __unsafe, __hvf_inplace, __variable_costate

end # module Common
