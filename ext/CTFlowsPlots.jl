"""
    CTFlowsPlots

Package extension providing plotting capabilities for `VectorFieldSolution`.
Activated automatically when `Plots` is loaded together with `CTFlows`.
"""
module CTFlowsPlots

import DocStringExtensions: TYPEDSIGNATURES

using CTFlows: CTFlows
using CTFlows.Solutions: Solutions
using Plots: Plots

# =============================================================================
# Plots.plot — delegate to semantic accessors
# =============================================================================

"""
$(TYPEDSIGNATURES)

Internal helper to convert a solution to time and state arrays.

# Arguments
- `sol::Solutions.VectorFieldSolution`: The solution to convert.

# Returns
- `Tuple{AbstractVector, AbstractMatrix}`: A tuple of (time vector, state matrix).

# Notes
- Uses `reduce(hcat, ...)'` for robust handling of 1D states.
- Uses `state(sol)` to explicitly obtain the state function.
- Internal function, not part of public API.
"""
function _sol_to_arrays(sol::Solutions.VectorFieldSolution)
    ts = Solutions.times(sol)
    x = Solutions.state(sol)
    states = reduce(hcat, x.(ts))'
    return ts, states
end

"""
$(TYPEDSIGNATURES)

Plot a `VectorFieldSolution` by extracting time points and states.

# Arguments
- `sol::Solutions.VectorFieldSolution`: The solution to plot.
- `kwargs...`: Additional keyword arguments passed to `Plots.plot`.

# Returns
- The plot object returned by `Plots.plot`.

See also: [`CTFlows.Solutions.VectorFieldSolution`](@ref), [`CTFlows.Solutions.times`](@ref), [`CTFlows.Solutions.state`](@ref).
"""
function Plots.plot(sol::Solutions.VectorFieldSolution; kwargs...)
    ts, states = _sol_to_arrays(sol)
    return Plots.plot(ts, states; kwargs...)
end

"""
$(TYPEDSIGNATURES)

Plot into an existing plot by extracting time points and states.

# Arguments
- `sol::Solutions.VectorFieldSolution`: The solution to plot.
- `kwargs...`: Additional keyword arguments passed to `Plots.plot!`.

# Returns
- The modified plot object returned by `Plots.plot!`.

See also: [`CTFlows.Solutions.VectorFieldSolution`](@ref), [`CTFlows.Solutions.times`](@ref), [`CTFlows.Solutions.state`](@ref).
"""
function Plots.plot!(sol::Solutions.VectorFieldSolution; kwargs...)
    ts, states = _sol_to_arrays(sol)
    return Plots.plot!(ts, states; kwargs...)
end

"""
$(TYPEDSIGNATURES)

Plot into an existing plot by extracting time points and states.

# Arguments
- `p::Plots.Plot`: The existing plot to modify.
- `sol::Solutions.VectorFieldSolution`: The solution to plot.
- `kwargs...`: Additional keyword arguments passed to `Plots.plot!`.

# Returns
- The modified plot object returned by `Plots.plot!`.

See also: [`CTFlows.Solutions.VectorFieldSolution`](@ref), [`CTFlows.Solutions.times`](@ref), [`CTFlows.Solutions.state`](@ref).
"""
function Plots.plot!(p::Plots.Plot, sol::Solutions.VectorFieldSolution; kwargs...)
    ts, states = _sol_to_arrays(sol)
    return Plots.plot!(p, ts, states; kwargs...)
end

end # module CTFlowsPlots
