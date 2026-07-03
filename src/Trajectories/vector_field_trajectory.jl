"""
$(TYPEDEF)

Abstract supertype for vector field solution containers.

This type defines the interface for all solution types that wrap ODE integration results.

See also: [`CTFlows.Trajectories.VectorFieldTrajectory`](@ref), [`CTSolvers.Integrators.AbstractIntegrationResult`](@extref).
"""
abstract type AbstractVectorFieldTrajectory end

"""
$(TYPEDEF)

Container for the integration result from a StateTrajectoryConfig integration.

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
using CTFlows.Trajectories

sol = VectorFieldTrajectory(result)
ts = times(sol)           # or time_grid(sol)
x = state(sol)            # callable state function
x(0.5)                    # evaluate at t = 0.5
\`\`\`

See also: [`CTSolvers.Integrators.AbstractIntegrationResult`](@extref), [`CTFlows.Trajectories.AbstractVectorFieldTrajectory`](@ref).
"""
struct VectorFieldTrajectory{R<:Integrators.AbstractIntegrationResult} <:
       AbstractVectorFieldTrajectory
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
- `sol::VectorFieldTrajectory`: The vector field solution.

# Returns
- `AbstractVector`: The vector of time points.

See also: [`CTSolvers.Integrators.AbstractIntegrationResult`](@extref), [`CTSolvers.Integrators.evaluate_at`](@extref).
"""
function Integrators.times(sol::VectorFieldTrajectory)
    return Integrators.times(sol.result)
end

"""
$(TYPEDSIGNATURES)

Return the solution itself as a state function of time.

This is a semantic accessor that returns `sol` itself (which is already callable),
providing a clear, self-documenting way to obtain the trajectory function.

# Arguments
- `sol::VectorFieldTrajectory`: The vector field solution.

# Returns
- `VectorFieldTrajectory`: The solution itself, which is callable as a function of time.

# Example
\`\`\`julia
using CTFlows.Trajectories

sol = VectorFieldTrajectory(result)
x = state(sol)    # x is a function of time
x(0.0)            # initial state
x(0.5)            # interpolated state at t = 0.5
x.(0.0:0.1:1.0)   # broadcast over time grid
\`\`\`

# Notes
- This accessor provides a foundation for uniform semantic accessors in optimal control:
  `state(sol)`, `costate(sol)`, `control(sol)` when extended to Hamiltonian systems.
- No allocation occurs — returns `sol` directly.

See also: [`CTSolvers.Integrators.times`](@extref), [`CTSolvers.Integrators.evaluate_at`](@extref), [`CTFlows.Trajectories.time_grid`](@ref).
"""
function state(sol::VectorFieldTrajectory)
    return sol
end

"""
$(TYPEDSIGNATURES)

Alias for `times(sol)` — returns the time grid from the solution.

This is an alternative, more explicit name for `times` in numerical contexts
where "time grid" is the standard terminology.

# Arguments
- `sol::VectorFieldTrajectory`: The vector field solution.

# Returns
- `AbstractVector`: The vector of time points.

# Example
\`\`\`julia
using CTFlows.Trajectories

sol = VectorFieldTrajectory(result)
tg = time_grid(sol)  # same as times(sol)
\`\`\`

# Notes
- `time_grid` and `times` are two names for the same operation.
- Use `time_grid` when "grid" terminology is clearer in context.
- Use `times` for brevity in everyday use.

See also: [`CTSolvers.Integrators.times`](@extref), [`CTFlows.Trajectories.state`](@ref).
"""
function time_grid(sol::VectorFieldTrajectory)
    return Integrators.times(sol)
end

"""
$(TYPEDSIGNATURES)

Evaluate the solution at a given time by delegating to the integration result.

# Arguments
- `sol::VectorFieldTrajectory`: The vector field solution.
- `t::Real`: The time at which to evaluate the solution.

# Returns
- The solution state at time `t`.

See also: [`CTSolvers.Integrators.evaluate_at`](@extref), [`CTSolvers.Integrators.times`](@extref).
"""
function (sol::VectorFieldTrajectory)(t::Real)
    return Integrators.evaluate_at(sol.result, t)
end

"""
$(TYPEDSIGNATURES)

Return the final state from the solution by delegating to the integration result.

# Arguments
- `sol::VectorFieldTrajectory`: The vector field solution.

# Returns
- The final state from the integration result.

See also: [`CTSolvers.Integrators.AbstractIntegrationResult`](@extref), [`CTSolvers.Integrators.final_state`](@extref).
"""
function Integrators.final_state(sol::VectorFieldTrajectory)
    return Integrators.final_state(sol.result)
end

"""
$(TYPEDSIGNATURES)

Merge a sequence of VectorFieldTrajectory objects into a single VectorFieldTrajectory.

This extracts the internal integration results, merges them, and wraps the result
in a new VectorFieldTrajectory.

# Arguments
- `segments::AbstractVector{<:VectorFieldTrajectory}`: Sequence of vector field solutions to merge.

# Returns
- `VectorFieldTrajectory`: A merged vector field solution containing the merged integration result.

See also: [`CTSolvers.Integrators.merge`](@extref), [`CTSolvers.Integrators.AbstractIntegrationResult`](@extref).
"""
function Integrators.merge(segments::AbstractVector{<:VectorFieldTrajectory})
    if isempty(segments)
        throw(
            Exceptions.IncorrectArgument(
                "Cannot merge empty sequence of VectorFieldTrajectory";
                got="0 segments",
                expected="at least 1 segment",
                context="VectorFieldTrajectory merge",
            ),
        )
    end

    # Extract internal results
    internal_results = [sol.result for sol in segments]

    # Merge the internal results
    merged_result = Integrators.merge(internal_results)

    # Wrap in VectorFieldTrajectory
    return VectorFieldTrajectory(merged_result)
end

# =============================================================================
# Stub methods — to be extended by CTFlowsPlots
# =============================================================================

"""
$(TYPEDSIGNATURES)

Plot stub — throws error if Plots extension not loaded.

# Arguments
- `sol::AbstractVectorFieldTrajectory`: The vector field solution.
- `kwargs...`: Additional plotting keyword arguments (ignored).

# Throws
- `CTBase.Exceptions.ExtensionError`: If Plots extension is not loaded.

See also: [`CTFlows.Trajectories.VectorFieldTrajectory`](@ref), [`CTFlows.Trajectories.AbstractVectorFieldTrajectory`](@ref).
"""
function RecipesBase.plot(sol::AbstractVectorFieldTrajectory; kwargs...)
    return throw(
        Exceptions.ExtensionError(
            :Plots;
            message="to plot solutions",
            feature="Plotting via Plots.jl",
            context="Load Plots extension first: using Plots",
        ),
    )
end

# =============================================================================
# Base.show
# =============================================================================

"""
$(TYPEDSIGNATURES)

Display the `VectorFieldTrajectory` in a readable text/plain format.

# Arguments
- `io::IO`: The IO stream to write to.
- `::MIME"text/plain"`: The MIME type.
- `sol::VectorFieldTrajectory`: The solution to display.
"""
function Base.show(io::IO, ::MIME"text/plain", sol::VectorFieldTrajectory)
    print(io, "VectorFieldTrajectory")
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

Display the `VectorFieldTrajectory` in a compact one-line format.

# Arguments
- `io::IO`: The IO stream to write to.
- `sol::VectorFieldTrajectory`: The solution to display.
"""
function Base.show(io::IO, sol::VectorFieldTrajectory)
    print(io, "VectorFieldTrajectory(")
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
    return print(io, ")")
end
