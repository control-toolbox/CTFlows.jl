"""
    MultiPhase

Multi-phase flow concatenation and sequential integration.

This module provides types and operators for concatenating flows with switching times
and optional jumps, implementing exact sequential integration.
"""
module MultiPhase

# 1. External-package imports (qualified, pollution-free)
import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Exceptions
import CTSolvers.Strategies
import CTSolvers.Options

# ==============================================================================
# Internal sibling-submodule imports
# ==============================================================================

using ..Common
using ..Systems
using ..Integrators
using ..Flows

# ==============================================================================
# Include files
# ==============================================================================

include(joinpath(@__DIR__, "multiphase_flow.jl"))
include(joinpath(@__DIR__, "concatenation.jl"))
include(joinpath(@__DIR__, "calling.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export MultiPhaseStateFlow, MultiPhaseHamiltonianFlow

end # module MultiPhase
