"""
    MultiPhase

Multi-phase flow concatenation and sequential integration.

This module provides types and operators for concatenating flows with switching times
and optional jumps, implementing exact sequential integration.
"""
module MultiPhase

# 1. External-package imports (qualified, pollution-free)
using DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
using CTBase: Core
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

# The switching times and the phase labels of a flow are read with the functions that read
# them on a solution (`CTModels.Solutions`, re-homed in `Trajectories`): the same name for a
# flow and for what it returns (control-toolbox/CTFlows.jl#544).
const switching_times = Trajectories.switching_times
const phase_labels = Trajectories.phase_labels

# ==============================================================================
# Include files
# ==============================================================================

include(joinpath(@__DIR__, "multiphase_flow.jl"))
include(joinpath(@__DIR__, "concatenation.jl"))
include(joinpath(@__DIR__, "calling.jl"))
include(joinpath(@__DIR__, "removed.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export MultiPhaseFlow, MultiPhaseStateFlow, MultiPhaseHamiltonianFlow, AnyMultiPhaseFlow
export n_phases, phase_flows, switching_times, jumps, phase_labels
# removed names, kept to say what replaces them (#544)
export get_flow, get_switching_time, get_jump
export get_flows, get_switching_times, get_jumps, get_labels

end # module MultiPhase
