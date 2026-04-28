"""
    Integrators

ODE integrator strategy types for CTFlows.

This module defines the `AbstractODEIntegrator` type which inherits from
`CTSolvers.Strategies.AbstractStrategy`.
"""
module Integrators

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

include(joinpath(@__DIR__, "abstract_ode_integrator.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export AbstractODEIntegrator

end # module Integrators
