# =============================================================================
# Abstract Types
# =============================================================================

"""
$(TYPEDEF)

Abstract configuration type for integration problems.

Marker type for dispatch on configuration objects. Concrete subtypes define
specific integration scenarios (e.g., point-to-point, trajectory, costate).

The type parameter `X0` encodes the type of the initial condition:
- `X0 <: Number` for scalar initial conditions
- `X0 <: AbstractVector` for vector initial conditions

This enables compile-time dispatch on scalar vs vector cases without runtime type tests.

# Interface Requirements

All subtypes must implement:
- `tspan(config)`: Return the time span as a tuple `(t0, tf)`.

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> PointConfig <: Common.AbstractConfig
true

julia> TrajectoryConfig <: Common.AbstractConfig
true
\`\`\`

See also: [`CTFlows.Common.AbstractPointConfig`](@ref), [`CTFlows.Common.AbstractTrajectoryConfig`](@ref).
"""
abstract type AbstractConfig{X0} end

"""
$(TYPEDEF)

Abstract configuration for point-to-point integration problems.

Concrete subtypes define integration from a single initial condition to a specific
final time, without storing the full trajectory.

# Interface Requirements

All subtypes must implement:
- `tspan(config)`: Return the time span as a tuple `(t0, tf)`.

See also: [`CTFlows.Common.PointConfig`](@ref), [`CTFlows.Common.HamiltonianPointConfig`](@ref).
"""
abstract type AbstractPointConfig{X0} <: AbstractConfig{X0} end

"""
$(TYPEDEF)

Abstract configuration for trajectory integration problems.

Concrete subtypes define integration over a continuous time interval, useful for
generating full trajectories.

# Interface Requirements

All subtypes must implement:
- `tspan(config)`: Return the time span as a tuple `(t0, tf)`.

See also: [`CTFlows.Common.TrajectoryConfig`](@ref), [`CTFlows.Common.HamiltonianTrajectoryConfig`](@ref).
"""
abstract type AbstractTrajectoryConfig{X0} <: AbstractConfig{X0} end

# =============================================================================
# Interface: tspan
# =============================================================================

"""
$(TYPEDSIGNATURES)

Extract the time span from an `AbstractConfig`.

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`CTFlows.Common.AbstractConfig`](@ref), [`CTFlows.Common.PointConfig`](@ref), [`CTFlows.Common.TrajectoryConfig`](@ref).
"""
function tspan(c::AbstractConfig)
    throw(Exceptions.NotImplemented(
        "AbstractConfig tspan method not implemented";
        required_method = "tspan(c::$(typeof(c)))",
        suggestion = "Return the time span as a tuple (t0, tf) for this configuration.",
        context = "AbstractConfig.tspan - required method implementation",
    ))
end

# =============================================================================
# PointConfig
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

julia> config = PointConfig(0.0, [1.0, 0.0], 1.0)
PointConfig
  t0: 0.0
  x0: [1.0, 0.0]
  tf: 1.0
