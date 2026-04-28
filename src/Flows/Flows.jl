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

# ==============================================================================
# Internal submodule imports
# ==============================================================================

using ..Core
using ..Systems
using ..Integrators

# ==============================================================================
# Include files
# ==============================================================================

include(joinpath(@__DIR__, "abstract_flow.jl"))
include(joinpath(@__DIR__, "flow.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export AbstractFlow, Flow
export system, integrator

end # module Flows
