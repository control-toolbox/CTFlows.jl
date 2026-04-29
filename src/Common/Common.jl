"""
    Common

Shared utilities and types for CTFlows.
"""
module Common
# ==============================================================================
# External package imports
# ==============================================================================

import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Exceptions

# ==============================================================================
# Includes
# ==============================================================================

include(joinpath(@__DIR__, "abstract_tag.jl"))
include(joinpath(@__DIR__, "configs.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export AbstractTag, AbstractConfig, PointConfig, TrajectoryConfig

end # module Common
