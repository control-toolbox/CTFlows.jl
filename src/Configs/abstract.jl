# =============================================================================
# Abstract Types
# =============================================================================

"""
$(TYPEDEF)

Abstract configuration type for integration problems.

Marker type for dispatch on configuration objects. Concrete subtypes define
specific integration scenarios (e.g., point-to-point, trajectory, costate).

The type parameters encode:
- `X0`: Type of the initial condition (scalar `Number` or vector `AbstractVector`)
- `Mode`: Integration mode (`PointTrait` or `TrajectoryTrait`)
- `Dyn`: Dynamics type (`StateDynamics` or `HamiltonianDynamics`)

This enables compile-time dispatch on mode and content without runtime type tests.

# Interface Requirements

All subtypes must implement:
- `tspan(config)`: Return the time span as a tuple `(t0, tf)`.

# Example
\`\`\`julia-repl
julia> using CTFlows.Configs

julia> StatePointConfig <: Configs.AbstractConfig
true

julia> StatePointConfig <: Configs.AbstractPointConfig
true

julia> StatePointConfig <: Configs.AbstractStateConfig
true
\`\`\`

See also: [`CTFlows.Configs.AbstractPointConfig`](@ref), [`CTFlows.Configs.AbstractTrajectoryConfig`](@ref), [`CTFlows.Configs.AbstractStateConfig`](@ref), [`CTFlows.Configs.AbstractHamiltonianConfig`](@ref).
"""
abstract type AbstractConfig{X0} end

# =============================================================================
# Type Aliases for Convenient Dispatch
# =============================================================================

"""
$(TYPEDEF)

Abstract configuration type with mode and content traits.

Extends `AbstractConfig` with additional type parameters for compile-time dispatch
on integration mode (point vs trajectory) and content type (state, Hamiltonian, augmented Hamiltonian).

# Type Parameters
- `X0`: Type of the initial condition (scalar `Number` or vector `AbstractVector`)
- `Mode <: AbstractModeTrait`: Integration mode trait (`PointTrait` or `TrajectoryTrait`)
- `Dyn <: AbstractDynamicsTrait`: Dynamics trait (`StateDynamics`, `HamiltonianDynamics`, or `AugmentedHamiltonianDynamics`)

# Interface Requirements

All subtypes must implement:
- `tspan(config)`: Return the time span as a tuple `(t0, tf)`.

# Example
\`\`\`julia-repl
julia> using CTFlows.Configs

julia> StatePointConfig <: Configs.AbstractConfigWithMaC
true

julia> HamiltonianPointConfig <: Configs.AbstractConfigWithMaC
true
\`\`\`

See also: [`CTFlows.Configs.AbstractConfig`](@ref), [`CTFlows.Configs.AbstractPointConfig`](@ref), [`CTFlows.Configs.AbstractTrajectoryConfig`](@ref), [`CTFlows.Configs.AbstractStateConfig`](@ref), [`CTFlows.Configs.AbstractHamiltonianConfig`](@ref), [`CTFlows.Configs.AbstractAugmentedHamiltonianConfig`](@ref).
"""
abstract type AbstractConfigWithMaC{X0, Mode<:Traits.AbstractModeTrait, Dyn<:Traits.AbstractDynamicsTrait} <: AbstractConfig{X0} end

"""
$(TYPEDSIGNATURES)

Return the mode trait type of a configuration.

Extracts the `Mode` type parameter from the configuration's parametric type,
enabling trait-based dispatch on the integration mode (point vs trajectory).

# Arguments
- `::AbstractConfigWithMaC{X0, Mode, Content}`: Any concrete configuration subtype.

# Returns
- `Type{Mode}`: The mode trait type (e.g., `PointTrait` or `TrajectoryTrait`).

# Example
\`\`\`julia
config = Configs.HamiltonianPointConfig(0.0, [1.0], [0.5], 1.0)
Configs.mode_trait(config) === Traits.PointTrait  # true
\`\`\`

See also: [`CTFlows.Configs.AbstractConfigWithMaC`](@ref), [`CTFlows.Traits.PointTrait`](@ref), [`CTFlows.Traits.TrajectoryTrait`](@ref), [`CTFlows.Configs.dynamics_trait`](@ref).
"""
function mode_trait(::AbstractConfigWithMaC{X0, Mode, Dyn}) where {X0, Mode, Dyn}
    return Mode