\`\`\`

See also: [`CTFlows.Common.TrajectoryConfig`](@ref)
"""
struct PointConfig{T0<:Real, X0, TF<:Real} <: AbstractPointConfig{X0}
    t0::T0
    x0::X0
    tf::TF
end

"""
$(TYPEDSIGNATURES)

Extract the time span from a `PointConfig`.

Returns a tuple `(t0, tf)` for consistency with `TrajectoryConfig`.

# Arguments
- `c::PointConfig`: The point configuration.

# Returns
- `Tuple{Real, Real}`: Time span as `(t0, tf)`.

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> config = PointConfig(0.0, [1.0, 0.0], 1.0)

julia> tspan(config)
(0.0, 1.0)
\`\`\`

See also: [`CTFlows.Common.PointConfig`](@ref), [`CTFlows.Common.TrajectoryConfig`](@ref)
"""
function tspan(c::PointConfig)::Tuple{Real, Real}
    return (c.t0, c.tf)
end

# =============================================================================
# TrajectoryConfig
# =============================================================================

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

julia> config = TrajectoryConfig((0.0, 1.0), [1.0, 0.0])
TrajectoryConfig
  tspan: (0.0, 1.0)
  x0: [1.0, 0.0]
\`\`\`

See also: [`CTFlows.Common.PointConfig`](@ref)
"""
struct TrajectoryConfig{TS<:Tuple{<:Real,<:Real}, X0} <: AbstractTrajectoryConfig{X0}
    tspan::TS
    x0::X0
end

"""
$(TYPEDSIGNATURES)

Extract the time span from a `TrajectoryConfig`.

Returns the stored time span tuple.

# Arguments
- `c::TrajectoryConfig`: The trajectory configuration.

# Returns
- `Tuple{Real, Real}`: Time span as `(t0, tf)`.

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> config = TrajectoryConfig((0.0, 1.0), [1.0, 0.0])

julia> tspan(config)
(0.0, 1.0)
\`\`\`

See also: [`CTFlows.Common.TrajectoryConfig`](@ref), [`CTFlows.Common.PointConfig`](@ref)
"""
function tspan(c::TrajectoryConfig)::Tuple{Real, Real}
    return c.tspan
end

# =============================================================================
# HamiltonianPointConfig
# =============================================================================

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

See also: [`CTFlows.Common.HamiltonianTrajectoryConfig`](@ref), [`CTFlows.Common.PointConfig`](@ref).
"""
struct HamiltonianPointConfig{T0<:Real, X0, P0, TF<:Real} <: AbstractPointConfig{X0}
    t0::T0
    x0::X0
    p0::P0
    tf::TF
end

"""
$(TYPEDSIGNATURES)

Extract the time span from a `HamiltonianPointConfig`.

Returns a tuple `(t0, tf)` for consistency with other config types.

# Arguments
- `c::HamiltonianPointConfig`: The Hamiltonian point configuration.

# Returns
- `Tuple{Real, Real}`: Time span as `(t0, tf)`.

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> config = HamiltonianPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], 1.0)

julia> tspan(config)
(0.0, 1.0)
\`\`\`

See also: [`CTFlows.Common.HamiltonianPointConfig`](@ref).
"""
function tspan(c::HamiltonianPointConfig)::Tuple{Real, Real}
    return (c.t0, c.tf)
end


# =============================================================================
# HamiltonianTrajectoryConfig
# =============================================================================

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

See also: [`CTFlows.Common.HamiltonianPointConfig`](@ref), [`CTFlows.Common.TrajectoryConfig`](@ref).
"""
struct HamiltonianTrajectoryConfig{TS<:Tuple{<:Real,<:Real}, X0, P0} <: AbstractTrajectoryConfig{X0}
    tspan::TS
    x0::X0
    p0::P0
end

"""
$(TYPEDSIGNATURES)

Extract the time span from a `HamiltonianTrajectoryConfig`.

Returns the stored time span tuple.

# Arguments
- `c::HamiltonianTrajectoryConfig`: The Hamiltonian trajectory configuration.

# Returns
- `Tuple{Real, Real}`: Time span as `(t0, tf)`.

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> config = HamiltonianTrajectoryConfig((0.0, 1.0), [1.0, 0.0], [0.5, 0.3])

julia> tspan(config)
(0.0, 1.0)
\`\`\`

See also: [`CTFlows.Common.HamiltonianTrajectoryConfig`](@ref).
"""
function tspan(c::HamiltonianTrajectoryConfig)::Tuple{Real, Real}
    return c.tspan
end


# =============================================================================
# Generic Accessor Functions
# =============================================================================

"""
$(TYPEDSIGNATURES)

Extract the initial state from an `AbstractConfig`.

Returns the initial state. For scalar configurations (`X0 <: Number`),
wraps in a vector for consistency with ODE solver expectations. For vector
configurations, returns the vector unchanged.

This uses compile-time dispatch on the type parameter `X0` to avoid runtime
type tests.

# Arguments
- `c::AbstractConfig{<:Number}`: Scalar configuration.

# Returns
- `AbstractVector`: The initial condition wrapped in a vector.

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> config = PointConfig(0.0, 1.0, 1.0)  # scalar x0

julia> initial_condition(config)
[1.0]
\`\`\`

See also: [`CTFlows.Common.AbstractConfig`](@ref), [`CTFlows.Common.PointConfig`](@ref).
"""
function initial_condition(c::AbstractConfig{<:Number})
    return [c.x0]
end

"""
$(TYPEDSIGNATURES)

Extract the initial condition from an `AbstractConfig`.

Returns the initial condition as a vector for vector configurations.

This uses compile-time dispatch on the type parameter `X0` to avoid runtime
type tests.

# Arguments
- `c::AbstractConfig`: Vector configuration.

# Returns
- `AbstractVector`: The initial condition vector.

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> config = PointConfig(0.0, [1.0, 0.0], 1.0)  # vector x0

julia> initial_condition(config)
[1.0, 0.0]
\`\`\`

See also: [`CTFlows.Common.AbstractConfig`](@ref), [`CTFlows.Common.PointConfig`](@ref).
"""
function initial_condition(c::AbstractConfig)
    return c.x0
end

"""
$(TYPEDSIGNATURES)

Extract the initial condition from a `HamiltonianPointConfig`.

Returns the concatenated state and costate as a single vector, which is the
expected format for ODE solvers in the Hamiltonian framework.

# Arguments
- `c::HamiltonianPointConfig`: The Hamiltonian point configuration.

# Returns
- `AbstractVector`: Concatenated state and costate vector.

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> config = HamiltonianPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], 1.0)

julia> initial_condition(config)
4-element Vector{Float64}:
 1.0
 0.0
 0.5
 0.3
\`\`\`

See also: [`CTFlows.Common.HamiltonianPointConfig`](@ref), [`CTFlows.Common.initial_state`](@ref), [`CTFlows.Common.initial_costate`](@ref).
"""
function initial_condition(c::HamiltonianPointConfig)
    return vcat(c.x0, c.p0)
end

"""
$(TYPEDSIGNATURES)

Extract the initial condition from a `HamiltonianTrajectoryConfig`.

Returns the concatenated state and costate as a single vector, which is the
expected format for ODE solvers in the Hamiltonian framework.

# Arguments
- `c::HamiltonianTrajectoryConfig`: The Hamiltonian trajectory configuration.

# Returns
- `AbstractVector`: Concatenated state and costate vector.

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> config = HamiltonianTrajectoryConfig((0.0, 1.0), [1.0, 0.0], [0.5, 0.3])

julia> initial_condition(config)
4-element Vector{Float64}:
 1.0
 0.0
 0.5
 0.3
\`\`\`

See also: [`CTFlows.Common.HamiltonianTrajectoryConfig`](@ref), [`CTFlows.Common.initial_state`](@ref), [`CTFlows.Common.initial_costate`](@ref).
"""
function initial_condition(c::HamiltonianTrajectoryConfig)
    return vcat(c.x0, c.p0)
end

"""
$(TYPEDSIGNATURES)

Extract the initial state from an `AbstractConfig`.

For point and trajectory configs, returns the state `x0`. For Hamiltonian
configs, returns the state `x0` (separate from costate).

# Arguments
- `c::AbstractConfig`: The configuration.

# Returns
- The initial state (scalar, vector, or tuple for Hamiltonian configs).

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> config = PointConfig(0.0, [1.0, 0.0], 1.0)

julia> initial_state(config)
[1.0, 0.0]
\`\`\`

See also: [`CTFlows.Common.initial_costate`](@ref), [`CTFlows.Common.initial_condition`](@ref).
"""
function initial_state(c::Common.AbstractConfig)
    return c.x0
end

"""
$(TYPEDSIGNATURES)

Extract the initial costate from a Hamiltonian config.

For Hamiltonian configs, returns the costate `p0`. For non-Hamiltonian configs,
throws `NotImplemented` since costate is not defined.

# Arguments
- `c::AbstractConfig`: The configuration.

# Returns
- The initial costate (vector).

# Throws
- `CTBase.Exceptions.NotImplemented`: If config is not a Hamiltonian config.

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> config = HamiltonianPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], 1.0)

julia> initial_costate(config)
[0.5, 0.3]
\`\`\`

See also: [`CTFlows.Common.initial_state`](@ref), [`CTFlows.Common.initial_condition`](@ref).
"""
function initial_costate(c::Union{Common.HamiltonianPointConfig, Common.HamiltonianTrajectoryConfig})
    return c.p0
end

function initial_costate(c::Common.AbstractConfig)
    throw(Exceptions.PreconditionError(
        "initial_costate is only defined for Hamiltonian configs";
        context = "initial_costate - requires Hamiltonian config",
        reason = "config type $(typeof(c)) does not have a costate field",
        suggestion = "use HamiltonianPointConfig or HamiltonianTrajectoryConfig instead",
    ))
end

# =============================================================================
# Base.show
# =============================================================================

"""
$(TYPEDSIGNATURES)

Display the `PointConfig` in tree-style format.
"""
function Base.show(io::IO, c::PointConfig)
    println(io, "PointConfig")
    println(io, "  t0: ", c.t0)
    println(io, "  x0: ", c.x0)
    print(io, "  tf: ", c.tf)
end

"""
$(TYPEDSIGNATURES)

Display the `PointConfig` in REPL format.
"""
function Base.show(io::IO, ::MIME"text/plain", c::PointConfig)
    show(io, c)
end

"""
$(TYPEDSIGNATURES)

Display the `TrajectoryConfig` in tree-style format.
"""
function Base.show(io::IO, c::TrajectoryConfig)
    println(io, "TrajectoryConfig")
    println(io, "  tspan: ", c.tspan)
    print(io, "  x0: ", c.x0)
end

"""
$(TYPEDSIGNATURES)

Display the `TrajectoryConfig` in REPL format.
"""
function Base.show(io::IO, ::MIME"text/plain", c::TrajectoryConfig)
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
