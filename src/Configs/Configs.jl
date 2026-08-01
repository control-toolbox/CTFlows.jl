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
- [`CTFlows.Configs.AbstractConfig`](@extref): Base configuration type
- [`CTFlows.Configs.AbstractConfigWithMaC`](@extref): Configuration with mode and content traits
- [`CTFlows.Configs.StateEndPointConfig`](@extref): Point-to-point state integration
- [`CTFlows.Configs.StateTrajectoryConfig`](@extref): Trajectory state integration
- [`CTFlows.Configs.HamiltonianEndPointConfig`](@extref): Point-to-point Hamiltonian integration
- [`CTFlows.Configs.HamiltonianTrajectoryConfig`](@extref): Trajectory Hamiltonian integration
- [`CTFlows.Configs.AugmentedHamiltonianEndPointConfig`](@extref): Augmented Hamiltonian for variable costate

# Accessors
- [`CTFlows.Configs.tspan`](@extref): Time span `(t0, tf)`
- [`CTFlows.Configs.initial_state`](@extref): Initial state
- [`CTFlows.Configs.initial_costate`](@extref): Initial costate (Hamiltonian configs)
- [`CTFlows.Configs.initial_variable_costate`](@extref): Initial variable costate (augmented configs)
- [`CTFlows.Configs.mode_trait`](@extref): Integration mode trait
- [`CTBase.Traits.dynamics_trait`](@extref): Dynamics trait

See also: [`CTFlows.Flows.build_flow`](@extref), [`CTFlows.Trajectories.build_trajectory`](@extref).
"""
module Configs

# ==============================================================================
# External package imports
# ==============================================================================

using DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
using CTBase: Exceptions
using CTBase: Traits

# ==============================================================================
# Internal sibling-submodule imports
# ==============================================================================

using ..Display: Display

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
