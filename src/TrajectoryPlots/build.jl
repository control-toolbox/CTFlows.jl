# =============================================================================
# build.jl — resolve description → build panels → assemble tree → CTBase.Plotting.Figure.
#
# `build_figure` is the single backend-agnostic entry point of the case layer: the
# `CTFlowsPlots` / `CTFlowsMakie` extensions call it and hand the figure to a
# `CTBase.Plotting.render` backend. It also owns the user-facing defaults, so the two
# extensions only forward keyword arguments. Mirror of `CTModels.PlotCase.build`.
# =============================================================================

"""
$(TYPEDSIGNATURES)

Lower each panel and assemble the [`CTBase.Plotting`](@extref) layout tree from
`(layout, placement)`:

- `:group` → one cell per panel, laid out in a horizontal row;
- `:split`, `:paired` → one column per panel (components stacked), columns side by
  side (e.g. state | costate) when they have equal heights;
- `:split`, `:stacked` → all component cells in a single vertical column.

`vlines` are drawn in every cell; `annotations[k]` are the texts of the `k`-th panel. A
lone panel needs no combinator. An invalid `layout` / `time` is reported by
[`CTBase.Plotting.lower`](@extref) as a `CTBase.Exceptions.IncorrectArgument`.
"""
function _assemble(
    sol,
    panels,
    placement;
    layout::Symbol,
    time::Symbol,
    vlines::AbstractVector{Plotting.VLine}=Plotting.VLine[],
    annotations::AbstractVector=[Plotting.Annotation[] for _ in panels],
)
    tn = _time_name(sol)
    nodes = [
        Plotting.lower(
            p; layout=layout, time=time, time_name=tn, vlines=vlines, annotations=a
        ) for (p, a) in zip(panels, annotations)
    ]
    length(nodes) == 1 && return nodes[1]
    if layout === :group
        return Plotting.Paired(nodes)                       # horizontal row of cells
    elseif placement === :paired && allequal(Plotting.n_leaves.(nodes))
        return Plotting.Paired(nodes)                       # side-by-side columns
    else
        return Plotting.Stacked(nodes)                      # single vertical column
    end
end

