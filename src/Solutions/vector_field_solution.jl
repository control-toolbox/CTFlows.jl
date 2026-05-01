"""
$(TYPEDEF)

Abstract supertype for vector field solution containers.

This type defines the interface for all solution types that wrap SciML ODE solutions.
Concrete subtypes should store the raw ODE solution and provide access via the `raw` function.

# Interface Requirements

Subtypes must implement:
- `raw(sol::SubType)`: Return the underlying SciML ODE solution

# Example
\`\`\`julia-repl
julia> using CTFlows.Solutions

julia> VectorFieldSolution <: AbstractVectorFieldSolution
true
\`\`\`

See also: [`Solutions.VectorFieldSolution`](@ref), [`Solutions.raw`](@ref).
"""
abstract type AbstractVectorFieldSolution end

"""
$(TYPEDEF)

Container for the raw SciML ODE solution from a TrajectoryConfig integration.

This type wraps the raw ODE solution returned by SciML solvers. For now,
it simply stores the solution without providing any accessor methods.

# Fields
- `ode_sol`: The raw ODE solution object (typically from SciML's solve function).

# Notes
- Access the raw ODE solution via the `raw(sol)` getter.
- The raw solution typically contains `.t` (time points) and `.u` (state values).
- Future versions may add convenience methods for accessing solution data.
- Plotting and evaluation capabilities are provided by the CTFlowsPlotsExt extension.
"""
struct VectorFieldSolution{TO<:SciMLBase.AbstractODESolution} <: AbstractVectorFieldSolution
    ode_sol::TO
end

"""
$(TYPEDSIGNATURES)

Return the raw SciML ODE solution from a `VectorFieldSolution`.

# Returns
- `SciMLBase.AbstractODESolution`: The underlying ODE solution object.
"""
function raw(sol::VectorFieldSolution)
    return sol.ode_sol
end

# =============================================================================
# Stub methods — to be extended by CTFlowsPlotsExt
# =============================================================================

"""
$(TYPEDSIGNATURES)

Plot stub — throws error if Plots extension not loaded.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: If Plots extension is not loaded.
"""
function RecipesBase.plot(sol::AbstractVectorFieldSolution, args...; kwargs...)
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

"""
$(TYPEDSIGNATURES)

Evaluate the solution at a given time by delegating to raw solution.
"""
function (sol::VectorFieldSolution)(args...; kwargs...)
    return raw(sol)(args...; kwargs...)
end

# =============================================================================
# Base.show
# =============================================================================

function Base.show(io::IO, ::MIME"text/plain", sol::VectorFieldSolution)
    print(io, "VectorFieldSolution")
    print(io, "\n  ode solution: ", nameof(typeof(raw(sol))))
    
    # Try to extract useful info from raw solution
    try
        raw_ode_sol = raw(sol)
        if hasfield(typeof(raw_ode_sol), :t) && !isempty(raw_ode_sol.t)
            print(io, "\n  time span: (", first(raw_ode_sol.t), ", ", last(raw_ode_sol.t), ")")
            print(io, "\n  time points: ", length(raw_ode_sol.t))
        end
    catch
        # If we can't extract info, just show the type
    end
end

function Base.show(io::IO, sol::VectorFieldSolution)
    print(io, "VectorFieldSolution(")
    parts = String[]
    push!(parts, "ode_sol=$(nameof(typeof(raw(sol))))")
    
    try
        raw_ode_sol = raw(sol)
        if hasfield(typeof(raw_ode_sol), :t) && !isempty(raw_ode_sol.t)
            push!(parts, "tspan=($(first(raw_ode_sol.t)), $(last(raw_ode_sol.t)))")
            push!(parts, "n=$(length(raw_ode_sol.t))")
        end
    catch
    end
    
    print(io, join(parts, ", "))
    print(io, ")")
end
