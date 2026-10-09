# =============================================================================
# Time specification of a trajectory call: a time span or an imposed output grid
# =============================================================================

"""
Time specification accepted by a trajectory call (and by the trajectory configurations):

- a 2-tuple `(t0, tf)` is the time span; the output grid is chosen automatically (the
  solver steps, or the integrator's `saveat`);
- a vector (or range) of times, or a tuple of at least three times, imposes the output grid
  `(t0, t1, …, tf)`: the integration runs from its first to its last time and the trajectory
  is returned on exactly these times. The grid takes precedence over the integrator's
  `saveat`, and only affects the output: the integration and the dense interpolant are the
  same as for the span `(t0, tf)`.

A grid must be strictly monotone (increasing for a forward integration, decreasing for a
backward one).

See also: [`CTFlows.Configs.StateTrajectoryConfig`](@extref), [`CTFlows.Configs.HamiltonianTrajectoryConfig`](@extref), [`CTFlows.Configs.output_grid`](@extref).
"""
const TimeSpec = Union{Tuple{Vararg{Real}},AbstractVector{<:Real}}

"""
$(TYPEDSIGNATURES)

Time span `(t0, tf)`, no imposed output grid.
"""
_time_spec(tspan::Tuple{Real,Real}) = (float.(tspan), nothing)

"""
$(TYPEDSIGNATURES)

Imposed output grid given as a tuple of times.
"""
_time_spec(times::Tuple{Vararg{Real}}) = _time_spec(collect(Float64, times))

"""
$(TYPEDSIGNATURES)

Imposed output grid: returns the span `(first, last)` and the grid as a vector of floats.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: If the grid has fewer than two times or is not
  strictly monotone.
"""
function _time_spec(grid::AbstractVector{<:Real})
    if length(grid) < 2
        throw(
            Exceptions.IncorrectArgument(
                "A time grid needs at least two times";
                got="$(length(grid)) time(s)",
                expected="(t0, tf) or a grid (t0, t1, …, tf)",
                context="trajectory call",
            ),
        )
    end
    g = collect(float(eltype(grid)), grid)
    steps = diff(g)
    if !(all(>(0), steps) || all(<(0), steps))
        throw(
            Exceptions.IncorrectArgument(
                "The time grid must be strictly monotone";
                got="$(g)",
                expected="strictly increasing (or strictly decreasing) times",
                suggestion="Sort the grid and remove repeated times.",
                context="trajectory call",
            ),
        )
    end
    return ((first(g), last(g)), g)
end

"""
$(TYPEDSIGNATURES)

Return the output time grid imposed at the call, or `nothing` (point configurations, and
trajectory configurations built from a time span).

See also: [`CTFlows.Configs.TimeSpec`](@extref).
"""
output_grid(::AbstractConfig) = nothing

"""
$(TYPEDSIGNATURES)

Return the output time grid imposed at the call, or `nothing` for a time span.
"""
output_grid(c::AbstractTrajectoryConfig) = c.grid
