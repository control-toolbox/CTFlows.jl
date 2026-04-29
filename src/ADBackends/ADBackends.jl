"""
    ADBackends

Automatic differentiation backend strategy types for CTFlows.

This module defines the `AbstractADBackend` type which inherits from
`CTSolvers.Strategies.AbstractStrategy`.

All AD backends implement the callable protocols: `ctgradient(backend, f, x)` and `ctjacobian(backend, f, x)`.

See also: [`AbstractADBackend`](@ref), [`ctgradient`](@ref), [`ctjacobian`](@ref).
"""
module ADBackends

# ==============================================================================
# External package imports
# ==============================================================================

import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Exceptions
import CTSolvers: CTSolvers

# ==============================================================================
# Internal submodule imports
# ==============================================================================

using ..Core

# ==============================================================================
# Include files
# ==============================================================================

include(joinpath(@__DIR__, "abstract_ad_backend.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export AbstractADBackend
export ctgradient, ctjacobian

end # module ADBackends
