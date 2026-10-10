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

# =============================================================================
# Generated output grids: `grid=` keyword of a trajectory call
# =============================================================================

"""
$(TYPEDEF)

Abstract supertype of the output grids generated from the time span of a trajectory call
(`f((t0, tf), x0, …; grid=spec)`). A generated grid has exactly `n` distinct times, the
bounds and the switching times of a multi-phase flow included; it only shapes the output
(the integration is that of the span).

See also: [`CTFlows.Configs.UniformGrid`](@extref), [`CTFlows.Configs.AdaptiveGrid`](@extref).
"""
abstract type AbstractGrid end

"""
$(TYPEDEF)

Uniform output grid of `n` times (`grid=n` is a shortcut for `grid=UniformGrid(n)`). On a
multi-phase flow, the `n - 1` intervals are shared between the phases in proportion to
their duration.

# Fields
- `n::Int`: Number of distinct times, at least 2.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: If `n < 2`.

See also: [`CTFlows.Configs.AdaptiveGrid`](@extref).
"""
struct UniformGrid <: AbstractGrid
    n::Int
    function UniformGrid(n::Integer)
        _check_grid_size(n, "UniformGrid")
        return new(n)
    end
end

"""
$(TYPEDEF)

Adaptive output grid of `n` times, denser where the plotted curves (state, costate and
control, each scaled by its range) bend: the times equidistribute the density
`ρ ∝ ‖y''‖^{1/2}`, which minimizes the error of the polyline drawn through them, mixed with
a uniform share `uniform`. On a multi-phase flow, the intervals are shared between the
phases in proportion to their mass.

# Fields
- `n::Int`: Number of distinct times, at least 2.
- `uniform::Float64`: Share of the uniform density, in `[0, 1]` (default `0.1`).

# Throws
- `CTBase.Exceptions.IncorrectArgument`: If `n < 2` or `uniform ∉ [0, 1]`.

See also: [`CTFlows.Configs.UniformGrid`](@extref).
"""
struct AdaptiveGrid <: AbstractGrid
    n::Int
    uniform::Float64
    function AdaptiveGrid(n::Integer; uniform::Real=0.1)
        _check_grid_size(n, "AdaptiveGrid")
        if !(0 <= uniform <= 1)
            throw(
                Exceptions.IncorrectArgument(
                    "The uniform share of an AdaptiveGrid must lie in [0, 1]";
                    got="uniform=$(uniform)",
                    expected="0 ≤ uniform ≤ 1",
                    context="AdaptiveGrid",
                ),
            )
        end
        return new(n, Float64(uniform))
    end
end

"""
$(TYPEDSIGNATURES)

Check the number of times of a generated grid.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: If `n < 2`.
"""
function _check_grid_size(n::Integer, context::String)
    n >= 2 || throw(
        Exceptions.IncorrectArgument(
            "A generated grid needs at least two times";
            got="n=$(n)",
            expected="n ≥ 2",
            context=context,
        ),
    )
    return nothing
end

"""
$(TYPEDSIGNATURES)

Normalize the `grid` keyword of a trajectory call: `nothing` (no generated grid), an
integer `n` (uniform grid of `n` times) or an [`CTFlows.Configs.AbstractGrid`](@extref).

# Throws
- `CTBase.Exceptions.IncorrectArgument`: For any other value (a vector of times is passed
  in place of the time span, not through `grid`).
"""
_grid_spec(::Nothing) = nothing
_grid_spec(n::Integer) = UniformGrid(n)
_grid_spec(spec::AbstractGrid) = spec
function _grid_spec(grid)
    throw(
        Exceptions.IncorrectArgument(
            "Invalid `grid` keyword";
            got="grid=$(repr(grid))",
            expected="an integer, UniformGrid(n) or AdaptiveGrid(n)",
            suggestion="To impose given times, pass them in place of the time span: f([t0, t1, …, tf], x0, …).",
            context="trajectory call",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Time specification of a trajectory call with a `grid` keyword: the span and the output
grid (a vector of times, a generated grid spec, or `nothing`).

# Throws
- `CTBase.Exceptions.IncorrectArgument`: If both a grid of times and `grid=` are given.
"""
function _time_spec(times::TimeSpec, grid)
    spec = _grid_spec(grid)
    spec === nothing && return _time_spec(times)
    if !(times isa Tuple{Real,Real})
        throw(
            Exceptions.IncorrectArgument(
                "Two output grids given: a grid of times and the `grid` keyword";
                got="times=$(times), grid=$(repr(grid))",
                expected="either a time span (t0, tf) with `grid=`, or a grid of times without `grid=`",
                context="trajectory call",
            ),
        )
    end
    return (float.(times), spec)
end
