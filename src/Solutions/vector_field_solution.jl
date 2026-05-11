"""
$(TYPEDEF)

Abstract supertype for vector field solution containers.

This type defines the interface for all solution types that wrap ODE integration results.

See also: [`CTFlows.Solutions.VectorFieldSolution`](@ref), [`CTFlows.Integrators.AbstractIntegrationResult`](@ref).
"""
abstract type AbstractVectorFieldSolution end

"""
$(TYPEDEF)

Container for the integration result from a TrajectoryConfig integration.

This type wraps the integration result returned by integrators and provides
semantic accessors for time grids and state functions.

# Fields
- `result`: The integration result object (subtype of `AbstractIntegrationResult`).

# Accessors
- `times(sol)`: Get the time grid (alias: `time_grid(sol)`)
- `state(sol)`: Get the solution as a callable state function
- `sol(t)`: Evaluate the solution at time `t` (equivalent to `state(sol)(t)`)

# Example
\`\`\`julia
using CTFlows.Solutions

sol = VectorFieldSolution(result)
ts = times(sol)           # or time_grid(sol)
x = state(sol)            # callable state function
x(0.5)                    # evaluate at t = 0.5
\`\`\`

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Solutions.AbstractVectorFieldSolution`](@ref).
"""
struct VectorFieldSolution{R<:Integrators.AbstractIntegrationResult} <: AbstractVectorFieldSolution
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
- `sol::VectorFieldSolution`: The vector field solution.

# Returns
- `AbstractVector`: The vector of time points.

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Integrators.evaluate_at`](@ref).
"""
function Integrators.times(sol::VectorFieldSolution)
    return Integrators.times(sol.result)
end

"""
$(TYPEDSIGNATURES)

Return the solution itself as a state function of time.

This is a semantic accessor that returns `sol` itself (which is already callable),
providing a clear, self-documenting way to obtain the trajectory function.

# Arguments
- `sol::VectorFieldSolution`: The vector field solution.

# Returns
- `VectorFieldSolution`: The solution itself, which is callable as a function of time.

# Example
\`\`\`julia
using CTFlows.Solutions

sol = VectorFieldSolution(result)
x = state(sol)    # x is a function of time
x(0.0)            # initial state
x(0.5)            # interpolated state at t = 0.5
x.(0.0:0.1:1.0)   # broadcast over time grid
\`\`\`

# Notes
- This accessor provides a foundation for uniform semantic accessors in optimal control:
  `state(sol)`, `costate(sol)`, `control(sol)` when extended to Hamiltonian systems.
- No allocation occurs — returns `sol` directly.

See also: [`CTFlows.Solutions.times`](@ref), [`CTFlows.Solutions.evaluate_at`](@ref), [`CTFlows.Solutions.time_grid`](@ref).
"""
function state(sol::VectorFieldSolution)
    return sol
end

"""
$(TYPEDSIGNATURES)

Alias for `times(sol)` — returns the time grid from the solution.

This is an alternative, more explicit name for `times` in numerical contexts
where "time grid" is the standard terminology.

# Arguments
- `sol::VectorFieldSolution`: The vector field solution.

# Returns
- `AbstractVector`: The vector of time points.

# Example
\`\`\`julia
using CTFlows.Solutions

sol = VectorFieldSolution(result)
tg = time_grid(sol)  # same as times(sol)
\`\`\`

# Notes
- `time_grid` and `times` are two names for the same operation.
- Use `time_grid` when "grid" terminology is clearer in context.
- Use `times` for brevity in everyday use.

See also: [`CTFlows.Solutions.times`](@ref), [`CTFlows.Solutions.state`](@ref).
"""
function time_grid(sol::VectorFieldSolution)
    return times(sol)
end

"""
$(TYPEDSIGNATURES)

Evaluate the solution at a given time by delegating to the integration result.

# Arguments
- `sol::VectorFieldSolution`: The vector field solution.
- `t::Real`: The time at which to evaluate the solution.

# Returns
- The solution state at time `t`.

See also: [`CTFlows.Solutions.evaluate_at`](@ref), [`CTFlows.Solutions.times`](@ref).
"""
function (sol::VectorFieldSolution)(t::Real)
    return evaluate_at(sol.result, t)
end

"""
$(TYPEDSIGNATURES)

Return the final state from the solution by delegating to the integration result.

# Arguments
- `sol::VectorFieldSolution`: The vector field solution.

# Returns
- The final state from the integration result.

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Solutions.final_state`](@ref).
"""
function Integrators.final_state(sol::VectorFieldSolution)
    return Integrators.final_state(sol.result)
end

"""
$(TYPEDSIGNATURES)

Merge a sequence of VectorFieldSolution objects into a single VectorFieldSolution.

This extracts the internal integration results, merges them, and wraps the result
in a new VectorFieldSolution.

# Arguments
- `segments::AbstractVector{<:VectorFieldSolution}`: Sequence of vector field solutions to merge.

# Returns
- `VectorFieldSolution`: A merged vector field solution containing the merged integration result.

See also: [`CTFlows.Integrators.merge`](@ref), [`CTFlows.Integrators.AbstractIntegrationResult`](@ref).
"""
function Integrators.merge(segments::AbstractVector{<:VectorFieldSolution})
    if isempty(segments)
        throw(Exceptions.IncorrectArgument(
            "Cannot merge empty sequence of VectorFieldSolution";
            got = "0 segments",
            expected = "at least 1 segment",
            context = "VectorFieldSolution merge",
        ))
    end
    
    # Extract internal results
    internal_results = [sol.result for sol in segments]
    
    # Merge the internal results
    merged_result = Integrators.merge(internal_results)
    
    # Wrap in VectorFieldSolution
    return VectorFieldSolution(merged_result)
end

# =============================================================================
# Stub methods — to be extended by CTFlowsPlots
# =============================================================================

"""
$(TYPEDSIGNATURES)

Plot stub — throws error if Plots extension not loaded.

# Arguments
- `sol::AbstractVectorFieldSolution`: The vector field solution.
- `kwargs...`: Additional plotting keyword arguments (ignored).

# Throws
- `CTBase.Exceptions.ExtensionError`: If Plots extension is not loaded.

See also: [`CTFlows.Solutions.VectorFieldSolution`](@ref), [`CTFlows.Solutions.AbstractVectorFieldSolution`](@ref).
"""
function RecipesBase.plot(sol::AbstractVectorFieldSolution; kwargs...)
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

Display the `VectorFieldSolution` in a readable text/plain format.

# Arguments
- `io::IO`: The IO stream to write to.
- `::MIME"text/plain"`: The MIME type.
- `sol::VectorFieldSolution`: The solution to display.
"""
function Base.show(io::IO, ::MIME"text/plain", sol::VectorFieldSolution)
    print(io, "VectorFieldSolution")
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

Display the `VectorFieldSolution` in a compact one-line format.

# Arguments
- `io::IO`: The IO stream to write to.
- `sol::VectorFieldSolution`: The solution to display.
"""
function Base.show(io::IO, sol::VectorFieldSolution)
    print(io, "VectorFieldSolution(")
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
