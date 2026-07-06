# =============================================================================
# Plots.plot / Plots.plot! for trajectories
#
# The thin public methods dispatch on the concrete trajectory types (so they win over
# the abstract `ExtensionError` stubs in src/Trajectories) and forward to `_plot` /
# `_plot!`, which are written against the abstract types + the `_default_description`
# contract.
# =============================================================================

# Resolve the description (contract default when none given), build panels, render.
function _plot(
    sol,
    description::Symbol...;
    layout::Symbol=PlotEngine.__layout(),
    control::Symbol=:components,
    time::Symbol=PlotEngine.__time(),
    state_style::Union{NamedTuple,Symbol}=PlotEngine.__style(),
    costate_style::Union{NamedTuple,Symbol}=PlotEngine.__style(),
    control_style::Union{NamedTuple,Symbol}=PlotEngine.__style(),
    size=nothing,
    kwargs...,
)
    desc = clean(isempty(description) ? _default_description(sol) : description)
    ts, panels, placement = _panels(
        sol,
        desc;
        control=control,
        state_style=state_style,
        costate_style=costate_style,
        control_style=control_style,
    )
    return PlotEngine.render(
        ts,
        panels;
        layout=layout,
        placement=placement,
        time=time,
        time_name=_time_name(sol),
        size=size,
        kwargs...,
    )
end

# Overlay variant onto an existing plot `p`.
function _plot!(
    p,
    sol,
    description::Symbol...;
    layout::Symbol=PlotEngine.__layout(),
    control::Symbol=:components,
    time::Symbol=PlotEngine.__time(),
    state_style::Union{NamedTuple,Symbol}=PlotEngine.__style(),
    costate_style::Union{NamedTuple,Symbol}=PlotEngine.__style(),
    control_style::Union{NamedTuple,Symbol}=PlotEngine.__style(),
    kwargs...,
)
    desc = clean(isempty(description) ? _default_description(sol) : description)
    ts, panels, placement = _panels(
        sol,
        desc;
        control=control,
        state_style=state_style,
        costate_style=costate_style,
        control_style=control_style,
    )
    return PlotEngine.render!(
        p,
        ts,
        panels;
        layout=layout,
        placement=placement,
        time=time,
        time_name=_time_name(sol),
        kwargs...,
    )
end

# Thin public methods: one triple (plot / plot! / plot!(p, …)) per concrete type. They
# dispatch on the concrete type (winning over the abstract stubs) and forward to the
# abstract-typed `_plot` / `_plot!`.
for T in (:VectorFieldTrajectory, :ControlledTrajectory, :HamiltonianVectorFieldTrajectory)
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
