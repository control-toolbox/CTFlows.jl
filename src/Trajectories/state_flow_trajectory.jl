# =============================================================================
# StateFlowTrajectory — a trajectory of a controlled dynamical system:
# state x(t) plus a reconstructed control u(t) = law(t, x(t), v). No costate.
# =============================================================================

"""
$(TYPEDEF)

Trajectory of a **controlled** dynamical system, as produced by an `OpenLoop` or
`ClosedLoop` control flow. It carries the state trajectory together with the control
law, from which the control is reconstructed along the trajectory. There is **no
costate** (the underlying flow is a state flow) and no objective.

# Fields
- `traj::T`: the underlying state trajectory (a [`CTFlows.Trajectories.VectorFieldTrajectory`](@extref)).
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

See also: [`CTFlows.Trajectories.VectorFieldTrajectory`](@extref),
[`CTFlows.Trajectories.state`](@extref), [`CTFlows.Trajectories.control`](@extref).
"""
struct StateFlowTrajectory{T<:VectorFieldTrajectory,L,V,O,C,M,SP,CP} <:
       AbstractVectorFieldTrajectory
    traj::T
    law::L
    variable::V
    objective::O
    state_coerce::C
    ocp::M
    state_proj::SP
    control_proj::CP
end

"""
$(TYPEDSIGNATURES)

Construct a `StateFlowTrajectory`, precomputing the state and control projections once so
the `state`/`control` accessors return a stored functor instead of rebuilding one on every
call. The control projection is `nothing` when there is no control law (`law === nothing`,
a basic control-free `Flow(ocp)`), in which case `control(sol)` raises a clear error.
"""
function StateFlowTrajectory(
    traj::VectorFieldTrajectory, law, variable, objective, state_coerce, ocp
)
    sp = ControlledStateProjection(traj, state_coerce)
    cp = _build_control_proj(law, traj, variable, state_coerce)
    return StateFlowTrajectory{
        typeof(traj),
        typeof(law),
        typeof(variable),
        typeof(objective),
        typeof(state_coerce),
        typeof(ocp),
        typeof(sp),
        typeof(cp),
    }(
        traj, law, variable, objective, state_coerce, ocp, sp, cp
    )
end

"""
$(TYPEDSIGNATURES)

No control projection when there is no control law (a basic control-free `Flow(ocp)`).
"""
_build_control_proj(::Nothing, traj, variable, coerce) = nothing
"""
$(TYPEDSIGNATURES)

Build the (precomputed) [`CTFlows.Trajectories.ControlProjection`](@extref) from the law and
the inner trajectory.
"""
function _build_control_proj(law, traj, variable, coerce)
    return ControlProjection(traj, law, variable, coerce)
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
[`CTFlows.Trajectories.StateFlowTrajectory`](@extref). The coercion (`only`/`identity`) is
precomputed and stored, so no length is tested at run time.
"""
struct ControlledStateProjection{T<:VectorFieldTrajectory,C} <: Function
    traj::T
    coerce::C
end
"""
$(TYPEDSIGNATURES)

Return the (1-D = scalar coerced) state at time `t` from a
[`CTFlows.Trajectories.ControlledStateProjection`](@extref).
"""
(sp::ControlledStateProjection)(t::Real) = sp.coerce(sp.traj(t))

"""
$(TYPEDEF)

Callable struct returning the reconstructed control of a
[`CTFlows.Trajectories.StateFlowTrajectory`](@extref):
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

Return the state function `x(t)` of a `StateFlowTrajectory` (scalar for a 1-D state).

This is a method of the [`CTModels.Components.state`](@extref) generic, contributed by
CTFlows for `StateFlowTrajectory`. Returns the stored
[`CTFlows.Trajectories.ControlledStateProjection`](@extref) precomputed at construction.

See also: [`CTFlows.Trajectories.control`](@extref), [`CTModels.Components.state`](@extref).
"""
Components.state(sol::StateFlowTrajectory) = sol.state_proj

"""
$(TYPEDSIGNATURES)

Return the reconstructed control function `u(t) = law(t, x(t), v)` of a
`StateFlowTrajectory`, as the stored [`CTFlows.Trajectories.ControlProjection`](@extref).

This is a method of the [`CTModels.Components.control`](@extref) generic, contributed by
CTFlows for `StateFlowTrajectory`.

Raises a [`CTBase.Exceptions.PreconditionError`](@extref) when the trajectory was built
without a control law (a basic control-free `Flow(ocp)`), which has no control to
reconstruct.

See also: [`CTFlows.Trajectories.state`](@extref), [`CTModels.Components.control`](@extref).
"""
Components.control(sol::StateFlowTrajectory) = _sft_control(sol.control_proj)

"""
$(TYPEDSIGNATURES)

Return the stored [`CTFlows.Trajectories.ControlProjection`](@extref) as-is, or throw a
[`CTBase.Exceptions.PreconditionError`](@extref) when the trajectory has no control
projection (`cp === nothing`, a basic control-free `Flow(ocp)`). Dispatch helper for
[`CTFlows.Trajectories.control`](@extref).
"""
_sft_control(cp::ControlProjection) = cp

"""
$(TYPEDSIGNATURES)

Throw a `PreconditionError` because the `StateFlowTrajectory` has no control projection
(`cp === nothing`, a basic control-free `Flow(ocp)`).

