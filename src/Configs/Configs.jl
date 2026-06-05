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
- [`AbstractConfig`](@ref): Base configuration type
- [`AbstractConfigWithMaC`](@ref): Configuration with mode and content traits
- [`StatePointConfig`](@ref): Point-to-point state integration
- [`StateTrajectoryConfig`](@ref): Trajectory state integration
- [`HamiltonianPointConfig`](@ref): Point-to-point Hamiltonian integration
- [`HamiltonianTrajectoryConfig`](@ref): Trajectory Hamiltonian integration
- [`AugmentedHamiltonianPointConfig`](@ref): Augmented Hamiltonian for variable costate

# Accessors
- [`tspan`](@ref): Time span `(t0, tf)`
- [`initial_state`](@ref): Initial state
- [`initial_costate`](@ref): Initial costate (Hamiltonian configs)
- [`initial_variable_costate`](@ref): Initial variable costate (augmented configs)
- [`mode_trait`](@ref): Integration mode trait
- [`dynamics_trait`](@ref): Dynamics trait

See also: [`CTFlows.Flows.build_flow`](@ref), [`CTFlows.Solutions.build_solution`](@ref).
"""
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
export initial_time, final_time, mode_trait, dynamics_trait

end # module Configs
