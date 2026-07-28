"""
$(TYPEDEF)

Abstract supertype for Hamiltonian vector field solution containers.

This type defines the interface for all solution types that wrap ODE integration
results for Hamiltonian systems.

See also: [`CTFlows.Trajectories.HamiltonianVectorFieldTrajectory`](@ref), [`CTSolvers.Integrators.AbstractIntegrationResult`](@extref).
"""
abstract type AbstractHamiltonianVectorFieldTrajectory end

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
using CTFlows.Trajectories

sol = HamiltonianVectorFieldTrajectory(result)
ts = times(sol)           # or time_grid(sol)
x = state(sol)            # callable state function x(t)
p = costate(sol)          # callable costate function p(t)
x(0.5), p(0.5)           # evaluate at t = 0.5
x0, p0 = sol(0.0)        # returns tuple (x(0), p(0))
```

See also: [`CTSolvers.Integrators.AbstractIntegrationResult`](@extref), [`CTFlows.Trajectories.AbstractHamiltonianVectorFieldTrajectory`](@ref).
"""
struct HamiltonianVectorFieldTrajectory{
    X0,R<:Integrators.AbstractIntegrationResult,V,SP,CP
} <: AbstractHamiltonianVectorFieldTrajectory
    x0::X0
    result::R
    variable::V
    state_proj::SP
    costate_proj::CP
end

"""
$(TYPEDSIGNATURES)

Construct a `HamiltonianVectorFieldTrajectory`, precomputing the state and costate
projections once so the `state`/`costate` accessors return a stored functor instead of
rebuilding one on every call.
"""
function HamiltonianVectorFieldTrajectory(
    x0, result::Integrators.AbstractIntegrationResult, variable
)
    sp = StateProjection(result, x0)
    cp = CostateProjection(result, x0)
    return HamiltonianVectorFieldTrajectory{
        typeof(x0),typeof(result),typeof(variable),typeof(sp),typeof(cp)
    }(
        x0, result, variable, sp, cp
    )
end

"""
$(TYPEDSIGNATURES)

Construct a `HamiltonianVectorFieldTrajectory` with no variable (`Core.NotProvided`).
"""
function HamiltonianVectorFieldTrajectory(x0, result::Integrators.AbstractIntegrationResult)
    return HamiltonianVectorFieldTrajectory(x0, result, Core.NotProvided)
end

# =============================================================================
# Internal helper for splitting solutions based on initial state shape
# =============================================================================

"""
    _ham_split_solution(u::AbstractVector, x0::Number) = (_safe_only(u[1:1]), _safe_only(u[2:2]))
    _ham_split_solution(u::AbstractVector, x0::AbstractVector) = (u[1:n], u[n+1:2n])
    _ham_split_solution(u::AbstractMatrix, x0::AbstractMatrix) = (u[1:n, :], u[n+1:2n, :])

Split a combined state vector into state and costate components, preserving the shape of x0.

For scalar x0, extracts single elements and coerces them back to scalars (via the GPU-safe
[`CTFlows.Systems._safe_only`](@ref), consistent with every other 1-D=scalar split path).
For vector/matrix x0, extracts views of the appropriate size.
"""
function _ham_split_solution(u::AbstractVector, x0::Number)
    return (Systems._safe_only(u[1:1]), Systems._safe_only(u[2:2]))
end

"""
$(TYPEDSIGNATURES)

Split a combined state–costate vector into two sub-vectors, using `length(x0)` as the
state dimension `n`.

# Returns
- `(u[1:n], u[(n+1):2n])`: state and costate sub-vectors.
"""
_ham_split_solution(u::AbstractVector, x0::AbstractVector) =
    let n = length(x0)
        (u[1:n], u[(n + 1):2n])
    end

"""
$(TYPEDSIGNATURES)

Split a combined state–costate matrix into two sub-matrices (column-wise), using
`size(x0, 1)` as the state dimension `n`.

# Returns
- `(u[1:n, :], u[(n+1):2n, :])`: state and costate sub-matrices.
"""
function _ham_split_solution(u::AbstractMatrix, x0::AbstractMatrix)
    let n = size(x0, 1)
        (u[1:n, :], u[(n + 1):2n, :])
    end
end

# =============================================================================
# Semantic Accessors and Delegation
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the vector of time points from the solution.

Delegates to `Integrators.times(sol.result)`.

# Arguments
- `sol::HamiltonianVectorFieldTrajectory`: The Hamiltonian vector field solution.

# Returns
- `AbstractVector`: The vector of time points.

See also: [`CTSolvers.Integrators.AbstractIntegrationResult`](@extref), [`CTSolvers.Integrators.evaluate_at`](@extref).
"""
function Integrators.times(sol::HamiltonianVectorFieldTrajectory)
    return Integrators.times(sol.result)
end

"""
$(TYPEDSIGNATURES)

Alias for `times(sol)` — returns the time grid from the solution.

This is a method of the [`CTModels.Components.time_grid`](@extref) generic, contributed by
CTFlows for `HamiltonianVectorFieldTrajectory`: an alternative, more explicit name for
`times` in numerical contexts where "time grid" is the standard terminology.

# Arguments
- `sol::HamiltonianVectorFieldTrajectory`: The Hamiltonian vector field solution.

# Returns
- `AbstractVector`: The vector of time points.

See also: [`CTSolvers.Integrators.times`](@extref), [`CTFlows.Trajectories.state`](@ref), [`CTModels.Components.time_grid`](@extref).
"""
function Components.time_grid(sol::HamiltonianVectorFieldTrajectory)
    return Integrators.times(sol)
end

"""
$(TYPEDSIGNATURES)

Evaluate the solution at a given time, returning a tuple `(x(t), p(t))`.

Splits the combined state vector into state and costate halves.

# Arguments
- `sol::HamiltonianVectorFieldTrajectory`: The Hamiltonian vector field solution.
- `t::Real`: The time at which to evaluate the solution.

# Returns
- `Tuple{AbstractVector, AbstractVector}`: The state `x(t)` and costate `p(t)` at time `t`.

See also: [`CTSolvers.Integrators.evaluate_at`](@extref), [`CTSolvers.Integrators.times`](@extref).
"""
function (sol::HamiltonianVectorFieldTrajectory)(t::Real)
    u = Integrators.evaluate_at(sol.result, t)
    return _ham_split_solution(u, sol.x0)
end

"""
$(TYPEDEF)

Callable struct returning the state component of a `HamiltonianVectorFieldTrajectory`.

`StateProjection(result, x0)(t)` is equivalent to `sol(t)[1]`. It wraps the inner
integration result and `x0` (not the trajectory itself), so it is constructed once at
trajectory construction and stored, and the `state(sol)` accessor returns it without
rebuilding a functor on every call.
"""
struct StateProjection{R<:Integrators.AbstractIntegrationResult,X0} <: Function
    result::R
    x0::X0
end

"""
$(TYPEDSIGNATURES)

Evaluate the state projection at time `t`: returns `x(t)`, the state component of the
underlying `HamiltonianVectorFieldTrajectory`.

Equivalent to `sol(t)[1]`.
"""
function (sp::StateProjection)(t::Real)
    return _ham_split_solution(Integrators.evaluate_at(sp.result, t), sp.x0)[1]
end

"""
$(TYPEDSIGNATURES)

Build a `StateProjection` from a `HamiltonianVectorFieldTrajectory` (its `result`/`x0`).
"""
StateProjection(sol::HamiltonianVectorFieldTrajectory) = StateProjection(sol.result, sol.x0)

"""
$(TYPEDEF)

Callable struct returning the costate component of a `HamiltonianVectorFieldTrajectory`.

`CostateProjection(result, x0)(t)` is equivalent to `sol(t)[2]`. It wraps the inner
integration result and `x0` (not the trajectory itself), so it is constructed once at
trajectory construction and stored, and the `costate(sol)` accessor returns it without
rebuilding a functor on every call.
"""
struct CostateProjection{R<:Integrators.AbstractIntegrationResult,X0} <: Function
    result::R
    x0::X0
end

"""
$(TYPEDSIGNATURES)

Evaluate the costate projection at time `t`: returns `p(t)`, the costate component of the
underlying `HamiltonianVectorFieldTrajectory`.

Equivalent to `sol(t)[2]`.
"""
function (cp::CostateProjection)(t::Real)
    return _ham_split_solution(Integrators.evaluate_at(cp.result, t), cp.x0)[2]
end

"""
$(TYPEDSIGNATURES)

Build a `CostateProjection` from a `HamiltonianVectorFieldTrajectory` (its `result`/`x0`).
"""
function CostateProjection(sol::HamiltonianVectorFieldTrajectory)
    return CostateProjection(sol.result, sol.x0)
end

"""
$(TYPEDSIGNATURES)

Return the solution as a state function of time `x(t)`.

This is a method of the [`CTModels.Components.state`](@extref) generic, contributed by
CTFlows for `HamiltonianVectorFieldTrajectory`. Returns a
[`CTFlows.Trajectories.StateProjection`](@ref) wrapping the solution, callable as `x(t)`.

# Arguments
- `sol::HamiltonianVectorFieldTrajectory`: The Hamiltonian vector field solution.

# Returns
- `StateProjection`: A callable `t -> x(t)` that returns the state at time `t`.

# Example
```julia
using CTFlows.Trajectories

