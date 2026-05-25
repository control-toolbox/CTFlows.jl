module Configs

# ==============================================================================
# External package imports
# ==============================================================================

import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Exceptions

# ==============================================================================
# Sibling imports
# ==============================================================================

import ..Traits: Traits

# ==============================================================================
# Includes
# ==============================================================================

include(joinpath(@__DIR__, "abstract.jl"))
include(joinpath(@__DIR__, "interface.jl"))
include(joinpath(@__DIR__, "implementations.jl"))
include(joinpath(@__DIR__, "concrete.jl"))
include(joinpath(@__DIR__, "show.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export AbstractConfig, AbstractConfigWithMaC
export AbstractPointConfig, AbstractTrajectoryConfig
export AbstractStateConfig, AbstractHamiltonianConfig, AbstractAugmentedHamiltonianConfig
export StatePointConfig, StateTrajectoryConfig
export HamiltonianPointConfig, HamiltonianTrajectoryConfig, AugmentedHamiltonianPointConfig
export tspan, initial_condition, initial_state, initial_costate, initial_variable_costate
export initial_time, final_time, mode_trait, content_trait

end # module Configs
