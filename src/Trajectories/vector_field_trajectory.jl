"""
$(TYPEDEF)

Abstract supertype for vector field solution containers.

This type defines the interface for all solution types that wrap ODE integration results.

See also: [`CTFlows.Trajectories.VectorFieldTrajectory`](@extref), [`CTSolvers.Integrators.AbstractIntegrationResult`](@extref).
"""
abstract type AbstractVectorFieldTrajectory end

"""
$(TYPEDEF)

Container for the integration result from a StateTrajectoryConfig integration.

This type wraps the integration result returned by integrators and provides
semantic accessors for time grids and state functions.

# Fields
- `result`: The integration result object (subtype of `AbstractIntegrationResult`).
- `variable`: The variable value threaded through the flow call, or `Core.NotProvided`
  when the flow carries no variable.
- `x0`: The initial state, or `Core.NotProvided` when built without a config (e.g. raw
  plumbing/tests). Drives the "1-D = scalar" coercion (issue #357,
  [`CTFlows.Systems._coerce_state`](@extref)) applied by `sol(t)` and `Integrators.final_state`
  — a scalar or length-1-vector `x0` collapses the returned state to a scalar; anything
  else, or `Core.NotProvided`, applies no coercion.

# Accessors
- `times(sol)`: Get the time grid (alias: `time_grid(sol)`)
- `state(sol)`: Get the solution as a callable state function
- `sol(t)`: Evaluate the solution at time `t` (equivalent to `state(sol)(t)`)

# Example
\`\`\`julia
using CTFlows: Trajectories

sol = Trajectories.VectorFieldTrajectory(result)
ts = times(sol)           # or Trajectories.time_grid(sol)
x = Trajectories.state(sol)            # callable state function
x(0.5)                    # evaluate at t = 0.5
\`\`\`

See also: [`CTSolvers.Integrators.AbstractIntegrationResult`](@extref), [`CTFlows.Trajectories.AbstractVectorFieldTrajectory`](@extref).
"""
struct VectorFieldTrajectory{R<:Integrators.AbstractIntegrationResult,V,X0} <:
       AbstractVectorFieldTrajectory
    result::R
    variable::V
    x0::X0
end

"""
$(TYPEDSIGNATURES)

Construct a `VectorFieldTrajectory` with no variable and no known initial state
(both default to `Core.NotProvided`, applying no shape coercion).
"""
function VectorFieldTrajectory(result::Integrators.AbstractIntegrationResult)
    return VectorFieldTrajectory(result, Core.NotProvided, Core.NotProvided)
end

"""
$(TYPEDSIGNATURES)

Construct a `VectorFieldTrajectory` with no known initial state (`Core.NotProvided`,
applying no shape coercion) — kept for callers that only carry `variable`, not `x0`
(e.g. [`CTFlows.Trajectories.merge`](@extref) on legacy segments, or direct construction
from a raw integration result in tests).
"""
function VectorFieldTrajectory(result::Integrators.AbstractIntegrationResult, variable)
    return VectorFieldTrajectory(result, variable, Core.NotProvided)
end

# =============================================================================
# Internal helper for display
# =============================================================================

"""
    _show_variable(v) -> Bool

Return `true` when the trajectory variable `v` is worth displaying, i.e. it is neither the
`Core.NotProvided` sentinel nor `nothing` (the value `Fixed` flows thread through).
"""
_show_variable(v) = !(v isa Core.NotProvidedType) && v !== nothing

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

This is a method of the [`CTModels.Components.state`](@extref) generic, contributed by
CTFlows for `VectorFieldTrajectory`. It returns `sol` itself (which is already callable),
providing a clear, self-documenting way to obtain the trajectory function.

# Arguments
- `sol::VectorFieldTrajectory`: The vector field solution.

# Returns
- `VectorFieldTrajectory`: The solution itself, which is callable as a function of time.

