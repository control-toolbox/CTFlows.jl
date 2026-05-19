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
- `Content`: Content type (`StateTrait` or `HamiltonianTrait`)

This enables compile-time dispatch on mode and content without runtime type tests.

# Interface Requirements

All subtypes must implement:
- `tspan(config)`: Return the time span as a tuple `(t0, tf)`.

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> StatePointConfig <: Common.AbstractConfig
true

julia> StatePointConfig <: Common.AbstractPointConfig
true

julia> StatePointConfig <: Common.AbstractStateConfig
true
\`\`\`

See also: [`CTFlows.Common.AbstractPointConfig`](@ref), [`CTFlows.Common.AbstractTrajectoryConfig`](@ref), [`CTFlows.Common.AbstractStateConfig`](@ref), [`CTFlows.Common.AbstractHamiltonianConfig`](@ref).
"""
abstract type AbstractConfig{X0} end

# =============================================================================
# Interface: stubs
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the time span for a configuration (stub method).

This is a stub method on the base `AbstractConfig` type that throws
`NotImplemented`. Concrete subtypes should implement this method to return
their specific time span format.

# Arguments
- `c::AbstractConfig`: The configuration.

# Throws
- `Exceptions.NotImplemented`: Always thrown for the base abstract type.

See also: [`CTFlows.Common.AbstractConfig`](@ref).
"""
function tspan(c::AbstractConfig)
    throw(Exceptions.NotImplemented(
        "AbstractConfig tspan method not implemented";
        required_method = "tspan(c::$(typeof(c)))",
        suggestion = "Return the time span as a tuple (t0, tf) for this configuration.",
        context = "AbstractConfig.tspan - required method implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Return the initial condition for a configuration (stub method).

This is a stub method on the base `AbstractConfig` type that throws
`NotImplemented`. Concrete subtypes should implement this method to return
their specific initial condition format.

# Arguments
- `c::AbstractConfig`: The configuration.

# Throws
- `Exceptions.NotImplemented`: Always thrown for the base abstract type.

See also: [`CTFlows.Common.AbstractConfig`](@ref).
"""
function initial_condition(c::AbstractConfig)
    throw(Exceptions.NotImplemented(
        "AbstractConfig initial_condition method not implemented";
        required_method = "initial_condition(c::$(typeof(c)))",
        suggestion = "Return the initial condition for this configuration.",
        context = "AbstractConfig.initial_condition - required method implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Return the initial state for a configuration (stub method).

This is a stub method on the base `AbstractConfig` type that throws
`NotImplemented`. Concrete subtypes should implement this method to return
their specific initial state.

# Arguments
- `c::AbstractConfig`: The configuration.

# Throws
- `Exceptions.NotImplemented`: Always thrown for the base abstract type.

See also: [`CTFlows.Common.AbstractConfig`](@ref).
"""
function initial_state(c::AbstractConfig)
    throw(Exceptions.NotImplemented(
        "AbstractConfig initial_state method not implemented";
        required_method = "initial_state(c::$(typeof(c)))",
        suggestion = "Return the initial state for this configuration.",
        context = "AbstractConfig.initial_state - required method implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Return the initial costate for a configuration (stub method).

This is a stub method on the base `AbstractConfig` type that throws
`NotImplemented`. Concrete subtypes should implement this method to return
their specific initial costate (if applicable).

# Arguments
- `c::AbstractConfig`: The configuration.

# Throws
- `Exceptions.NotImplemented`: Always thrown for the base abstract type.

See also: [`CTFlows.Common.AbstractConfig`](@ref).
"""
function initial_costate(c::AbstractConfig)
    throw(Exceptions.NotImplemented(
        "AbstractConfig initial_costate method not implemented";
        required_method = "initial_costate(c::$(typeof(c)))",
        suggestion = "Return the initial costate for this configuration.",
        context = "AbstractConfig.initial_costate - required method implementation",
    ))
end

# =============================================================================
# Type Aliases for Convenient Dispatch
# =============================================================================

abstract type AbstractConfigWithMaC{X0, Mode<:AbstractModeTrait, Content<:AbstractContentTrait} <: AbstractConfig{X0} end

"""
$(TYPEDEF)

Alias for point integration mode configurations.

Matches any `AbstractConfig` with `PointTrait` as the mode parameter.
"""
const AbstractPointConfig{X0, C} = AbstractConfigWithMaC{X0, PointTrait, C}

"""
$(TYPEDEF)

Alias for trajectory integration mode configurations.

Matches any `AbstractConfig` with `TrajectoryTrait` as the mode parameter.
"""
const AbstractTrajectoryConfig{X0, C} = AbstractConfigWithMaC{X0, TrajectoryTrait, C}

"""
$(TYPEDEF)

Alias for state content configurations.

Matches any `AbstractConfig` with `StateTrait` as the content parameter.
"""
const AbstractStateConfig{X0, M} = AbstractConfigWithMaC{X0, M, StateTrait}

"""
$(TYPEDEF)

Alias for Hamiltonian content configurations.

Matches any `AbstractConfig` with `HamiltonianTrait` as the content parameter.
"""
const AbstractHamiltonianConfig{X0, M} = AbstractConfigWithMaC{X0, M, HamiltonianTrait}

"""
$(TYPEDEF)

Type alias for augmented Hamiltonian configurations, which include state, costate, and augmented variable initial conditions.

# Type Parameters
- `X0`: Type of the initial condition (typically a vector concatenating state, costate, and augmented variable).
- `M`: Type of the mutability trait (`InPlace` or `OutOfPlace`).

# Notes
- Augmented Hamiltonian configurations are used for systems where the Hamiltonian depends on an additional variable (e.g., a control parameter or optimization variable).
- The initial condition typically has the form `vcat(x0, p0, pv0)` where `x0` is the initial state, `p0` is the initial costate, and `pv0` is the initial augmented variable.
- Subtypes [`CTFlows.Common.AbstractConfigWithMaC`](@ref) with [`CTFlows.Common.AugmentedHamiltonianTrait`](@ref).
- Used in conjunction with [`CTFlows.Systems.HamiltonianSystem`](@ref) for automatic differentiation-based Hamiltonian integration.

See also: [`CTFlows.Common.AbstractHamiltonianConfig`](@ref), [`CTFlows.Common.AugmentedHamiltonianTrait`](@ref), [`CTFlows.Systems.HamiltonianSystem`](@ref).
"""
const AbstractAugmentedHamiltonianConfig{X0, M} = AbstractConfigWithMaC{X0, M, AugmentedHamiltonianTrait}

# =============================================================================
# Interface implementations on abstract config types
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the time span as a tuple for point configurations.

For point configurations, extracts the initial and final times from the
`t0` and `tf` fields.

# Arguments
- `c::AbstractPointConfig`: The point configuration.

# Returns
- `Tuple{Real, Real}`: Time span as (t0, tf).

See also: [`CTFlows.Common.AbstractPointConfig`](@ref), [`CTFlows.Common.tspan`](@ref).
"""
function tspan(c::AbstractPointConfig)::Tuple{Real, Real}
    return (c.t0, c.tf)
end

"""
$(TYPEDSIGNATURES)

Return the time span for trajectory configurations.

For trajectory configurations, returns the stored `tspan` field directly.

# Arguments
- `c::AbstractTrajectoryConfig`: The trajectory configuration.

# Returns
- `Tuple{Real, Real}`: Time span as (t0, tf).

See also: [`CTFlows.Common.AbstractTrajectoryConfig`](@ref), [`CTFlows.Common.tspan`](@ref).
"""
function tspan(c::AbstractTrajectoryConfig)::Tuple{Real, Real}
    return c.tspan
end

"""
$(TYPEDSIGNATURES)

Return the initial condition as a vector for scalar state configurations.

For scalar initial conditions, wraps the scalar in a length-1 vector to
maintain consistent vector-based ODE problem construction.

# Arguments
- `c::AbstractStateConfig{<:Number, M}`: The state configuration with scalar initial state.

# Returns
- `Vector{<:Number}`: Length-1 vector containing the scalar initial state.

See also: [`CTFlows.Common.AbstractStateConfig`](@ref), [`CTFlows.Common.initial_condition`](@ref).
"""
function initial_condition(c::AbstractStateConfig{<:Number, M}) where {M}
    return [c.x0]
end

"""
$(TYPEDSIGNATURES)

Return the initial condition for state configurations.

For vector initial conditions, returns the state vector directly.

# Arguments
- `c::AbstractStateConfig`: The state configuration.

# Returns
- The initial state vector.

See also: [`CTFlows.Common.AbstractStateConfig`](@ref).
"""
function initial_condition(c::AbstractStateConfig)
    return c.x0
end

"""
$(TYPEDSIGNATURES)

Return the initial condition for Hamiltonian configurations.

For Hamiltonian systems, the initial condition is the concatenation of the
initial state and initial costate: `vcat(x0, p0)`.

# Arguments
- `c::AbstractHamiltonianConfig`: The Hamiltonian configuration.

# Returns
- Concatenated vector `[x0; p0]`.

See also: [`CTFlows.Common.AbstractHamiltonianConfig`](@ref), [`CTFlows.Common.initial_state`](@ref), [`CTFlows.Common.initial_costate`](@ref).
"""
function initial_condition(c::AbstractHamiltonianConfig)
    return vcat(c.x0, c.p0)
end

"""
$(TYPEDSIGNATURES)

Return the initial state from a configuration.

Extracts the initial state field from the configuration.

# Arguments
- `c::AbstractConfigWithMaC`: The configuration with mode and content traits.

# Returns
- The initial state vector.

See also: [`CTFlows.Common.AbstractConfigWithMaC`](@ref).
"""
function initial_state(c::AbstractConfigWithMaC)
    return c.x0
end

"""
$(TYPEDSIGNATURES)

Return the initial costate for state configurations (error stub).

State configurations do not have a costate field. This method throws a
`PreconditionError` to enforce the contract that `initial_costate` is only
defined for Hamiltonian configurations.

# Arguments
- `c::AbstractStateConfig`: The state configuration.

# Throws
- `Exceptions.PreconditionError`: Always thrown for state configurations.

See also: [`CTFlows.Common.AbstractStateConfig`](@ref), [`CTFlows.Common.AbstractHamiltonianConfig`](@ref), [`CTFlows.Common.initial_costate`](@ref).
"""
function initial_costate(c::AbstractStateConfig)
    throw(Exceptions.PreconditionError(
        "initial_costate is only defined for Hamiltonian configs";
        context = "initial_costate - requires Hamiltonian config",
        reason = "config type $(typeof(c)) does not have a costate field",
        suggestion = "use HamiltonianPointConfig or HamiltonianTrajectoryConfig instead",
    ))
end

"""
$(TYPEDSIGNATURES)

Return the initial costate for Hamiltonian configurations.

Extracts the initial costate field from the Hamiltonian configuration.

# Arguments
- `c::AbstractHamiltonianConfig`: The Hamiltonian configuration.

# Returns
- The initial costate vector.

See also: [`CTFlows.Common.AbstractHamiltonianConfig`](@ref).
"""
function initial_costate(c::AbstractHamiltonianConfig)
    return c.p0
end

# =============================================================================
# Concrete configurations
# =============================================================================

"""
$(TYPEDEF)

Configuration for a point-to-point integration problem.

Defines the initial and final time points along with the initial state for
integration from a single initial condition to a specific final time.

# Fields
- `t0::T0`: Initial time
- `x0::X0`: Initial state vector
- `tf::TF`: Final time

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> config = StatePointConfig(0.0, [1.0, 0.0], 1.0)
StatePointConfig
  t0: 0.0
  x0: [1.0, 0.0]
  tf: 1.0
\`\`\`

See also: [`CTFlows.Common.StateTrajectoryConfig`](@ref)
"""
struct StatePointConfig{T0<:Real, X0, TF<:Real} <: AbstractConfigWithMaC{X0, PointTrait, StateTrait}
    t0::T0
    x0::X0
    tf::TF
end

"""
$(TYPEDEF)

Configuration for a trajectory integration problem.

Defines a time span and initial state for integration over a continuous
time interval, useful for generating full trajectories.

# Fields
- `tspan::TS`: Time span as a tuple (t0, tf)
- `x0::X0`: Initial state vector

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> config = StateTrajectoryConfig((0.0, 1.0), [1.0, 0.0])
StateTrajectoryConfig
  tspan: (0.0, 1.0)
  x0: [1.0, 0.0]
\`\`\`

See also: [`CTFlows.Common.StatePointConfig`](@ref)
"""
struct StateTrajectoryConfig{TS<:Tuple{<:Real,<:Real}, X0} <: AbstractConfigWithMaC{X0, TrajectoryTrait, StateTrait}
    tspan::TS
    x0::X0
end


"""
$(TYPEDEF)

Configuration for a Hamiltonian point-to-point integration problem.

Defines the initial and final time points along with the initial state and costate
for integration from a single initial condition to a specific final time in the
Hamiltonian framework.

# Fields
- `t0::T0`: Initial time
- `x0::X0`: Initial state vector
- `p0::P0`: Initial costate vector
- `tf::TF`: Final time

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> config = HamiltonianPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], 1.0)
HamiltonianPointConfig
  t0: 0.0
  x0: [1.0, 0.0]
  p0: [0.5, 0.3]
  tf: 1.0
\`\`\`

See also: [`CTFlows.Common.HamiltonianTrajectoryConfig`](@ref), [`CTFlows.Common.StatePointConfig`](@ref).
"""
struct HamiltonianPointConfig{T0<:Real, X0, P0, TF<:Real} <: AbstractConfigWithMaC{X0, PointTrait, HamiltonianTrait}
    t0::T0
    x0::X0
    p0::P0
    tf::TF
end

"""
$(TYPEDEF)

Configuration for a Hamiltonian trajectory integration problem.

Defines a time span and initial state and costate for integration over a
continuous time interval in the Hamiltonian framework, useful for generating
full Hamiltonian trajectories.

# Fields
- `tspan::TS`: Time span as a tuple (t0, tf)
- `x0::X0`: Initial state vector
- `p0::P0`: Initial costate vector

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> config = HamiltonianTrajectoryConfig((0.0, 1.0), [1.0, 0.0], [0.5, 0.3])
HamiltonianTrajectoryConfig
  tspan: (0.0, 1.0)
  x0: [1.0, 0.0]
  p0: [0.5, 0.3]
\`\`\`

See also: [`CTFlows.Common.HamiltonianPointConfig`](@ref), [`CTFlows.Common.StateTrajectoryConfig`](@ref).
"""
struct HamiltonianTrajectoryConfig{TS<:Tuple{<:Real,<:Real}, X0, P0} <: AbstractConfigWithMaC{X0, TrajectoryTrait, HamiltonianTrait}
    tspan::TS
    x0::X0
    p0::P0
end

# =============================================================================
# Base.show
# =============================================================================

"""
$(TYPEDSIGNATURES)

Display the `StatePointConfig` in tree-style format.
"""
function Base.show(io::IO, c::StatePointConfig)
    println(io, "StatePointConfig")
    println(io, "  t0: ", c.t0)
    println(io, "  x0: ", c.x0)
    print(io, "  tf: ", c.tf)
end

"""
$(TYPEDSIGNATURES)

Display the `StatePointConfig` in REPL format.
"""
function Base.show(io::IO, ::MIME"text/plain", c::StatePointConfig)
    show(io, c)
end

"""
$(TYPEDSIGNATURES)

Display the `StateTrajectoryConfig` in tree-style format.
"""
function Base.show(io::IO, c::StateTrajectoryConfig)
    println(io, "StateTrajectoryConfig")
    println(io, "  tspan: ", c.tspan)
    print(io, "  x0: ", c.x0)
end

"""
$(TYPEDSIGNATURES)

Display the `StateTrajectoryConfig` in REPL format.
"""
function Base.show(io::IO, ::MIME"text/plain", c::StateTrajectoryConfig)
    show(io, c)
end

"""
$(TYPEDSIGNATURES)

Display the `HamiltonianPointConfig` in tree-style format.
"""
function Base.show(io::IO, c::HamiltonianPointConfig)
    println(io, "HamiltonianPointConfig")
    println(io, "  t0: ", c.t0)
    println(io, "  x0: ", c.x0)
    println(io, "  p0: ", c.p0)
    print(io, "  tf: ", c.tf)
end

"""
$(TYPEDSIGNATURES)

Display the `HamiltonianPointConfig` in REPL format.
"""
function Base.show(io::IO, ::MIME"text/plain", c::HamiltonianPointConfig)
    show(io, c)
end

"""
$(TYPEDSIGNATURES)

Display the `HamiltonianTrajectoryConfig` in tree-style format.
"""
function Base.show(io::IO, c::HamiltonianTrajectoryConfig)
    println(io, "HamiltonianTrajectoryConfig")
    println(io, "  tspan: ", c.tspan)
    println(io, "  x0: ", c.x0)
    print(io, "  p0: ", c.p0)
end

"""
$(TYPEDSIGNATURES)

Display the `HamiltonianTrajectoryConfig` in REPL format.
"""
function Base.show(io::IO, ::MIME"text/plain", c::HamiltonianTrajectoryConfig)
    show(io, c)
end
