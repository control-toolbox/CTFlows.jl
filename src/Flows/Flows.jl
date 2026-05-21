"""
    Flows

Flow types and contracts for CTFlows.

This module defines the `AbstractFlow` type and its required methods:
- `(flow)(t0, x0, tf)`: callable interface for state integration
- `(flow)(t0, x0, p0, tf)`: callable interface for state + costate integration
- `system`: returns the system associated with the flow
- `integrator`: returns the integrator used by the flow
"""
module Flows

# 1. External-package imports (qualified, pollution-free)
import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Exceptions
using CTSolvers: CTSolvers

# ==============================================================================
# Internal sibling-submodule imports
# ==============================================================================

using ..Common
using ..Data
using ..Differentiation
using ..Systems
using ..Integrators
using ..Solutions

# ==============================================================================
# Include files
# ==============================================================================

include(joinpath(@__DIR__, "abstract_flow.jl"))
include(joinpath(@__DIR__, "flow.jl"))
include(joinpath(@__DIR__, "building.jl"))
include(joinpath(@__DIR__, "calling.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export AbstractFlow, AbstractStateFlow, AbstractHamiltonianFlow, Flow, StateFlow, HamiltonianFlow
export system, integrator
export call
export build_flow
export prepare_cache

end # module Flows