"""
$(TYPEDSIGNATURES)

Throw a `CTBase.Exceptions.IncorrectArgument` for the empty case: an empty
`description`, or every drawn group styled `:none`, leaves nothing to plot.
"""
function _nothing_to_plot()
    return throw(
        Exceptions.IncorrectArgument(
            "nothing to plot";
            got="no panels (empty description or every group styled :none)",
            expected="at least one group to draw",
            context="TrajectoryPlots",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Build the [`CTBase.Plotting.Figure`](@extref) for a CTFlows trajectory `sol` and a
`description`.

Resolves the description (the [`_default_description`](@ref) contract default when none
is given), builds the state / costate / control [`CTBase.Plotting.Panel`](@extref)s via
the semantic accessors, and assembles the layout tree. This is the single
backend-agnostic entry point: the `CTFlowsPlots` / `CTFlowsMakie` extensions call it and
render the result through a [`CTBase.Plotting.render`](@extref) backend.

# Arguments
- `sol`: a `VectorFieldTrajectory`, `HamiltonianVectorFieldTrajectory` or
  `StateFlowTrajectory`.
- `description`: any of `:state`, `:costate`, `:control`; empty ⇒ the per-type default.

# Keyword arguments
- `layout::Symbol = :split`: `:split` (one subplot per component) or `:group`.
- `control::Symbol = :components`: `:components`, `:norm` or `:all`.
- `time::Symbol = :default`: `:default` or `:normalize` / `:normalise`.
- `state_style` / `costate_style` / `control_style`: a `NamedTuple` of attributes or
  `:none` to hide the group.
- `switching_style = NamedTuple()`: style of the vertical lines at the switching times of
  a multi-phase trajectory (dashed black lines by default, merged with this style); `:none`
  hides them.
- `phase_labels::Symbol = :control`: where to write the phase labels (see
  [`CTFlows.Trajectories.phase_labels`](@extref)): `:control` (the control panel, or the
  first drawn panel when the control is not drawn), `:all` (every panel) or `:none`.
- `phase_labels_style::NamedTuple = NamedTuple()`: style of the labels (`color`,
  `fontsize`, `halign`, `valign`).
- `jumps::Symbol = :segment`: a jump at a switching time is drawn as a vertical segment
  from the left to the right limit (`:segment`), or the curve is broken between the two
  limits (`:none`), so that no segment suggests values the trajectory does not take.
- `size`: figure size; `nothing` defers to the engine heuristic.

At every switching time, a jump of the state, costate or control is drawn as a vertical
segment, from the left to the right limit, or as a break in the curve with `jumps=:none`.
The whole trajectory is one curve per component, so it keeps one color across phases.

# Returns
- `CTBase.Plotting.Figure`.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: nothing to draw (empty description, or every
  drawn group styled `:none`); an invalid `control` / `layout` / `time` /
  `phase_labels` / `jumps`.
"""
function build_figure(
    sol,
    description::Symbol...;
    layout::Symbol=Plotting.__layout(),
    control::Symbol=:components,
    time::Symbol=Plotting.__time(),
    state_style::Union{NamedTuple,Symbol}=Plotting.__style(),
    costate_style::Union{NamedTuple,Symbol}=Plotting.__style(),
    control_style::Union{NamedTuple,Symbol}=Plotting.__style(),
    switching_style::Union{NamedTuple,Symbol}=Plotting.__style(),
    phase_labels::Symbol=:control,
    phase_labels_style::NamedTuple=Plotting.__style(),
    jumps::Symbol=:segment,
    size=nothing,
)
    _check_phase_labels(phase_labels)
    _check_jumps(jumps)
    desc = clean(isempty(description) ? _default_description(sol) : description)
    ts, panels, placement = _panels(
        sol,
        desc;
        control=control,
        state_style=state_style,
        costate_style=costate_style,
        control_style=control_style,
        connect=(jumps === :segment),
    )
    isempty(panels) && _nothing_to_plot()
    taus = Trajectories.switching_times(sol)
    vlines = if switching_style === :none
        Plotting.VLine[]
    else
        style = merge(_SWITCHING_STYLE, switching_style)
        Plotting.switching_vlines(ts, taus; time=time, style=style)
    end
    texts = if phase_labels === :none
        Plotting.Annotation[]
    else
        labels = Trajectories.phase_labels(sol)
        Plotting.phase_annotations(ts, taus, labels; time=time, style=phase_labels_style)
    end
    on = _phase_label_panels(
        phase_labels, length(panels), _control_shown(desc, control_style)
    )
    annotations = [k ? texts : Plotting.Annotation[] for k in on]
    root = _assemble(
        sol,
        panels,
        placement;
        layout=layout,
        time=time,
        vlines=vlines,
        annotations=annotations,
    )
    return Plotting.Figure(root; size=size)
end

# =============================================================================
# Switching structure: vertical lines at the switching times, phase labels
# =============================================================================

"""
Default style of the vertical lines at the switching times: dashed black lines behind the
curves, as the initial/final time markers of a `CTModels.Solution` plot.
"""
const _SWITCHING_STYLE = (color=:black, linestyle=:dash, linewidth=1, z_order=:back, label="")

"""
$(TYPEDSIGNATURES)

Check the drawing of the jumps: `:segment` or `:none`.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: for any other value.
"""
function _check_jumps(jumps::Symbol)
    jumps in (:segment, :none) || throw(
        Exceptions.IncorrectArgument(
            "Invalid jumps choice";
            got="jumps=$jumps",
            expected=":segment or :none",
            suggestion="Use jumps=:segment (default, a vertical segment) or :none (a break)",
            context="TrajectoryPlots.build_figure",
        ),
    )
    return nothing
end

"""
$(TYPEDSIGNATURES)

Check the placement of the phase labels: `:control`, `:all` or `:none`.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: for any other value.
"""
function _check_phase_labels(phase_labels::Symbol)
    phase_labels in (:control, :all, :none) || throw(
        Exceptions.IncorrectArgument(
            "Invalid phase_labels choice";
            got="phase_labels=$phase_labels",
            expected=":control, :all or :none",
            suggestion="Use phase_labels=:control (default), :all or :none",
            context="TrajectoryPlots.build_figure",
        ),
    )
    return nothing
end

"""
$(TYPEDSIGNATURES)

Return, for each of the `n` drawn panels, whether it receives the phase labels: every panel
for `phase_labels = :all`, none for `:none`; for `:control`, the control panel when it is
drawn (the last panel, see [`CTFlows.TrajectoryPlots._panels`](@extref)), the first panel
otherwise.
"""
function _phase_label_panels(phase_labels::Symbol, n::Int, control_shown::Bool)::Vector{Bool}
    phase_labels === :all && return fill(true, n)
    phase_labels === :none && return fill(false, n)
    target = control_shown ? n : 1
    return [k == target for k in 1:n]
end

"""
Keyword-argument names consumed by [`build_figure`](@ref); every other keyword a user
passes to `plot(sol; …)` is forwarded to the `CTBase.Plotting` rendering backend.
"""
const _BUILD_KEYS = (
    :layout,
    :control,
    :time,
    :state_style,
    :costate_style,
    :control_style,
    :switching_style,
    :phase_labels,
    :phase_labels_style,
    :jumps,
)

"""
$(TYPEDSIGNATURES)

Split the user keyword arguments of `plot(sol; …)` into the pair `(build, render)`:
`build` holds the [`_BUILD_KEYS`](@ref) consumed by [`build_figure`](@ref), `render`
holds everything else (forwarded to the `CTBase.Plotting` backend). The `size` keyword
is handled explicitly by the extensions and is not part of `_BUILD_KEYS`.
"""
function split_plot_kwargs(kwargs)
    build = NamedTuple(k => v for (k, v) in pairs(kwargs) if k in _BUILD_KEYS)
    render = NamedTuple(k => v for (k, v) in pairs(kwargs) if !(k in _BUILD_KEYS))
    return build, render
end
