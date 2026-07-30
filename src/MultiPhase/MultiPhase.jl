"""
    MultiPhase

Multi-phase flow concatenation and sequential integration.

This module provides types and operators for concatenating flows with switching times
and optional jumps, implementing exact sequential integration.
"""
module MultiPhase

# 1. External-package imports (qualified, pollution-free)
using DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
using CTBase: Exceptions
using CTBase: Strategies
using CTBase: Options
using CTBase: Traits

# ==============================================================================
# Internal sibling-submodule imports
# ==============================================================================

using ..Display: Display
using ..Configs: Configs
using ..Systems: Systems
using ..Integrators: Integrators
using ..Flows: Flows
using ..Trajectories: Trajectories

# ==============================================================================
# Include files
# ==============================================================================

include(joinpath(@__DIR__, "multiphase_flow.jl"))
include(joinpath(@__DIR__, "concatenation.jl"))
include(joinpath(@__DIR__, "calling.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export MultiPhaseFlow, MultiPhaseStateFlow, MultiPhaseHamiltonianFlow, AnyMultiPhaseFlow
export n_phases, get_flow, get_switching_time, get_jump
export get_flows, get_switching_times, get_jumps

end # module MultiPhase