sol = HamiltonianVectorFieldTrajectory(result)
x = state(sol)    # x is a callable StateProjection
x(0.0)            # initial state
x(0.5)            # interpolated state at t = 0.5
```

See also: [`CTFlows.Trajectories.costate`](@ref), [`CTSolvers.Integrators.times`](@extref), [`CTModels.Components.state`](@extref).
"""
function Components.state(sol::HamiltonianVectorFieldTrajectory)
    return sol.state_proj
end

"""
$(TYPEDSIGNATURES)

Return the solution as a costate function of time `p(t)`.

This is a method of the [`CTModels.Components.costate`](@extref) generic, contributed by
CTFlows for `HamiltonianVectorFieldTrajectory`. Returns a
[`CTFlows.Trajectories.CostateProjection`](@ref) wrapping the solution, callable as `p(t)`.

# Arguments
- `sol::HamiltonianVectorFieldTrajectory`: The Hamiltonian vector field solution.

# Returns
- `CostateProjection`: A callable `t -> p(t)` that returns the costate at time `t`.

# Example
```julia
using CTFlows.Trajectories

sol = HamiltonianVectorFieldTrajectory(result)
p = costate(sol)  # p is a callable CostateProjection
p(0.0)            # initial costate
p(0.5)            # interpolated costate at t = 0.5
```

See also: [`CTFlows.Trajectories.state`](@ref), [`CTSolvers.Integrators.times`](@extref), [`CTModels.Components.costate`](@extref).
"""
function Components.costate(sol::HamiltonianVectorFieldTrajectory)
    return sol.costate_proj
end

"""
$(TYPEDSIGNATURES)

Return the raw final ODE state vector `[xf; pf]` from the integration result.

Delegates directly to the underlying integration result without splitting.
Callers that need the split form should use `_ham_split_solution` explicitly.

# Arguments
- `sol::HamiltonianVectorFieldTrajectory`: The Hamiltonian vector field solution.

# Returns
- `AbstractVector`: The concatenated final state `[xf; pf]`.

See also: [`CTSolvers.Integrators.AbstractIntegrationResult`](@extref), [`CTSolvers.Integrators.final_state`](@extref).
"""
function Integrators.final_state(sol::HamiltonianVectorFieldTrajectory)
    u = Integrators.final_state(sol.result)
    return _ham_split_solution(u, sol.x0)
end

"""
$(TYPEDSIGNATURES)

Return the termination status of the solution by delegating to the integration result.

# Arguments
- `sol::HamiltonianVectorFieldTrajectory`: The Hamiltonian vector field solution.

# Returns
- The termination status (a `Symbol`) from the integration result.

See also: [`CTSolvers.Integrators.AbstractIntegrationResult`](@extref), [`CTSolvers.Integrators.status`](@extref).
"""
function Integrators.status(sol::HamiltonianVectorFieldTrajectory)
    return Integrators.status(sol.result)
end

"""
$(TYPEDSIGNATURES)

Return whether the solution terminated successfully by delegating to the integration result.

# Arguments
- `sol::HamiltonianVectorFieldTrajectory`: The Hamiltonian vector field solution.

# Returns
- Whether the integration succeeded.

See also: [`CTSolvers.Integrators.AbstractIntegrationResult`](@extref), [`CTSolvers.Integrators.successful`](@extref).
"""
function Integrators.successful(sol::HamiltonianVectorFieldTrajectory)
    return Integrators.successful(sol.result)
end

"""
$(TYPEDSIGNATURES)

Merge a sequence of HamiltonianVectorFieldTrajectory objects into a single HamiltonianVectorFieldTrajectory.

This extracts the internal integration results, merges them, and wraps the result
in a new HamiltonianVectorFieldTrajectory.

# Arguments
- `segments::AbstractVector{<:HamiltonianVectorFieldTrajectory}`: Sequence of Hamiltonian vector field solutions to merge.

# Returns
- `HamiltonianVectorFieldTrajectory`: A merged Hamiltonian vector field solution containing the merged integration result.

See also: [`CTSolvers.Integrators.merge`](@extref), [`CTSolvers.Integrators.AbstractIntegrationResult`](@extref).
"""
function Integrators.merge(segments::AbstractVector{<:HamiltonianVectorFieldTrajectory})
    if isempty(segments)
        throw(
            Exceptions.IncorrectArgument(
                "Cannot merge empty sequence of HamiltonianVectorFieldTrajectory";
                got="0 segments",
                expected="at least 1 segment",
                context="HamiltonianVectorFieldTrajectory merge",
            ),
        )
    end

    internal_results = [sol.result for sol in segments]
    merged_result = Integrators.merge(internal_results)
    return HamiltonianVectorFieldTrajectory(
        segments[1].x0, merged_result, segments[1].variable
    )
end

# =============================================================================
# Stub methods — to be extended by CTFlowsPlots
# =============================================================================

"""
$(TYPEDSIGNATURES)

Plot stub — throws error if Plots extension not loaded.

# Arguments
- `sol::AbstractHamiltonianVectorFieldTrajectory`: The Hamiltonian vector field solution.
- `kwargs...`: Additional plotting keyword arguments (ignored).

# Throws
- `CTBase.Exceptions.ExtensionError`: If Plots extension is not loaded.

See also: [`CTFlows.Trajectories.HamiltonianVectorFieldTrajectory`](@ref), [`CTFlows.Trajectories.AbstractHamiltonianVectorFieldTrajectory`](@ref).
"""
function RecipesBase.plot(sol::AbstractHamiltonianVectorFieldTrajectory; kwargs...)
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

Display the `HamiltonianVectorFieldTrajectory` in a readable text/plain format.

# Arguments
- `io::IO`: The IO stream to write to.
- `::MIME"text/plain"`: The MIME type.
- `sol::HamiltonianVectorFieldTrajectory`: The solution to display.
"""
function Base.show(io::IO, ::MIME"text/plain", sol::HamiltonianVectorFieldTrajectory)
    fmt = Display.format_codes(io)
    Display.print_header(io, "HamiltonianVectorFieldTrajectory"; fmt=fmt)
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
        xf, pf = Integrators.final_state(sol)
        push!(fields, ("final state", xf, fmt.value))
        push!(fields, ("final costate", pf, fmt.value))
    catch
    end
    if _show_variable(sol.variable)
        push!(fields, ("variable", sol.variable, fmt.value))
    end
    return Display.print_fields(io, fields; fmt=fmt)
end

"""
$(TYPEDSIGNATURES)

Display the `HamiltonianVectorFieldTrajectory` in a compact one-line format.

# Arguments
- `io::IO`: The IO stream to write to.
- `sol::HamiltonianVectorFieldTrajectory`: The solution to display.
"""
function Base.show(io::IO, sol::HamiltonianVectorFieldTrajectory)
    fmt = Display.format_codes(io)
    print(io, fmt.name, "HamiltonianVectorFieldTrajectory", fmt.reset, "(")
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
