"""
$(TYPEDEF)

Abstract supertype for vector field solution containers.

This type defines the interface for all solution types that wrap ODE integration results.

See also: [`CTFlows.Solutions.VectorFieldSolution`](@ref), [`CTFlows.Solutions.AbstractIntegrationResult`](@ref).
"""
abstract type AbstractVectorFieldSolution end

"""
$(TYPEDEF)

Container for the integration result from a TrajectoryConfig integration.

This type wraps the integration result returned by integrators.

# Fields
- `result`: The integration result object (subtype of `AbstractIntegrationResult`).

See also: [`CTFlows.Solutions.AbstractIntegrationResult`](@ref), [`CTFlows.Solutions.AbstractVectorFieldSolution`](@ref).
"""
struct VectorFieldSolution{R<:AbstractIntegrationResult} <: AbstractVectorFieldSolution
    result::R
end

# =============================================================================
# Semantic Accessors and Delegation
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the vector of time points from the solution.

Delegates to `times(sol.result)`.

# Arguments
- `sol::VectorFieldSolution`: The vector field solution.

# Returns
- `AbstractVector`: The vector of time points.

See also: [`CTFlows.Solutions.AbstractIntegrationResult`](@ref), [`CTFlows.Solutions.evaluate_at`](@ref).
"""
function times(sol::VectorFieldSolution)
    return times(sol.result)
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

# =============================================================================
# Stub methods — to be extended by CTFlowsPlotsExt
# =============================================================================

"""
$(TYPEDSIGNATURES)

Plot stub — throws error if Plots extension not loaded.

# Arguments
- `sol::AbstractVectorFieldSolution`: The vector field solution.
- `kwargs...`: Additional plotting keyword arguments (ignored).

# Throws
- `CTBase.Exceptions.IncorrectArgument`: If Plots extension is not loaded.

See also: [`CTFlows.Solutions.VectorFieldSolution`](@ref), [`CTFlows.Solutions.AbstractVectorFieldSolution`](@ref).
"""
function RecipesBase.plot(sol::AbstractVectorFieldSolution; kwargs...)
    throw(
        Exceptions.IncorrectArgument(
            "Plots extension not loaded";
            got = "plot call without Plots extension",
            expected = "Plots.jl to be loaded",
            suggestion = "Load Plots.jl with: using Plots",
            context = "RecipesBase.plot - extension availability check",
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
