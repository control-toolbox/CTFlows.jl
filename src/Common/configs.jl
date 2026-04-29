struct PointConfig{T0, X0, TF}
    t0::T0
    x0::X0
    tf::TF
end

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
