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

# ==============================================================================
# Internal sibling-submodule imports
# ==============================================================================

using ..Common
using ..Systems
using CTSolvers: CTSolvers

# ==============================================================================
# Include files
# ==============================================================================

include(joinpath(@__DIR__, "abstract_ode_integrator.jl"))
include(joinpath(@__DIR__, "sciml_integrator.jl"))
include(joinpath(@__DIR__, "build_integrator.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export AbstractODEIntegrator, SciMLIntegrator, SciMLTag
export build_sciml_integrator, build_integrator

end # module Integrators
