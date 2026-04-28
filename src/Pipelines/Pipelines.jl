"""
    Pipelines

Pipeline functions for CTFlows.

This module provides high-level pipeline functions that operate on abstract types:
- `build_system`: Build a system from input using a modeler and AD backend
- `build_flow`: Build a flow from a system and integrator (or from input + modeler + integrator + AD backend)
- `integrate`: Integrate a flow over a time span
- `build_solution`: Package an ODE solution into the appropriate result type
- `solve`: Solve an ODE problem using a flow (integrate + build_solution)

All pipelines are written using only the abstract types, allowing concrete implementations
to plug in without changing the pipeline logic.

See also: [`build_system`](@ref), [`build_flow`](@ref), [`integrate`](@ref), [`build_solution`](@ref), [`solve`](@ref).
"""
module Pipelines

# ==============================================================================
# External package imports
# ==============================================================================

import DocStringExtensions: TYPEDSIGNATURES

# ==============================================================================
# Internal submodule imports
# ==============================================================================

using ..Core
using ..Systems
using ..Flows
using ..Modelers
using ..Integrators
using ..ADBackends

# ==============================================================================
# Include files
# ==============================================================================

include(joinpath(@__DIR__, "build_system.jl"))
include(joinpath(@__DIR__, "build_flow.jl"))
include(joinpath(@__DIR__, "integrate.jl"))
include(joinpath(@__DIR__, "solve.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export build_system, build_flow, integrate, build_solution, solve

end # module Pipelines
