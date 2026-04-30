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
include(joinpath(@__DIR__, "traits.jl"))
include(joinpath(@__DIR__, "default.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export AbstractTag, AbstractConfig, PointConfig, TrajectoryConfig, tspan
export TimeDependence, Autonomous, NonAutonomous
export VariableDependence, Fixed, NonFixed
export has_time_dependence_trait, has_variable_dependence_trait
export time_dependence, variable_dependence
export is_autonomous, is_nonautonomous, is_variable, is_nonvariable, has_variable

end # module Common
