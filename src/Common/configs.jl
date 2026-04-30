"""
$(TYPEDEF)

Abstract configuration type for integration problems.

Marker type for dispatch on configuration objects. Concrete subtypes define
specific integration scenarios (e.g., point-to-point, trajectory, costate).

# Interface Requirements

No required methods - this is a marker type for type-based dispatch only.

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> PointConfig <: Common.AbstractConfig
true

julia> TrajectoryConfig <: Common.AbstractConfig
true
\`\`\`

See also: [`CTFlows.Common.PointConfig`](@ref), [`CTFlows.Common.TrajectoryConfig`](@ref)
"""
abstract type AbstractConfig end

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
struct PointConfig{T0<:Real, X0, TF<:Real} <: AbstractConfig
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
function tspan(c::PointConfig)
    return (c.t0, c.tf)
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

julia> config = TrajectoryConfig((0.0, 1.0), [1.0, 0.0])
TrajectoryConfig
  tspan: (0.0, 1.0)
  x0: [1.0, 0.0]
\`\`\`

See also: [`CTFlows.Common.PointConfig`](@ref)
"""
struct TrajectoryConfig{TS<:Tuple{<:Real,<:Real}, X0} <: AbstractConfig
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
function tspan(c::TrajectoryConfig)
    return c.tspan
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

# =============================================================================
# Default values for time-dependent object constructors
# =============================================================================

"""
$(TYPEDSIGNATURES)

Default value for autonomous flag in time-dependent object constructors.

Returns `true` by default, meaning objects do not explicitly depend on time
unless specified otherwise.
"""
__autonomous()::Bool = true

"""
$(TYPEDSIGNATURES)

Default value for variable flag in time-dependent object constructors.

Returns `false` by default, meaning objects have fixed parameters unless
specified otherwise.
"""
__variable()::Bool = false
