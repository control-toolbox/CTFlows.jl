"""
    Pipelines

Pipeline functions for CTFlows.

This module provides high-level pipeline functions that operate on abstract types:
- `build_system`: Build a system from a vector field
- `build_flow`: Build a flow from a system and integrator
- `integrate`: Integrate a flow using a configuration object
- `solve`: Solve an ODE problem using a flow (alias for integrate)
- `Flow`: High-level constructor for Flow from vector field data

All pipelines are written using only the abstract types, allowing concrete implementations
to plug in without changing the pipeline logic.

See also: [`build_system`](@ref), [`build_flow`](@ref), [`integrate`](@ref), [`solve`](@ref), [`Flow`](@ref).
"""
module Pipelines

# ==============================================================================
# External package imports
# ==============================================================================

import DocStringExtensions: TYPEDSIGNATURES
import CTBase.Exceptions

# ==============================================================================
# Internal submodule imports
# ==============================================================================

using ..Common
using ..Systems
using ..Integrators
using ..Flows

# ==============================================================================
# Include files
# ==============================================================================

include(joinpath(@__DIR__, "build_system.jl"))
include(joinpath(@__DIR__, "build_flow.jl"))
include(joinpath(@__DIR__, "solve.jl"))
include(joinpath(@__DIR__, "flow_constructor.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export build_system, build_flow, solve

end # module Pipelines
