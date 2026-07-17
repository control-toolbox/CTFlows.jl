# =============================================================================
# Plots.plot / Plots.plot! for trajectories
#
# The thin public methods dispatch on the concrete trajectory types (so they win over
# the abstract `ExtensionError` stubs in src/Trajectories) and forward to `_plot` /
# `_plot!`, which are written against the abstract types + the `_default_description`
# contract. All layout/rendering is delegated to `CTBase.Plotting`.
# =============================================================================

# Lower each panel and assemble the layout tree from (layout, placement):
#   - :group          -> one cell per panel, laid out in a horizontal row;
#   - :split, :paired -> one column per panel (components stacked), columns side by
#                        side (e.g. state | costate) when they have equal heights;
#   - :split, :stacked-> all component cells in a single vertical column.
# A lone panel needs no combinator. Bad `layout`/`time` are reported by `lower`.
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

# Guard the empty case (empty description, or every drawn group styled `:none`).
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

# Resolve the description (contract default when none given), build panels, render.
function _plot(
    sol,
    description::Symbol...;
    layout::Symbol=Plotting.__layout(),
    control::Symbol=:components,
    time::Symbol=Plotting.__time(),
    state_style::Union{NamedTuple,Symbol}=Plotting.__style(),
    costate_style::Union{NamedTuple,Symbol}=Plotting.__style(),
    control_style::Union{NamedTuple,Symbol}=Plotting.__style(),
    size=nothing,
    kwargs...,
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
    return Plotting.render(Plotting.Figure(root; size=size); kwargs...)
end

# Overlay variant onto an existing plot `p`.
function _plot!(
    p,
    sol,
    description::Symbol...;
    layout::Symbol=Plotting.__layout(),
    control::Symbol=:components,
    time::Symbol=Plotting.__time(),
    state_style::Union{NamedTuple,Symbol}=Plotting.__style(),
    costate_style::Union{NamedTuple,Symbol}=Plotting.__style(),
    control_style::Union{NamedTuple,Symbol}=Plotting.__style(),
    kwargs...,
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
    return Plotting.render!(p, Plotting.Figure(root); kwargs...)
end

# Thin public methods: one triple (plot / plot! / plot!(p, …)) per concrete type. They
# dispatch on the concrete type (winning over the abstract stubs) and forward to the
# abstract-typed `_plot` / `_plot!`.
for T in (:VectorFieldTrajectory, :StateFlowTrajectory, :HamiltonianVectorFieldTrajectory)
    @eval begin
        function Plots.plot(sol::Trajectories.$T, description::Symbol...; kwargs...)
            return _plot(sol, description...; kwargs...)
        end

        function Plots.plot!(sol::Trajectories.$T, description::Symbol...; kwargs...)
            return _plot!(Plots.current(), sol, description...; kwargs...)
        end

        function Plots.plot!(
            p::Plots.Plot, sol::Trajectories.$T, description::Symbol...; kwargs...
        )
            return _plot!(p, sol, description...; kwargs...)
        end
    end
end
