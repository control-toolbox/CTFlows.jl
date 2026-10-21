# =============================================================================
# Building PlotEngine.Panels from a trajectory via the semantic accessors
# =============================================================================

"""
$(TYPEDSIGNATURES)

Subscript form of a component index: `1` → `"₁"`, `12` → `"₁₂"`.
"""
_sub(i::Integer) = join(Char(0x2080 + (c - '0')) for c in string(i))

"""
$(TYPEDSIGNATURES)

Generated component names, used when the trajectory carries no model: `["x"]` for one
component, `["x₁", "x₂", …]` otherwise.
"""
function _gen_names(sym::AbstractString, n::Integer)
    return n == 1 ? [String(sym)] : [sym * _sub(i) for i in 1:n]
end

"""
$(TYPEDSIGNATURES)

Sample a callable `f` over the times `ts` into an `(n_times × n_components)` matrix. A scalar
(1-D) and a vector-valued `f` are handled alike.
"""
_sample(f, ts) = Matrix{Float64}(reduce(hcat, f.(ts))')

"""
$(TYPEDSIGNATURES)

Return the limits of `component` at the switching times of `sol` as the `(left, right)`
matrices of [`CTBase.Plotting.splice_jumps`](@extref): one row per switching time, one
column per component. They are read with [`CTFlows.Trajectories.left_limit`](@extref) and
[`CTFlows.Trajectories.right_limit`](@extref).
"""
function _limits(sol, component::Symbol)
    n = length(Trajectories.switching_times(sol))
    rows(f) = permutedims(reduce(hcat, (vcat(f(sol, component, i)) for i in 1:n)))
    return (rows(Trajectories.left_limit), rows(Trajectories.right_limit))
end

"""
$(TYPEDSIGNATURES)

Insert the left and right limits of `component` at the switching times of `sol` into the
samples `(ts, M)` of that component, with [`CTBase.Plotting.splice_jumps`](@extref): a jump
is drawn as a vertical segment, or, with `connect = false`, the curve is broken between
the two limits. The samples are returned unchanged when the trajectory has no switching
time.

# Returns
- `(ts, M)`: the time grid (each switching time twice) and the matrix of samples.
"""
function _spliced_samples(
    sol, ts::AbstractVector, M::AbstractMatrix, component::Symbol; connect::Bool=true
)
    taus = Trajectories.switching_times(sol)
    isempty(taus) && return (ts, M)
    return Plotting.splice_jumps(ts, M, taus, _limits(sol, component)...; connect=connect)
end

"""
$(TYPEDSIGNATURES)

Euclidean norm of a row, written out to avoid a `LinearAlgebra` dependency.
"""
_rownorm(row) = sqrt(sum(abs2, row))

# =============================================================================
# Component names: from the OCP model when the trajectory carries one, else generated.
# Only a StateFlowTrajectory built from an OCP (Flow(ocp, law)) carries a model.
# =============================================================================

"""
$(TYPEDSIGNATURES)

The OCP model a trajectory carries, or `nothing`. Only a `StateFlowTrajectory` built from an
OCP (`Flow(ocp, law)`) carries one.
"""
_traj_model(sol) = nothing
_traj_model(sol::Trajectories.StateFlowTrajectory) = sol.ocp

"""
$(TYPEDSIGNATURES)

Names of the `n` state components: from the OCP model when the trajectory carries one, else
generated (`x`, `x₁`, …).
"""
function _state_names(sol, n)
    return if _traj_model(sol) === nothing
        _gen_names("x", n)
    else
        CTModels.state_components(_traj_model(sol))
    end
end

"""
$(TYPEDSIGNATURES)

Names of the `m` control components: from the OCP model when the trajectory carries one,
else generated (`u`, `u₁`, …).
"""
function _control_names(sol, m)
    return if _traj_model(sol) === nothing
        _gen_names("u", m)
    else
        CTModels.control_components(_traj_model(sol))
    end
end

"""
$(TYPEDSIGNATURES)

Name of the control as a whole (for the label of its norm): from the OCP model, else `"u"`.
"""
function _control_name(sol)
    return _traj_model(sol) === nothing ? "u" : CTModels.control_name(_traj_model(sol))
end

"""
$(TYPEDSIGNATURES)

Time-axis name for a trajectory: the OCP's time name when available, else `"t"`.
"""
_time_name(sol) = _traj_model(sol) === nothing ? "t" : CTModels.time_name(_traj_model(sol))

# =============================================================================
# Panel builders
# =============================================================================

"""
$(TYPEDSIGNATURES)

The state panel: `state(sol)` sampled at `ts`, one curve per component, with the jumps at
the switching times drawn as vertical segments.
"""
function _state_panel(sol, ts, style::NamedTuple; connect::Bool=true)
    M = _sample(Trajectories.state(sol), ts)
    T, M = _spliced_samples(sol, ts, M, :state; connect=connect)
    return Plotting.Panel(T, M; title="state", labels=_state_names(sol, size(M, 2)), style)
end

"""
$(TYPEDSIGNATURES)

The costate panel: `costate(sol)` sampled at `ts`. When the state is drawn alongside (paired
columns), the state labels name the rows, so the costate curves carry no label, as in
CTModels.
"""
function _costate_panel(sol, ts, style::NamedTuple; state_shown::Bool, connect::Bool=true)
    M = _sample(Trajectories.costate(sol), ts)
    T, M = _spliced_samples(sol, ts, M, :costate; connect=connect)
    n = size(M, 2)
    labels = state_shown ? fill("", n) : _gen_names("p", n)
    return Plotting.Panel(T, M; title="costate", labels, style)
end

"""
$(TYPEDSIGNATURES)

The control panel: `control(sol)` sampled at `ts`, drawn as its components
(`control=:components`), its norm (`:norm`) or both (`:all`).

# Throws
- `CTBase.Exceptions.IncorrectArgument`: for any other value of `control`.
"""
function _control_panel(sol, ts, control::Symbol, style::NamedTuple; connect::Bool=true)
    U = _sample(Trajectories.control(sol), ts)
    T, U = _spliced_samples(sol, ts, U, :control; connect=connect)
    m = size(U, 2)
    if control === :components
        data, labels = U, _control_names(sol, m)
    elseif control === :norm
        data = reshape([_rownorm(@view U[k, :]) for k in axes(U, 1)], :, 1)
        labels = ["‖" * _control_name(sol) * "‖"]
    elseif control === :all
        nrm = reshape([_rownorm(@view U[k, :]) for k in axes(U, 1)], :, 1)
        data = hcat(U, nrm)
        labels = vcat(_control_names(sol, m), ["‖" * _control_name(sol) * "‖"])
    else
        throw(
            Exceptions.IncorrectArgument(
                "Invalid control choice";
                got="control=$control",
                expected=":components, :norm or :all",
                context="TrajectoryPlots._control_panel",
            ),
        )
    end
    return Plotting.Panel(T, data; title="control", labels, style)
end

"""
$(TYPEDSIGNATURES)

Return whether the control panel is drawn: `:control` is in the description and the
control is not styled `:none`.
"""
_control_shown(description, control_style)::Bool =
    :control in description && control_style !== :none

"""
$(TYPEDSIGNATURES)

Turn a trajectory and a cleaned `description` into `(times, panels, placement)`. Panels
are emitted in the canonical order state → costate → control; a group whose style is
`:none` is skipped. `placement` is `:paired` when both state and costate are drawn (they
sit side by side), otherwise `:stacked`.
"""
function _panels(
    sol,
    description;
    control::Symbol,
    state_style::Union{NamedTuple,Symbol},
    costate_style::Union{NamedTuple,Symbol},
    control_style::Union{NamedTuple,Symbol},
    connect::Bool=true,
)
    ts = Integrators.times(sol)
    panels = Plotting.Panel[]
    state_shown = :state in description && state_style !== :none
    costate_shown = :costate in description && costate_style !== :none

    state_shown && push!(panels, _state_panel(sol, ts, state_style; connect=connect))
    if costate_shown
        cp = _costate_panel(
            sol, ts, costate_style; state_shown=state_shown, connect=connect
        )
        push!(panels, cp)
    end
    if _control_shown(description, control_style)
        push!(panels, _control_panel(sol, ts, control, control_style; connect=connect))
    end

    placement = (state_shown && costate_shown) ? :paired : :stacked
    return ts, panels, placement
end
