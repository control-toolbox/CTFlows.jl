# =============================================================================
# Building PlotEngine.Panels from a trajectory via the semantic accessors
# =============================================================================

# Subscript a component index: 1 -> "₁", 12 -> "₁₂".
_sub(i::Integer) = join(Char(0x2080 + (c - '0')) for c in string(i))

# Generated (fallback) component names: scalar -> ["x"], vector -> ["x₁", "x₂", …].
_gen_names(sym::AbstractString, n::Integer) =
    n == 1 ? [String(sym)] : [sym * _sub(i) for i in 1:n]

# Sample a callable `f` over the time grid into an (n_times × n_components) matrix.
# Handles scalar (1-D) and vector-valued callables uniformly, like the accessors do.
_sample(f, ts) = Matrix{Float64}(reduce(hcat, f.(ts))')

# Euclidean norm of a row (inlined to avoid a LinearAlgebra dependency in the extension).
_rownorm(row) = sqrt(sum(abs2, row))

# =============================================================================
# Component names: from the OCP model when the trajectory carries one, else generated.
# Only a ControlledTrajectory built from an OCP (Flow(ocp, law)) carries a model.
# =============================================================================

_traj_model(sol) = nothing
_traj_model(sol::Trajectories.ControlledTrajectory) = sol.ocp

_state_names(sol, n) =
    _traj_model(sol) === nothing ? _gen_names("x", n) :
    CTModels.state_components(_traj_model(sol))
_control_names(sol, m) =
    _traj_model(sol) === nothing ? _gen_names("u", m) :
    CTModels.control_components(_traj_model(sol))
_control_name(sol) =
    _traj_model(sol) === nothing ? "u" : CTModels.control_name(_traj_model(sol))

"""
$(TYPEDSIGNATURES)

Time-axis name for a trajectory: the OCP's time name when available, else `"t"`.
"""
_time_name(sol) = _traj_model(sol) === nothing ? "t" : CTModels.time_name(_traj_model(sol))

# =============================================================================
# Panel builders
# =============================================================================

function _state_panel(sol, ts, style::NamedTuple)
    M = _sample(Trajectories.state(sol), ts)
    return Panel("state", _state_names(sol, size(M, 2)), M, style)
end

# When state is shown alongside (paired columns), the aligned state ylabels label the
# rows, so the costate column carries no ylabel (mirrors the CTModels convention).
function _costate_panel(sol, ts, style::NamedTuple; state_shown::Bool)
    M = _sample(Trajectories.costate(sol), ts)
    n = size(M, 2)
    labels = state_shown ? fill("", n) : _gen_names("p", n)
    return Panel("costate", labels, M, style)
end

function _control_panel(sol, ts, control::Symbol, style::NamedTuple)
    U = _sample(Trajectories.control(sol), ts)
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
    return Panel("control", labels, data, style)
end

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
)
    ts = Integrators.times(sol)
    panels = Panel[]
    state_shown = :state in description && state_style !== :none
    costate_shown = :costate in description && costate_style !== :none

    state_shown && push!(panels, _state_panel(sol, ts, state_style))
    costate_shown &&
        push!(panels, _costate_panel(sol, ts, costate_style; state_shown=state_shown))
    if :control in description && control_style !== :none
        push!(panels, _control_panel(sol, ts, control, control_style))
    end

    placement = (state_shown && costate_shown) ? :paired : :stacked
    return ts, panels, placement
end
