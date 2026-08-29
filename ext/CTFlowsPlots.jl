"""
Weak-dependency extension of CTFlows providing `Plots.plot` / `Plots.plot!` for the
three trajectory types (`VectorFieldTrajectory`, `HamiltonianVectorFieldTrajectory`,
`StateFlowTrajectory`).

Loaded automatically when `Plots` is available together with `CTFlows`. This is the thin
plumbing on top of the backend-free case layer [`CTFlows.TrajectoryPlots`](@extref): the
public methods build the figure with [`CTFlows.TrajectoryPlots.build_figure`](@extref)
and render it through the `CTBase.Plotting` Plots backend. Everything domain-specific
(vocabulary, panels, layout) lives in `CTFlows.TrajectoryPlots` and is shared with the
`CTFlowsMakie` extension.

`Plots.plot` returns a `Plots.Plot`; the `description` and keyword arguments are
documented on [`CTFlows.TrajectoryPlots.build_figure`](@extref).
"""
module CTFlowsPlots

using DocStringExtensions: TYPEDSIGNATURES

using CTBase: Plotting
using CTFlows: Trajectories, TrajectoryPlots
using Plots: Plots

# --- internal implementations (abstract-typed; backend-agnostic build + Plots render) --

"""
$(TYPEDSIGNATURES)

Internal implementation of `Plots.plot` for the CTFlows trajectory types.

Builds the figure with [`CTFlows.TrajectoryPlots.build_figure`](@extref) (which owns the
user-facing defaults and throws on an empty description) and renders it via
[`CTBase.Plotting.render`](@extref) on the Plots backend. Returns a `Plots.Plot`.
"""
function _plot(sol, description::Symbol...; size=nothing, kwargs...)
    build, render = TrajectoryPlots.split_plot_kwargs(kwargs)
    fig = TrajectoryPlots.build_figure(sol, description...; size=size, build...)
    return Plotting.render(Plotting.PlotsBackend(), fig; render...)
end

"""
$(TYPEDSIGNATURES)

Internal implementation of `Plots.plot!` for the CTFlows trajectory types: build the
figure with [`CTFlows.TrajectoryPlots.build_figure`](@extref) and overlay it onto the
existing plot `p` via [`CTBase.Plotting.render!`](@extref) (Plots backend).
"""
function _plot!(p::Plots.Plot, sol, description::Symbol...; kwargs...)
    build, render = TrajectoryPlots.split_plot_kwargs(kwargs)
    fig = TrajectoryPlots.build_figure(sol, description...; build...)
    return Plotting.render!(Plotting.PlotsBackend(), p, fig; render...)
end

# --- public methods --------------------------------------------------------------------
#
# One (plot / plot!(p, …) / plot!(…)) triple per concrete trajectory type. The concrete
# dispatch is the minimal plumbing Julia's method specificity needs so these win over the
# abstract `RecipesBase.plot` `ExtensionError` stubs in `src/Trajectories`; every method
# forwards verbatim to the abstract-typed `_plot` / `_plot!` above, which carry the
# documentation for the operation (mirrors the "documented once, as a unit" rule the
# Handbook applies to dispatch-only method groups).

for T in (:VectorFieldTrajectory, :StateFlowTrajectory, :HamiltonianVectorFieldTrajectory)
    @eval begin
        function Plots.plot(sol::Trajectories.$T, description::Symbol...; kwargs...)
            return _plot(sol, description...; kwargs...)
        end

        function Plots.plot!(
            p::Plots.Plot, sol::Trajectories.$T, description::Symbol...; kwargs...
        )
            return _plot!(p, sol, description...; kwargs...)
        end

        function Plots.plot!(sol::Trajectories.$T, description::Symbol...; kwargs...)
            return _plot!(Plots.current(), sol, description...; kwargs...)
        end
    end
end

end # module CTFlowsPlots
