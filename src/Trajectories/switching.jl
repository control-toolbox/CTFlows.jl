# =============================================================================
# Switching structure of a trajectory: switching times, phase labels, limits
#
# A multi-phase trajectory is left-continuous at a switching time tᵢ: `sol(tᵢ)` and the
# accessors return the value before the jump. The value after it (a jump of the state or
# costate, a change of control law) is read with `right_limit`. The phase labels come from
# the flows (`Flow(...; label=...)`) and are kept through concatenation.
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the switching times of a trajectory: the times between consecutive phases of a
multi-phase flow, strictly increasing; empty for a single-phase trajectory.

See also: [`CTFlows.Trajectories.phase_labels`](@extref), [`CTFlows.Trajectories.right_limit`](@extref).
"""
function switching_times(
    sol::Union{VectorFieldTrajectory,HamiltonianVectorFieldTrajectory}
)::Vector{Float64}
    return collect(Float64, Integrators.switching_times(sol.result))
end
switching_times(sol::StateFlowTrajectory)::Vector{Float64} = switching_times(sol.traj)

"""
$(TYPEDSIGNATURES)

Return the phase labels of a trajectory, one per phase (`""` for a phase with no label);
empty when no flow of the trajectory was labelled.

See also: [`CTFlows.Flows.label`](@extref), [`CTFlows.Trajectories.switching_times`](@extref).
"""
function phase_labels(
    sol::Union{VectorFieldTrajectory,HamiltonianVectorFieldTrajectory}
)::Vector{String}
    return sol.labels
end
phase_labels(sol::StateFlowTrajectory)::Vector{String} = phase_labels(sol.traj)

"""
$(TYPEDSIGNATURES)

Return a copy of a trajectory with the phase labels `labels`, one per phase (the
integration result is shared). Labels that are all empty are dropped, so that an
unlabelled trajectory keeps no label.

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): if there is not one label per phase.
"""
function with_labels(sol::VectorFieldTrajectory, labels::AbstractVector{<:AbstractString})
    kept = _kept_labels(sol, labels)
    return VectorFieldTrajectory(sol.result, sol.variable, sol.x0, kept)
end
function with_labels(
    sol::HamiltonianVectorFieldTrajectory, labels::AbstractVector{<:AbstractString}
)
    kept = _kept_labels(sol, labels)
    return HamiltonianVectorFieldTrajectory(sol.x0, sol.result, sol.variable, kept)
end
function with_labels(sol::StateFlowTrajectory, labels::AbstractVector{<:AbstractString})
    return StateFlowTrajectory(
        with_labels(sol.traj, labels),
        sol.law,
        sol.variable,
        sol.objective,
        sol.state_coerce,
        sol.ocp,
    )
end

"""
$(TYPEDSIGNATURES)

Return the labels of `sol` to keep: none when every label is empty, all of them otherwise.

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): if there is not one label per phase of
  `sol`.
"""
function _kept_labels(sol, labels::AbstractVector{<:AbstractString})::Vector{String}
    all(isempty, labels) && return String[]
    n = length(switching_times(sol)) + 1
    length(labels) == n || throw(
        Exceptions.IncorrectArgument(
            "one label per phase";
            got="$(length(labels)) label(s) for $n phase(s)",
            expected="$n labels (one more than the switching times)",
            suggestion="give \"\" for a phase with no label",
            context="Trajectories.with_labels",
        ),
    )
    return collect(String, labels)
end

"""
$(TYPEDSIGNATURES)

Return the sequence of phase labels as written by the displays, e.g. `"bang → · → singular"`:
the labels joined by arrows, a phase with no label written `·` so that every phase keeps
its place between the switching times.

See also: [`CTFlows.Trajectories.phase_labels`](@extref).
"""
function _phase_sequence(labels::AbstractVector{<:AbstractString})::String
    return join((isempty(l) ? "·" : l for l in labels), " → ")
end

"""
$(TYPEDSIGNATURES)

Return the display fields of the switching structure of a trajectory: the switching times
when there are any, the sequence of phase labels when at least one phase is labelled
(nothing is shown for an unlabelled trajectory).

See also: [`CTFlows.Trajectories._phase_sequence`](@extref).
"""
function _switching_fields(sol, fmt)
    fields = Any[]
    times = switching_times(sol)
    isempty(times) || push!(fields, ("switching times", times, fmt.value))
    labels = phase_labels(sol)
    any(!isempty, labels) &&
        push!(fields, ("phases", _phase_sequence(labels), fmt.value))
    return fields
end

"""
$(TYPEDSIGNATURES)

Return the compact display parts of the switching structure of a trajectory (see
[`CTFlows.Trajectories._switching_fields`](@extref)).
"""
function _switching_parts(sol)
    parts = String[]
    times = switching_times(sol)
    isempty(times) || push!(parts, "switching_times=$(times)")
    labels = phase_labels(sol)
    any(!isempty, labels) && push!(parts, "phases=$(_phase_sequence(labels))")
    return parts
end

"""
$(TYPEDSIGNATURES)