# Example
\`\`\`julia
using CTFlows: Trajectories

sol = Trajectories.VectorFieldTrajectory(result)
x = Trajectories.state(sol)    # x is a function of time
x(0.0)            # initial state
x(0.5)            # interpolated state at t = 0.5
x.(0.0:0.1:1.0)   # broadcast over time grid
\`\`\`

# Notes
- This accessor provides a foundation for uniform semantic accessors in optimal control:
  `state(sol)`, `costate(sol)`, `control(sol)` when extended to Hamiltonian systems.
- No allocation occurs — returns `sol` directly.

See also: [`CTSolvers.Integrators.times`](@extref), [`CTSolvers.Integrators.evaluate_at`](@extref), [`CTFlows.Trajectories.time_grid`](@extref), [`CTModels.Components.state`](@extref).
"""
function Components.state(sol::VectorFieldTrajectory)
    return sol
end

"""
$(TYPEDSIGNATURES)

Alias for `times(sol)` — returns the time grid from the solution.

This is a method of the [`CTModels.Components.time_grid`](@extref) generic, contributed by
CTFlows for `VectorFieldTrajectory`: an alternative, more explicit name for `times` in
numerical contexts where "time grid" is the standard terminology.

# Arguments
- `sol::VectorFieldTrajectory`: The vector field solution.

# Returns
- `AbstractVector`: The vector of time points.

# Example
\`\`\`julia
using CTFlows: Trajectories

sol = Trajectories.VectorFieldTrajectory(result)
tg = Trajectories.time_grid(sol)  # same as times(sol)
\`\`\`

# Notes
- `time_grid` and `times` are two names for the same operation.
- Use `time_grid` when "grid" terminology is clearer in context.
- Use `times` for brevity in everyday use.

See also: [`CTSolvers.Integrators.times`](@extref), [`CTFlows.Trajectories.state`](@extref), [`CTModels.Components.time_grid`](@extref).
"""
function Components.time_grid(sol::VectorFieldTrajectory)
    return Integrators.times(sol)
end

"""
$(TYPEDSIGNATURES)

Evaluate the solution at a given time, coerced to a scalar for a 1-D state (issue #357).

Delegates to the integration result, then applies
[`CTFlows.Systems._coerce_state`](@extref)`(sol.x0)` — a scalar or length-1-vector `x0`
collapses the returned state to a scalar; anything else (including `x0 ===
Core.NotProvided`) applies no coercion.

# Arguments
- `sol::VectorFieldTrajectory`: The vector field solution.
- `t::Real`: The time at which to evaluate the solution.

# Returns
- The solution state at time `t`.

See also: [`CTFlows.Systems._coerce_state`](@extref), [`CTSolvers.Integrators.evaluate_at`](@extref), [`CTSolvers.Integrators.times`](@extref).
"""
function (sol::VectorFieldTrajectory)(t::Real)
    return Systems._coerce_state(sol.x0)(Integrators.evaluate_at(sol.result, t))
end

"""
$(TYPEDSIGNATURES)

Return the final state from the solution, coerced to a scalar for a 1-D state (issue
#357) — see [`CTFlows.Systems._coerce_state`](@extref).

# Arguments
- `sol::VectorFieldTrajectory`: The vector field solution.

# Returns
- The final state from the integration result.

See also: [`CTFlows.Systems._coerce_state`](@extref), [`CTSolvers.Integrators.AbstractIntegrationResult`](@extref), [`CTSolvers.Integrators.final_state`](@extref).
"""
function Integrators.final_state(sol::VectorFieldTrajectory)
    return Systems._coerce_state(sol.x0)(Integrators.final_state(sol.result))
end

"""
$(TYPEDSIGNATURES)

Return the termination status of the solution by delegating to the integration result.

# Arguments
- `sol::VectorFieldTrajectory`: The vector field solution.

# Returns
- The termination status (a `Symbol`) from the integration result.

See also: [`CTSolvers.Integrators.AbstractIntegrationResult`](@extref), [`CTSolvers.Integrators.status`](@extref).
"""
function Integrators.status(sol::VectorFieldTrajectory)
    return Integrators.status(sol.result)
end

"""
$(TYPEDSIGNATURES)

Return whether the solution terminated successfully by delegating to the integration result.

# Arguments
- `sol::VectorFieldTrajectory`: The vector field solution.

# Returns
- Whether the integration succeeded.

See also: [`CTSolvers.Integrators.AbstractIntegrationResult`](@extref), [`CTSolvers.Integrators.successful`](@extref).
"""
function Integrators.successful(sol::VectorFieldTrajectory)
    return Integrators.successful(sol.result)
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

    # Wrap in VectorFieldTrajectory, preserving the first segment's variable and x0
    return VectorFieldTrajectory(merged_result, segments[1].variable, segments[1].x0)
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

See also: [`CTFlows.Trajectories.VectorFieldTrajectory`](@extref), [`CTFlows.Trajectories.AbstractVectorFieldTrajectory`](@extref).
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
    fmt = Display.format_codes(io)
    Display.print_header(io, "VectorFieldTrajectory"; fmt=fmt)
    fields = Any[("result", nameof(typeof(sol.result)), "")]
    try
        ts = Integrators.times(sol)
        if !isempty(ts)
            push!(fields, ("tspan", (first(ts), last(ts)), fmt.value))
            push!(fields, ("time points", length(ts), fmt.count))
        end
    catch
    end
    try
        push!(fields, ("final state", Integrators.final_state(sol), fmt.value))
    catch
    end
    if _show_variable(sol.variable)
        push!(fields, ("variable", sol.variable, fmt.value))
    end
    return Display.print_fields(io, fields; fmt=fmt)
end

"""
$(TYPEDSIGNATURES)

Display the `VectorFieldTrajectory` in a compact one-line format.

# Arguments
- `io::IO`: The IO stream to write to.
- `sol::VectorFieldTrajectory`: The solution to display.
"""
function Base.show(io::IO, sol::VectorFieldTrajectory)
    fmt = Display.format_codes(io)
    print(io, fmt.name, "VectorFieldTrajectory", fmt.reset, "(")
    parts = String[]
    push!(parts, "result=$(nameof(typeof(sol.result)))")

    try
        ts = Integrators.times(sol)
        if !isempty(ts)
            push!(parts, "tspan=($(first(ts)), $(last(ts)))")
            push!(parts, "n=$(length(ts))")
        end
    catch
    end

    if _show_variable(sol.variable)
        push!(parts, "variable=$(sol.variable)")
    end

    print(io, join(parts, ", "))
    return print(io, ")")
end
