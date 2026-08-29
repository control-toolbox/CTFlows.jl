"""
Weak-dependency extension of CTFlows providing `Makie.plot` / `Makie.plot!` for the
three trajectory types (`VectorFieldTrajectory`, `HamiltonianVectorFieldTrajectory`,
`StateFlowTrajectory`).

Loaded automatically when both `CTFlows` and `Makie` are available (for example via
`CairoMakie` or `GLMakie`). This is the thin plumbing on top of the backend-free case
layer [`CTFlows.TrajectoryPlots`](@extref): the public methods build the figure with
[`CTFlows.TrajectoryPlots.build_figure`](@extref) and render it through the
`CTBase.Plotting` Makie backend, which is at feature parity with the Plots backend.
Everything domain-specific (vocabulary, panels, layout) lives in
`CTFlows.TrajectoryPlots` and is shared with the `CTFlowsPlots` extension.

`Makie.plot` returns a `Makie.Figure`; the `description` and keyword arguments are
identical to the Plots backend (see [`CTFlows.TrajectoryPlots.build_figure`](@extref)).
The zero-argument `Makie.plot(; kwargs...)` empty-canvas figure is provided by the
`CTModelsMakie` extension (always loaded here, since CTModels is a hard dependency).
"""
module CTFlowsMakie

using DocStringExtensions: TYPEDSIGNATURES

using CTBase: Plotting
using CTFlows: Trajectories, TrajectoryPlots
using Makie: Makie

# --- internal implementations (abstract-typed; backend-agnostic build + Makie render) --

"""
$(TYPEDSIGNATURES)

Internal implementation of `Makie.plot` for the CTFlows trajectory types.

Builds the figure with [`CTFlows.TrajectoryPlots.build_figure`](@extref) (which owns the
user-facing defaults and throws on an empty description) and renders it via
[`CTBase.Plotting.render`](@extref) on the Makie backend. Returns a `Makie.Figure`.
"""
function _plot(sol, description::Symbol...; size=nothing, kwargs...)
    build, render = TrajectoryPlots.split_plot_kwargs(kwargs)
    fig = TrajectoryPlots.build_figure(sol, description...; size=size, build...)
    return Plotting.render(Plotting.MakieBackend(), fig; render...)
end

"""
$(TYPEDSIGNATURES)

Internal implementation of `Makie.plot!` for the CTFlows trajectory types: build the
figure with [`CTFlows.TrajectoryPlots.build_figure`](@extref) and overlay it onto the
existing `Makie.Figure` `f` via [`CTBase.Plotting.render!`](@extref) (Makie backend).
"""
function _plot!(f::Makie.Figure, sol, description::Symbol...; kwargs...)
    build, render = TrajectoryPlots.split_plot_kwargs(kwargs)
    fig = TrajectoryPlots.build_figure(sol, description...; build...)
    return Plotting.render!(Plotting.MakieBackend(), f, fig; render...)
end

# --- public methods --------------------------------------------------------------------
#
# One (plot / plot!(f, …) / plot!(…)) triple per concrete trajectory type. The concrete
# dispatch is the minimal plumbing Julia's method specificity needs so these win over the
# abstract `RecipesBase.plot` `ExtensionError` stubs in `src/Trajectories`; every method
# forwards verbatim to the abstract-typed `_plot` / `_plot!` above, which carry the
# documentation for the operation (mirrors the "documented once, as a unit" rule the
# Handbook applies to dispatch-only method groups).

for T in (:VectorFieldTrajectory, :StateFlowTrajectory, :HamiltonianVectorFieldTrajectory)
    @eval begin
        function Makie.plot(sol::Trajectories.$T, description::Symbol...; kwargs...)
            return _plot(sol, description...; kwargs...)
        end

        function Makie.plot!(
            f::Makie.Figure, sol::Trajectories.$T, description::Symbol...; kwargs...
        )
            return _plot!(f, sol, description...; kwargs...)
        end

        function Makie.plot!(sol::Trajectories.$T, description::Symbol...; kwargs...)
            f = Makie.current_figure()
            return _plot!(
                f === nothing ? Makie.Figure() : f, sol, description...; kwargs...
            )
        end
    end
end

end # module CTFlowsMakie
