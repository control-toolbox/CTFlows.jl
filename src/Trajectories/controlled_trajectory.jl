# =============================================================================
# ControlledTrajectory — a trajectory of a controlled dynamical system:
# state x(t) plus a reconstructed control u(t) = law(t, x(t), v). No costate.
# =============================================================================

"""
$(TYPEDEF)

Trajectory of a **controlled** dynamical system, as produced by an `OpenLoop` or
`ClosedLoop` control flow. It carries the state trajectory together with the control
law, from which the control is reconstructed along the trajectory. There is **no
costate** (the underlying flow is a state flow) and no objective.

# Fields
- `traj::T`: the underlying state trajectory (a [`CTFlows.Trajectories.VectorFieldTrajectory`](@ref)).
- `law::L`: the control law (`OpenLoop` or `ClosedLoop`).
- `variable::V`: the variable threaded through the flow call (or `Core.NotProvided`).
- `objective::O`: the objective value (Mayer + Lagrange with the reconstructed control)
  when the trajectory was built from an OCP, or `nothing` (e.g. from `Flow(fc, law)`).
- `state_coerce::C`: the state coercion (`only` for a 1-D state, `identity` otherwise),
  precomputed once so the state/control projections never test a length at run time.
- `ocp::M`: the OCP model the controlled flow was built from — the source of the
  component names (state/control) and the time name for plotting — or `nothing`
  (e.g. from `Flow(fc, law)`).

# Accessors
- `state(sol)`: callable state function `x(t)`.
- `control(sol)`: callable control function `u(t) = law(t, x(t), v)`.
- `objective(sol)`: the objective value (errors if unavailable).
- `times(sol)` / `time_grid(sol)`: the time grid.
- `sol(t)`: the state at time `t`.
- `costate(sol)`: **errors** — a controlled state trajectory has no costate.

See also: [`CTFlows.Trajectories.VectorFieldTrajectory`](@ref),
[`CTFlows.Trajectories.state`](@ref), [`CTFlows.Trajectories.control`](@ref).
"""
struct ControlledTrajectory{T<:VectorFieldTrajectory,L,V,O,C,M} <:
       AbstractVectorFieldTrajectory
    traj::T
    law::L
    variable::V
    objective::O
    state_coerce::C
    ocp::M
end

# =============================================================================
# Control reconstruction — feedback-dispatched uniform call of the law
# =============================================================================

# open-loop u(t, v) ignores the state, closed-loop u(t, x, v) uses it.
"""
$(TYPEDSIGNATURES)

Reconstruct the control from an `OpenLoop` law: `u(t, v)` (the state is ignored).
"""
function _controlled_u(law::Data.ControlLaw{<:Function,Traits.OpenLoopFeedback}, t, x, v)
    return law(t, v)
end
"""
$(TYPEDSIGNATURES)

Reconstruct the control from a `ClosedLoop` law: `u(t, x, v)`.
"""
function _controlled_u(law::Data.ControlLaw{<:Function,Traits.ClosedLoopFeedback}, t, x, v)
    return law(t, x, v)
end

"""
$(TYPEDSIGNATURES)

Unwrap the variable passed to the flow call: return `nothing` when it was not provided
(`Core.NotProvided`), otherwise return it as-is.
"""
_cp_variable(v) = v isa Core.NotProvidedType ? nothing : v

"""
$(TYPEDEF)

Callable struct returning the (1-D = scalar coerced) state of a
[`CTFlows.Trajectories.ControlledTrajectory`](@ref). The coercion (`only`/`identity`) is
precomputed and stored, so no length is tested at run time.
"""
struct ControlledStateProjection{T<:VectorFieldTrajectory,C} <: Function
    traj::T
    coerce::C
end
"""
$(TYPEDSIGNATURES)

Return the (1-D = scalar coerced) state at time `t` from a
[`CTFlows.Trajectories.ControlledStateProjection`](@ref).
"""
(sp::ControlledStateProjection)(t::Real) = sp.coerce(sp.traj(t))

"""
$(TYPEDEF)

Callable struct returning the reconstructed control of a
[`CTFlows.Trajectories.ControlledTrajectory`](@ref):
`ControlProjection(sol)(t) = law(t, x(t), v)`. A functor (not a closure); the state
coercion is precomputed.
"""
struct ControlProjection{T<:VectorFieldTrajectory,L,V,C} <: Function
    traj::T
    law::L
    variable::V
    coerce::C
end

"""
$(TYPEDSIGNATURES)

Return the reconstructed control at time `t`: `law(t, x(t), v)` with the state coerced
(1-D = scalar).
"""
function (cp::ControlProjection)(t::Real)
    return _controlled_u(cp.law, t, cp.coerce(cp.traj(t)), _cp_variable(cp.variable))
end

# =============================================================================
# Semantic accessors and delegation
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the state function `x(t)` of a `ControlledTrajectory` (scalar for a 1-D state).

