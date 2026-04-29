"""
$(TYPEDEF)

Container for the raw SciML ODE solution from a TrajectoryConfig integration.

This type wraps the raw ODE solution returned by SciML solvers. For now,
it simply stores the solution without providing any accessor methods.

# Fields
- `raw`: The raw ODE solution object (typically from SciML's solve function).

# Notes
- No accessor methods are provided at this time.
- The raw solution typically contains `.t` (time points) and `.u` (state values).
- Future versions may add convenience methods for accessing solution data.
- Plotting and evaluation capabilities are provided by the CTFlowsPlotsExt extension.
"""
struct VectorFieldSolution
    raw::Any
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
function RecipesBase.plot(sol::VectorFieldSolution, args...; kwargs...)
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

function Base.show(io::IO, ::MIME"text/plain", sol::VectorFieldSolution)
    print(io, "VectorFieldSolution")
    print(io, "\n  raw: ", nameof(typeof(sol.raw)))
    
    # Try to extract useful info from raw solution
    try
        if hasfield(typeof(sol.raw), :t) && !isempty(sol.raw.t)
            print(io, "\n  time span: (", first(sol.raw.t), ", ", last(sol.raw.t), ")")
            print(io, "\n  time points: ", length(sol.raw.t))
        end
    catch
        # If we can't extract info, just show the type
    end
end

function Base.show(io::IO, sol::VectorFieldSolution)
    print(io, "VectorFieldSolution(")
    parts = String[]
    push!(parts, "raw=$(nameof(typeof(sol.raw)))")
    
    try
        if hasfield(typeof(sol.raw), :t) && !isempty(sol.raw.t)
            push!(parts, "tspan=($(first(sol.raw.t)), $(last(sol.raw.t)))")
            push!(parts, "n=$(length(sol.raw.t))")
        end
    catch
    end
    
    print(io, join(parts, ", "))
    print(io, ")")
end
