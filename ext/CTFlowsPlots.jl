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

# =============================================================================
# Plots.plot — HamiltonianVectorFieldSolution
# =============================================================================

"""
Internal helper to convert a Hamiltonian solution to time, state, and costate arrays.

# Arguments
- `sol::Solutions.HamiltonianVectorFieldSolution`: The Hamiltonian solution to convert.

# Returns
- `Tuple{AbstractVector, AbstractMatrix, AbstractMatrix}`: A tuple of (time vector, state matrix, costate matrix).

# Notes
- Uses `reduce(hcat, ...)'` for robust handling of 1D states.
- Uses `state(sol)` and `costate(sol)` to explicitly obtain the state and costate functions.
- Internal function, not part of public API.
"""
function _ham_sol_to_arrays(sol::Solutions.HamiltonianVectorFieldSolution)
    ts = Solutions.times(sol)
    x = Solutions.state(sol)
    p = Solutions.costate(sol)
    states = reduce(hcat, x.(ts))'
    costates = reduce(hcat, p.(ts))'
    return ts, states, costates
end

"""
$(TYPEDSIGNATURES)

Plot a `HamiltonianVectorFieldSolution` by extracting time points, states, and costates.

Uses a `(1, 2)` layout to show state and costate in separate subplots.

# Arguments
- `sol::Solutions.HamiltonianVectorFieldSolution`: The Hamiltonian solution to plot.
- `kwargs...`: Additional keyword arguments passed to `Plots.plot`.

# Returns
- The plot object returned by `Plots.plot`.

See also: [`CTFlows.Solutions.HamiltonianVectorFieldSolution`](@ref), [`CTFlows.Solutions.times`](@ref), [`CTFlows.Solutions.state`](@ref), [`CTFlows.Solutions.costate`](@ref).
"""
function Plots.plot(sol::Solutions.HamiltonianVectorFieldSolution; kwargs...)
    ts, states, costates = _ham_sol_to_arrays(sol)
    return Plots.plot(ts, [states costates]; layout=(1, 2), kwargs...)
end

"""
$(TYPEDSIGNATURES)

Plot into an existing plot by extracting time points, states, and costates.

Uses a `(1, 2)` layout to show state and costate in separate subplots.

# Arguments
- `sol::Solutions.HamiltonianVectorFieldSolution`: The Hamiltonian solution to plot.
- `kwargs...`: Additional keyword arguments passed to `Plots.plot!`.

# Returns
- The modified plot object returned by `Plots.plot!`.

See also: [`CTFlows.Solutions.HamiltonianVectorFieldSolution`](@ref), [`CTFlows.Solutions.times`](@ref), [`CTFlows.Solutions.state`](@ref), [`CTFlows.Solutions.costate`](@ref).
"""
function Plots.plot!(sol::Solutions.HamiltonianVectorFieldSolution; kwargs...)
    ts, states, costates = _ham_sol_to_arrays(sol)
    return Plots.plot!(ts, [states costates]; layout=(1, 2), kwargs...)
end

"""
$(TYPEDSIGNATURES)

Plot into an existing plot by extracting time points, states, and costates.

Uses a `(1, 2)` layout to show state and costate in separate subplots.

# Arguments
- `p::Plots.Plot`: The existing plot to modify.
- `sol::Solutions.HamiltonianVectorFieldSolution`: The Hamiltonian solution to plot.
- `kwargs...`: Additional keyword arguments passed to `Plots.plot!`.

# Returns
- The modified plot object returned by `Plots.plot!`.

See also: [`CTFlows.Solutions.HamiltonianVectorFieldSolution`](@ref), [`CTFlows.Solutions.times`](@ref), [`CTFlows.Solutions.state`](@ref), [`CTFlows.Solutions.costate`](@ref).
"""
function Plots.plot!(p::Plots.Plot, sol::Solutions.HamiltonianVectorFieldSolution; kwargs...)
    ts, states, costates = _ham_sol_to_arrays(sol)
    return Plots.plot!(p, ts, [states costates]; layout=(1, 2), kwargs...)
end

end # module CTFlowsPlots