See also: [`CTFlows.Trajectories.control`](@ref).
"""
state(sol::ControlledTrajectory) = ControlledStateProjection(sol.traj, sol.state_coerce)

"""
$(TYPEDSIGNATURES)

Return the reconstructed control function `u(t) = law(t, x(t), v)` of a
`ControlledTrajectory`, as a [`CTFlows.Trajectories.ControlProjection`](@ref).

See also: [`CTFlows.Trajectories.state`](@ref).
"""
function control(sol::ControlledTrajectory)
    return ControlProjection(sol.traj, sol.law, sol.variable, sol.state_coerce)
end

"""
$(TYPEDSIGNATURES)

Return the time grid of a `ControlledTrajectory`.
"""
Integrators.times(sol::ControlledTrajectory) = Integrators.times(sol.traj)

"""
$(TYPEDSIGNATURES)

Alias for `times(sol)` — the time grid of a `ControlledTrajectory`.
"""
time_grid(sol::ControlledTrajectory) = Integrators.times(sol.traj)

"""
$(TYPEDSIGNATURES)

Return the final state of a `ControlledTrajectory`.
"""
Integrators.final_state(sol::ControlledTrajectory) = Integrators.final_state(sol.traj)

"""
$(TYPEDSIGNATURES)

Evaluate the state at time `t` (scalar for a 1-D state).
"""
(sol::ControlledTrajectory)(t::Real) = sol.state_coerce(sol.traj(t))

"""
$(TYPEDSIGNATURES)

Return the objective value of a `ControlledTrajectory` (Mayer + Lagrange, with the
control reconstructed from the law). Available only when the trajectory was built from
an OCP (trajectory mode); otherwise a clear error is raised.

See also: [`CTFlows.Trajectories.state`](@ref), [`CTFlows.Trajectories.control`](@ref).
"""
objective(sol::ControlledTrajectory{T,L,V,<:Real}) where {T,L,V} = sol.objective

"""
$(TYPEDSIGNATURES)

Throw a [`CTBase.Exceptions.PreconditionError`](@extref) when the objective is not
available (the trajectory was built without an OCP, e.g. from `Flow(fc, law)`).

See also: [`CTFlows.Trajectories.objective`](@ref).
"""
function objective(sol::ControlledTrajectory{T,L,V,Nothing}) where {T,L,V}
    return throw(
        Exceptions.PreconditionError(
            "this ControlledTrajectory has no objective value";
            reason="it was built without an optimal control problem (e.g. from " *
                   "Flow(fc, law) rather than Flow(ocp, law)), so there is no cost to evaluate",
            suggestion="build the flow from an OCP — Flow(ocp, law) — to obtain the objective, " *
                       "or use state(sol) and control(sol)",
            context="ControlledTrajectory — objective getter",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

A `ControlledTrajectory` has **no costate** — it is the trajectory of a controlled
state flow (`OpenLoop`/`ClosedLoop`), not a Hamiltonian flow. Raises a
`PreconditionError` pointing at the available getters.

See also: [`CTFlows.Trajectories.state`](@ref), [`CTFlows.Trajectories.control`](@ref).
"""
function costate(sol::ControlledTrajectory)
    return throw(
        Exceptions.PreconditionError(
            "a ControlledTrajectory has no costate";
            reason="it is the trajectory of a controlled state flow (OpenLoop/ClosedLoop), " *
                   "which integrates ẋ = f(t, x, u(...), v) with no costate — unlike a " *
                   "DynClosedLoop (Hamiltonian) flow",
            suggestion="use state(sol) and control(sol); costate only exists for Hamiltonian flows",
            context="ControlledTrajectory — costate getter",
        ),
    )
end

# =============================================================================
# Base.show
# =============================================================================

"""
$(TYPEDSIGNATURES)

Pretty-print a [`CTFlows.Trajectories.ControlledTrajectory`](@ref) to `io` (multi-line
format with tspan, time points, final state, variable, and objective when available).
"""
function Base.show(io::IO, ::MIME"text/plain", sol::ControlledTrajectory)
    fmt = Display.format_codes(io)
    Display.print_header(io, "ControlledTrajectory"; fmt=fmt)
    fields = Any[]
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
    if sol.objective !== nothing
        push!(fields, ("objective", sol.objective, fmt.value))
    end
    return Display.print_fields(io, fields; fmt=fmt)
end

"""
$(TYPEDSIGNATURES)

Compact one-line representation of a [`CTFlows.Trajectories.ControlledTrajectory`](@ref).
"""
function Base.show(io::IO, sol::ControlledTrajectory)
    print(io, "ControlledTrajectory(")
    parts = String[]
    try
        ts = Integrators.times(sol)
        isempty(ts) || push!(parts, "tspan=($(first(ts)), $(last(ts))), n=$(length(ts))")
    catch
    end
    _show_variable(sol.variable) && push!(parts, "variable=$(sol.variable)")
    sol.objective === nothing || push!(parts, "objective=$(sol.objective)")
    print(io, join(parts, ", "))
    return print(io, ")")
end