end

"""
$(TYPEDSIGNATURES)

Return the dynamics trait type of a configuration.

Extracts the `Dyn` type parameter from the configuration's parametric type,
enabling trait-based dispatch on the integration dynamics (state, Hamiltonian, augmented Hamiltonian).

# Arguments
- `::AbstractConfigWithMaC{X0, Mode, Dyn}`: Any concrete configuration subtype.

# Returns
- `Type{Dyn}`: The dynamics trait type (e.g., `StateDynamics`, `HamiltonianDynamics`, or `AugmentedHamiltonianDynamics`).

# Example
\`\`\`julia
config = Configs.HamiltonianPointConfig(0.0, [1.0], [0.5], 1.0)
Configs.dynamics_trait(config) === Traits.HamiltonianDynamics  # true
\`\`\`

See also: [`CTFlows.Configs.AbstractConfigWithMaC`](@ref), [`CTFlows.Traits.StateDynamics`](@ref), [`CTFlows.Traits.HamiltonianDynamics`](@ref), [`CTFlows.Traits.AugmentedHamiltonianDynamics`](@ref), [`CTFlows.Configs.mode_trait`](@ref).
"""
function dynamics_trait(::AbstractConfigWithMaC{X0, Mode, Dyn}) where {X0, Mode, Dyn}
    return Dyn
end

"""
$(TYPEDEF)

Alias for point integration mode configurations.

Matches any `AbstractConfig` with `PointTrait` as the mode parameter.
"""
const AbstractPointConfig{X0, C} = AbstractConfigWithMaC{X0, Traits.PointTrait, C}

"""
$(TYPEDEF)

Alias for trajectory integration mode configurations.

Matches any `AbstractConfig` with `TrajectoryTrait` as the mode parameter.
"""
const AbstractTrajectoryConfig{X0, C} = AbstractConfigWithMaC{X0, Traits.TrajectoryTrait, C}

"""
$(TYPEDEF)

Alias for state content configurations.

Matches any `AbstractConfig` with `StateDynamics` as the dynamics parameter.
"""
const AbstractStateConfig{X0, M} = AbstractConfigWithMaC{X0, M, Traits.StateDynamics}

"""
$(TYPEDEF)

Alias for Hamiltonian content configurations.

Matches any `AbstractConfig` with `HamiltonianDynamics` as the dynamics parameter.
"""
const AbstractHamiltonianConfig{X0, M} = AbstractConfigWithMaC{X0, M, Traits.HamiltonianDynamics}

"""
$(TYPEDEF)

Type alias for augmented Hamiltonian configurations, which include state, costate, and augmented variable initial conditions.

# Type Parameters
- `X0`: Type of the initial condition (typically a vector concatenating state, costate, and augmented variable).
- `M`: Type of the mutability trait (`InPlace` or `OutOfPlace`).

# Notes
- Augmented Hamiltonian configurations are used for systems where the Hamiltonian depends on an additional variable (e.g., a control parameter or optimization variable).
- The initial condition typically has the form `vcat(x0, p0, pv0)` where `x0` is the initial state, `p0` is the initial costate, and `pv0` is the initial augmented variable.
- Subtypes [`CTFlows.Configs.AbstractConfigWithMaC`](@ref) with [`CTFlows.Traits.AugmentedHamiltonianDynamics`](@ref).
- Used in conjunction with [`CTFlows.Systems.HamiltonianSystem`](@ref) for automatic differentiation-based Hamiltonian integration.

See also: [`CTFlows.Configs.AbstractHamiltonianConfig`](@ref), [`CTFlows.Traits.AugmentedHamiltonianDynamics`](@ref), [`CTFlows.Systems.HamiltonianSystem`](@ref).
"""
const AbstractAugmentedHamiltonianConfig{X0, M} = AbstractConfigWithMaC{X0, M, Traits.AugmentedHamiltonianDynamics}
