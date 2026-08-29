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

A lone panel needs no combinator. An invalid `layout` / `time` is reported by
[`CTBase.Plotting.lower`](@extref) as a `CTBase.Exceptions.IncorrectArgument`.
"""
function _assemble(sol, panels, placement; layout::Symbol, time::Symbol)
    tn = _time_name(sol)
    nodes = [Plotting.lower(p; layout=layout, time=time, time_name=tn) for p in panels]
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
- `size`: figure size; `nothing` defers to the engine heuristic.

# Returns
- `CTBase.Plotting.Figure`.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: nothing to draw (empty description, or every
  drawn group styled `:none`); an invalid `control` / `layout` / `time`.
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
    size=nothing,
)
    desc = clean(isempty(description) ? _default_description(sol) : description)
    _, panels, placement = _panels(
        sol,
        desc;
        control=control,
        state_style=state_style,
        costate_style=costate_style,
        control_style=control_style,
    )
    isempty(panels) && _nothing_to_plot()
    root = _assemble(sol, panels, placement; layout=layout, time=time)
    return Plotting.Figure(root; size=size)
end

"""
Keyword-argument names consumed by [`build_figure`](@ref); every other keyword a user
passes to `plot(sol; …)` is forwarded to the `CTBase.Plotting` rendering backend.
"""
const _BUILD_KEYS = (:layout, :control, :time, :state_style, :costate_style, :control_style)

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