Check that `i` is the index of a switching time of `sol`.

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): if it is not.
"""
function _check_switch_index(sol, i::Integer, context::String)
    n = length(switching_times(sol))
    1 <= i <= n || throw(
        Exceptions.IncorrectArgument(
            "no switching time with this index";
            got="i = $i",
            expected=n == 0 ? "no index: the trajectory has a single phase" : "1 ≤ i ≤ $n",
            suggestion="use an index of switching_times(sol)",
            context=context,
        ),
    )
    return nothing
end

"""
$(TYPEDSIGNATURES)

Throw the error of a component a trajectory does not have.

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): always.
"""
function _throw_component(sol, component::Symbol, expected::String)
    throw(
        Exceptions.IncorrectArgument(
            "unknown component for this trajectory";
            got=":$component for a $(nameof(typeof(sol)))",
            expected=expected,
            suggestion="use one of the components of this trajectory: $expected",
            context="right_limit / left_limit",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Return the value of `component` just after the `i`-th switching time `tᵢ`, after a jump of
the state or costate or a change of control law. The trajectory itself is left-continuous:
it returns the value before, see [`CTFlows.Trajectories.left_limit`](@extref).

`component` is `:state` for a [`CTFlows.Trajectories.VectorFieldTrajectory`](@extref);
`:state` or `:costate` for a [`CTFlows.Trajectories.HamiltonianVectorFieldTrajectory`](@extref);
`:state` or `:control` for a [`CTFlows.Trajectories.StateFlowTrajectory`](@extref). A
one-dimensional component is a scalar.

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): if `i` is not the index of a switching
  time, or the trajectory has no such component.

See also: [`CTFlows.Trajectories.switching_times`](@extref).
"""
function right_limit(sol::VectorFieldTrajectory, component::Symbol, i::Integer)
    component === :state || _throw_component(sol, component, ":state")
    _check_switch_index(sol, i, "right_limit")
    return Systems._coerce_state(sol.x0)(Integrators.right_limit(sol.result, i))
end
function right_limit(sol::HamiltonianVectorFieldTrajectory, component::Symbol, i::Integer)
    component in (:state, :costate) || _throw_component(sol, component, ":state or :costate")
    _check_switch_index(sol, i, "right_limit")
    x, p = _ham_split_solution(Integrators.right_limit(sol.result, i), sol.x0)
    return component === :state ? x : p
end
function right_limit(sol::StateFlowTrajectory, component::Symbol, i::Integer)
    component in (:state, :control) || _throw_component(sol, component, ":state or :control")
    _check_switch_index(sol, i, "right_limit")
    x = sol.state_coerce(Integrators.right_limit(sol.traj.result, i))
    component === :state && return x
    sol.law === nothing && _throw_component(sol, component, ":state (no control law)")
    t = switching_times(sol)[i]
    return _right_controlled_u(sol.law, i, t, x, _cp_variable(sol.variable))
end

"""
$(TYPEDSIGNATURES)

Return the value of `component` at the `i`-th switching time `tᵢ`, before the jump: the
value the trajectory itself returns at `tᵢ`. Same components as
[`CTFlows.Trajectories.right_limit`](@extref).

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): if `i` is not the index of a switching
  time, or the trajectory has no such component.
"""
function left_limit(sol::VectorFieldTrajectory, component::Symbol, i::Integer)
    component === :state || _throw_component(sol, component, ":state")
    _check_switch_index(sol, i, "left_limit")
    return state(sol)(switching_times(sol)[i])
end
function left_limit(sol::HamiltonianVectorFieldTrajectory, component::Symbol, i::Integer)
    component in (:state, :costate) || _throw_component(sol, component, ":state or :costate")
    _check_switch_index(sol, i, "left_limit")
    f = component === :state ? state(sol) : costate(sol)
    return f(switching_times(sol)[i])
end
function left_limit(sol::StateFlowTrajectory, component::Symbol, i::Integer)
    component in (:state, :control) || _throw_component(sol, component, ":state or :control")
    _check_switch_index(sol, i, "left_limit")
    component === :control && sol.law === nothing &&
        _throw_component(sol, component, ":state (no control law)")
    f = component === :state ? state(sol) : control(sol)
    return f(switching_times(sol)[i])
end

"""
$(TYPEDSIGNATURES)

Control just after the `i`-th switching time `t`, from the state `x` after the jump: the
law of the next phase. A single law has no phase, so it is the law itself;
`CTFlows.MultiPhase` adds the method of the piecewise law of a multi-phase flow.
"""
_right_controlled_u(law, ::Integer, t, x, v) = _controlled_u(law, t, x, v)
