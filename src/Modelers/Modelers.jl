"""
    Modelers

Flow modeler strategy types for CTFlows.

This module defines the `AbstractFlowModeler` type which inherits from
`CTSolvers.Strategies.AbstractStrategy`.
"""
module Modelers

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

include(joinpath(@__DIR__, "abstract_flow_modeler.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export AbstractFlowModeler

end # module Modelers