This happens when the flow was built without a control law (e.g. for direct shooting),
so there is no control to reconstruct.
"""
function _sft_control(::Nothing)
    return throw(
        Exceptions.PreconditionError(
            "this StateFlowTrajectory has no control";
            reason="it was built without a control law (a basic control-free Flow(ocp), " *
                   "e.g. for direct shooting), so there is no control to reconstruct",
            suggestion="use state(sol); control only exists for flows built with a control law",
            context="StateFlowTrajectory — control getter",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Return the time grid of a `StateFlowTrajectory`.
"""
Integrators.times(sol::StateFlowTrajectory) = Integrators.times(sol.traj)

"""
$(TYPEDSIGNATURES)

Alias for `times(sol)` — the time grid of a `StateFlowTrajectory`.

This is a method of the [`CTModels.Components.time_grid`](@extref) generic, contributed by
CTFlows for `StateFlowTrajectory`.
"""
Components.time_grid(sol::StateFlowTrajectory) = Integrators.times(sol.traj)

"""
$(TYPEDSIGNATURES)

Return the final state of a `StateFlowTrajectory`.
"""
Integrators.final_state(sol::StateFlowTrajectory) = Integrators.final_state(sol.traj)

"""
$(TYPEDSIGNATURES)

Return the termination status of a `StateFlowTrajectory`, delegating to the underlying
state trajectory.
"""
Integrators.status(sol::StateFlowTrajectory) = Integrators.status(sol.traj)

"""
$(TYPEDSIGNATURES)

Return whether a `StateFlowTrajectory` terminated successfully, delegating to the
underlying state trajectory.
"""
Integrators.successful(sol::StateFlowTrajectory) = Integrators.successful(sol.traj)

"""
$(TYPEDSIGNATURES)

Evaluate the state at time `t` (scalar for a 1-D state).
"""
(sol::StateFlowTrajectory)(t::Real) = sol.state_coerce(sol.traj(t))

"""
$(TYPEDSIGNATURES)

Return the objective value of a `StateFlowTrajectory` (Mayer + Lagrange, with the
control reconstructed from the law). Available only when the trajectory was built from
an OCP (trajectory mode); otherwise a clear error is raised.

This is a method of the [`CTModels.Components.objective`](@extref) generic, contributed by
CTFlows for `StateFlowTrajectory`.

See also: [`CTFlows.Trajectories.state`](@extref), [`CTFlows.Trajectories.control`](@extref), [`CTModels.Components.objective`](@extref).
"""
function Components.objective(
    sol::StateFlowTrajectory{T,L,V,<:Real}
) where {T<:VectorFieldTrajectory,L,V}
    return sol.objective
end

"""
$(TYPEDSIGNATURES)

Throw a [`CTBase.Exceptions.PreconditionError`](@extref) when the objective is not
available (the trajectory was built without an OCP, e.g. from `Flow(fc, law)`).

This is a method of the [`CTModels.Components.objective`](@extref) generic, contributed by
CTFlows for `StateFlowTrajectory`.

See also: [`CTFlows.Trajectories.objective`](@extref), [`CTModels.Components.objective`](@extref).
"""
function Components.objective(
    sol::StateFlowTrajectory{T,L,V,Nothing}
) where {T<:VectorFieldTrajectory,L,V}
    return throw(
        Exceptions.PreconditionError(
            "this StateFlowTrajectory has no objective value";
            reason="it was built without an optimal control problem (e.g. from " *
                   "Flow(fc, law) rather than Flow(ocp, law)), so there is no cost to evaluate",
            suggestion="build the flow from an OCP — Flow(ocp, law) — to obtain the objective, " *
                       "or use state(sol) and control(sol)",
            context="StateFlowTrajectory — objective getter",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

A `StateFlowTrajectory` has **no costate** — it is the trajectory of a controlled
state flow (`OpenLoop`/`ClosedLoop`), not a Hamiltonian flow. Raises a
`PreconditionError` pointing at the available getters.

This is a method of the [`CTModels.Components.costate`](@extref) generic, contributed by
CTFlows for `StateFlowTrajectory`.

See also: [`CTFlows.Trajectories.state`](@extref), [`CTFlows.Trajectories.control`](@extref), [`CTModels.Components.costate`](@extref).
"""
function Components.costate(sol::StateFlowTrajectory)
    return throw(
        Exceptions.PreconditionError(
            "a StateFlowTrajectory has no costate";
            reason="it is the trajectory of a controlled state flow (OpenLoop/ClosedLoop), " *
                   "which integrates ẋ = f(t, x, u(...), v) with no costate — unlike a " *
                   "DynClosedLoop (Hamiltonian) flow",
            suggestion="use state(sol) and control(sol); costate only exists for Hamiltonian flows",
            context="StateFlowTrajectory — costate getter",
        ),
    )
end

# =============================================================================
# Base.show
# =============================================================================

"""
$(TYPEDSIGNATURES)

Pretty-print a [`CTFlows.Trajectories.StateFlowTrajectory`](@extref) to `io` (multi-line
format with tspan, time points, final state, variable, and objective when available).
"""
function Base.show(io::IO, ::MIME"text/plain", sol::StateFlowTrajectory)
    fmt = Display.format_codes(io)
    Display.print_header(io, "StateFlowTrajectory"; fmt=fmt)
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

Compact one-line representation of a [`CTFlows.Trajectories.StateFlowTrajectory`](@extref).
"""
function Base.show(io::IO, sol::StateFlowTrajectory)
    print(io, "StateFlowTrajectory(")
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
