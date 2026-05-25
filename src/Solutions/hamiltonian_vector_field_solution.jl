"""
$(TYPEDEF)

Abstract supertype for Hamiltonian vector field solution containers.

This type defines the interface for all solution types that wrap ODE integration
results for Hamiltonian systems.

See also: [`CTFlows.Solutions.HamiltonianVectorFieldSolution`](@ref), [`CTFlows.Integrators.AbstractIntegrationResult`](@ref).
"""
abstract type AbstractHamiltonianVectorFieldSolution end

"""
$(TYPEDEF)

Container for the integration result from a HamiltonianTrajectoryConfig integration.

This type wraps the integration result returned by integrators and provides
semantic accessors for time grids, state functions, and costate functions.

# Fields
- `result`: The integration result object (subtype of `AbstractIntegrationResult`).

# Accessors
- `times(sol)`: Get the time grid (alias: `time_grid(sol)`)
- `state(sol)`: Get the solution as a callable state function `x(t)`
- `costate(sol)`: Get the solution as a callable costate function `p(t)`
- `sol(t)`: Evaluate the solution at time `t`, returning tuple `(x(t), p(t))`

# Example
```julia
using CTFlows.Solutions

sol = HamiltonianVectorFieldSolution(result)
ts = times(sol)           # or time_grid(sol)
x = state(sol)            # callable state function x(t)
p = costate(sol)          # callable costate function p(t)
x(0.5), p(0.5)           # evaluate at t = 0.5
x0, p0 = sol(0.0)        # returns tuple (x(0), p(0))
```

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Solutions.AbstractHamiltonianVectorFieldSolution`](@ref).
"""
struct HamiltonianVectorFieldSolution{R<:Integrators.AbstractIntegrationResult} <: AbstractHamiltonianVectorFieldSolution
    result::R
end

# =============================================================================
# Semantic Accessors and Delegation
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the vector of time points from the solution.

Delegates to `Integrators.times(sol.result)`.

# Arguments
- `sol::HamiltonianVectorFieldSolution`: The Hamiltonian vector field solution.

# Returns
- `AbstractVector`: The vector of time points.

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Integrators.evaluate_at`](@ref).
"""
function Integrators.times(sol::HamiltonianVectorFieldSolution)
    return Integrators.times(sol.result)
end

"""
$(TYPEDSIGNATURES)

Alias for `times(sol)` — returns the time grid from the solution.

This is an alternative, more explicit name for `times` in numerical contexts
where "time grid" is the standard terminology.

# Arguments
- `sol::HamiltonianVectorFieldSolution`: The Hamiltonian vector field solution.

# Returns
- `AbstractVector`: The vector of time points.

See also: [`CTFlows.Solutions.times`](@ref), [`CTFlows.Solutions.state`](@ref).
"""
function time_grid(sol::HamiltonianVectorFieldSolution)
    return Integrators.times(sol)
end

"""
$(TYPEDSIGNATURES)

Evaluate the solution at a given time, returning a tuple `(x(t), p(t))`.

Splits the combined state vector into state and costate halves.

# Arguments
- `sol::HamiltonianVectorFieldSolution`: The Hamiltonian vector field solution.
- `t::Real`: The time at which to evaluate the solution.

# Returns
- `Tuple{AbstractVector, AbstractVector}`: The state `x(t)` and costate `p(t)` at time `t`.

See also: [`CTFlows.Solutions.evaluate_at`](@ref), [`CTFlows.Solutions.times`](@ref).
"""
function (sol::HamiltonianVectorFieldSolution)(t::Real)
    u = Integrators.evaluate_at(sol.result, t)
    n = length(u) ÷ 2
    return (u[1:n], u[n+1:2n])
end

"""
$(TYPEDSIGNATURES)

Return the solution as a state function of time `x(t)`.

This is a semantic accessor that returns a function which, when called with a time,
returns only the state component `x(t)` (not the costate).

# Arguments
- `sol::HamiltonianVectorFieldSolution`: The Hamiltonian vector field solution.

# Returns
- `Function`: A function `t -> x(t)` that returns the state at time `t`.

# Example
```julia
using CTFlows.Solutions

sol = HamiltonianVectorFieldSolution(result)
x = state(sol)    # x is a function of time
x(0.0)            # initial state
x(0.5)            # interpolated state at t = 0.5
```

See also: [`CTFlows.Solutions.costate`](@ref), [`CTFlows.Solutions.times`](@ref).
"""
function state(sol::HamiltonianVectorFieldSolution)
    return t -> sol(t)[1]
end

"""
$(TYPEDSIGNATURES)

Return the solution as a costate function of time `p(t)`.

This is a semantic accessor that returns a function which, when called with a time,
returns only the costate component `p(t)` (not the state).

# Arguments
- `sol::HamiltonianVectorFieldSolution`: The Hamiltonian vector field solution.

# Returns
- `Function`: A function `t -> p(t)` that returns the costate at time `t`.

# Example
```julia
using CTFlows.Solutions

