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

See also: [`TrajectoryConfig`](@ref)
"""
struct PointConfig{T0, X0, TF}
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

julia> config = TrajectoryConfig((0.0, 1.0), [1.0, 0.0])
TrajectoryConfig
  tspan: (0.0, 1.0)
  x0: [1.0, 0.0]
\`\`\`

See also: [`PointConfig`](@ref)
"""
struct TrajectoryConfig{TS, X0}
    tspan::TS
    x0::X0
end

# =============================================================================
# Base.show
# =============================================================================

function Base.show(io::IO, c::PointConfig)
    println(io, "PointConfig")
    println(io, "  t0: ", c.t0)
    println(io, "  x0: ", c.x0)
    print(io, "  tf: ", c.tf)
end

function Base.show(io::IO, ::MIME"text/plain", c::PointConfig)
    show(io, c)
end

function Base.show(io::IO, c::TrajectoryConfig)
    println(io, "TrajectoryConfig")
    println(io, "  tspan: ", c.tspan)
    print(io, "  x0: ", c.x0)
end

function Base.show(io::IO, ::MIME"text/plain", c::TrajectoryConfig)
    show(io, c)
end

# =============================================================================
# Default values for VectorField constructor
# =============================================================================

"""
$(TYPEDSIGNATURES)

Default value for autonomous flag in VectorField constructor.

Returns `true` by default, meaning systems are autonomous unless explicitly specified.
"""
__autonomous()::Bool = true

"""
$(TYPEDSIGNATURES)

Default value for variable flag in VectorField constructor.

Returns `false` by default, meaning systems have fixed parameters unless explicitly specified.
"""
__variable()::Bool = false
