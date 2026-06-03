"""
    Integrators

ODE integrator strategy types for CTFlows.

This module defines the `AbstractIntegrator` type which inherits from
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

import ..Common: Common
import ..Configs: Configs
import ..Systems: Systems
using CTSolvers: CTSolvers

# ==============================================================================
# Include files
# ==============================================================================

include(joinpath(@__DIR__, "integration_result.jl"))
include(joinpath(@__DIR__, "abstract_integrator.jl"))
include(joinpath(@__DIR__, "sciml.jl"))
include(joinpath(@__DIR__, "building.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export AbstractIntegrator, AbstractSciMLIntegrator,SciML, SciMLTag, Tsit5Tag
export AbstractIntegrationResult, final_state, times, evaluate_at
export build_sciml_integrator, build_integrator
export build_problem, solve_problem, merge

end # module Integrators