sol = HamiltonianVectorFieldSolution(result)
p = costate(sol)  # p is a function of time
p(0.0)            # initial costate
p(0.5)            # interpolated costate at t = 0.5
```

See also: [`CTFlows.Solutions.state`](@ref), [`CTFlows.Solutions.times`](@ref).
"""
function costate(sol::HamiltonianVectorFieldSolution)
    return t -> sol(t)[2]
end

"""
$(TYPEDSIGNATURES)

Return the final state and costate from the solution as a tuple `(xf, pf)`.

Splits the combined state vector into state and costate halves.

# Arguments
- `sol::HamiltonianVectorFieldSolution`: The Hamiltonian vector field solution.

# Returns
- `Tuple{AbstractVector, AbstractVector}`: The final state `xf` and final costate `pf`.

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Solutions.final_state`](@ref).
"""
function Integrators.final_state(sol::HamiltonianVectorFieldSolution)
    u = Integrators.final_state(sol.result)
    n = length(u) ÷ 2
    return (u[1:n], u[n+1:2n])
end

"""
$(TYPEDSIGNATURES)

Merge a sequence of HamiltonianVectorFieldSolution objects into a single HamiltonianVectorFieldSolution.

This extracts the internal integration results, merges them, and wraps the result
in a new HamiltonianVectorFieldSolution.

# Arguments
- `segments::AbstractVector{<:HamiltonianVectorFieldSolution}`: Sequence of Hamiltonian vector field solutions to merge.

# Returns
- `HamiltonianVectorFieldSolution`: A merged Hamiltonian vector field solution containing the merged integration result.

See also: [`CTFlows.Integrators.merge`](@ref), [`CTFlows.Integrators.AbstractIntegrationResult`](@ref).
"""
function Integrators.merge(segments::AbstractVector{<:HamiltonianVectorFieldSolution})
    if isempty(segments)
        throw(Exceptions.IncorrectArgument(
            "Cannot merge empty sequence of HamiltonianVectorFieldSolution";
            got = "0 segments",
            expected = "at least 1 segment",
            context = "HamiltonianVectorFieldSolution merge",
        ))
    end
    
    internal_results = [sol.result for sol in segments]
    merged_result = Integrators.merge(internal_results)
    return HamiltonianVectorFieldSolution(merged_result)
end

# =============================================================================
# Stub methods — to be extended by CTFlowsPlots
# =============================================================================

"""
$(TYPEDSIGNATURES)

Plot stub — throws error if Plots extension not loaded.

# Arguments
- `sol::AbstractHamiltonianVectorFieldSolution`: The Hamiltonian vector field solution.
- `kwargs...`: Additional plotting keyword arguments (ignored).

# Throws
- `CTBase.Exceptions.ExtensionError`: If Plots extension is not loaded.

See also: [`CTFlows.Solutions.HamiltonianVectorFieldSolution`](@ref), [`CTFlows.Solutions.AbstractHamiltonianVectorFieldSolution`](@ref).
"""
function RecipesBase.plot(sol::AbstractHamiltonianVectorFieldSolution; kwargs...)
    throw(
        Exceptions.ExtensionError(
            :Plots;
            message = "to plot solutions",
            feature = "Plotting via Plots.jl",
            context = "Load Plots extension first: using Plots",
        ),
    )
end

# =============================================================================
# Base.show
# =============================================================================

"""
$(TYPEDSIGNATURES)

Display the `HamiltonianVectorFieldSolution` in a readable text/plain format.

# Arguments
- `io::IO`: The IO stream to write to.
- `::MIME"text/plain"`: The MIME type.
- `sol::HamiltonianVectorFieldSolution`: The solution to display.
"""
function Base.show(io::IO, ::MIME"text/plain", sol::HamiltonianVectorFieldSolution)
    print(io, "HamiltonianVectorFieldSolution")
    print(io, "\n  result: ", nameof(typeof(sol.result)))
    
    try
        ts = times(sol)
        if !isempty(ts)
            print(io, "\n  time span: (", first(ts), ", ", last(ts), ")")
            print(io, "\n  time points: ", length(ts))
        end
    catch
    end
end

"""
$(TYPEDSIGNATURES)

Display the `HamiltonianVectorFieldSolution` in a compact one-line format.

# Arguments
- `io::IO`: The IO stream to write to.
- `sol::HamiltonianVectorFieldSolution`: The solution to display.
"""
function Base.show(io::IO, sol::HamiltonianVectorFieldSolution)
    print(io, "HamiltonianVectorFieldSolution(")
    parts = String[]
    push!(parts, "result=$(nameof(typeof(sol.result)))")
    
    try
        ts = times(sol)
        if !isempty(ts)
            push!(parts, "tspan=($(first(ts)), $(last(ts)))")
            push!(parts, "n=$(length(ts))")
        end
    catch
    end
    
    print(io, join(parts, ", "))
    print(io, ")")
end
