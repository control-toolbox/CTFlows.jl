"""
    TrajectoryPlots

Backend-free CTFlows **case layer** for the [`CTBase.Plotting`](@extref) engine.

It owns the trajectory plotting vocabulary (`:state`, `:costate`, `:control`), turns a
trajectory plus a `description` into [`CTBase.Plotting.Panel`](@extref)s via the semantic
accessors, assembles the layout tree, and produces a [`CTBase.Plotting.Figure`](@extref)
through the single entry point [`build_figure`](@ref).

It carries **no rendering geometry and no backend dependency**: the concrete
`Plots.plot` / `Makie.plot` methods live in the `CTFlowsPlots` / `CTFlowsMakie`
extensions, which call `build_figure` and hand the figure to a
[`CTBase.Plotting.render`](@extref) backend. This mirrors `CTModels.PlotCase`, the
analogous case layer for `CTModels.Solution` plotting.

Design: everything is written against the **abstract** trajectory types plus the
[`_default_description`](@ref) contract, so the same code serves every subtype.
"""
module TrajectoryPlots

using DocStringExtensions: TYPEDSIGNATURES, TYPEDEF

using CTBase: Exceptions
using CTBase: Plotting
using CTModels: CTModels

using ..Trajectories: Trajectories
using ..Integrators: Integrators

include("description.jl")
include("panels.jl")
include("build.jl")

end # module TrajectoryPlots
