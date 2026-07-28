"""
    Configs

Configuration types for integration problems in CTFlows.

This module provides the configuration type hierarchy that specifies integration
scenarios including:
- Integration mode: point-to-point vs trajectory
- Dynamics type: state-only vs Hamiltonian (state + costate)
- Time dependence: autonomous vs non-autonomous
- Variable dependence: fixed vs non-fixed (for optimal control)

Configuration types encode these choices as type parameters for compile-time dispatch.

# Main Types
- [`CTFlows.Configs.AbstractConfig`](@ref): Base configuration type
- [`CTFlows.Configs.AbstractConfigWithMaC`](@ref): Configuration with mode and content traits
- [`CTFlows.Configs.StateEndPointConfig`](@ref): Point-to-point state integration
- [`CTFlows.Configs.StateTrajectoryConfig`](@ref): Trajectory state integration
- [`CTFlows.Configs.HamiltonianEndPointConfig`](@ref): Point-to-point Hamiltonian integration
- [`CTFlows.Configs.HamiltonianTrajectoryConfig`](@ref): Trajectory Hamiltonian integration
- [`CTFlows.Configs.AugmentedHamiltonianEndPointConfig`](@ref): Augmented Hamiltonian for variable costate

# Accessors
- [`CTFlows.Configs.tspan`](@ref): Time span `(t0, tf)`
- [`CTFlows.Configs.initial_state`](@ref): Initial state
- [`CTFlows.Configs.initial_costate`](@ref): Initial costate (Hamiltonian configs)
- [`CTFlows.Configs.initial_variable_costate`](@ref): Initial variable costate (augmented configs)
- [`CTFlows.Configs.mode_trait`](@ref): Integration mode trait
- [`CTBase.Traits.dynamics_trait`](@extref): Dynamics trait

See also: [`CTFlows.Flows.build_flow`](@ref), [`CTFlows.Trajectories.build_trajectory`](@ref).
"""
module Configs

# ==============================================================================
# External package imports
# ==============================================================================

import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Exceptions
import CTBase.Traits

# ==============================================================================
# Internal sibling-submodule imports
# ==============================================================================

import ..Display: Display

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
export AbstractEndPointConfig, AbstractTrajectoryConfig
export AbstractStateConfig, AbstractHamiltonianConfig, AbstractAugmentedHamiltonianConfig
export StateEndPointConfig, StateTrajectoryConfig
export HamiltonianEndPointConfig,
    HamiltonianTrajectoryConfig, AugmentedHamiltonianEndPointConfig
export tspan, initial_condition, initial_state, initial_costate, initial_variable_costate
export initial_time, final_time, mode_trait

end # module Configs
