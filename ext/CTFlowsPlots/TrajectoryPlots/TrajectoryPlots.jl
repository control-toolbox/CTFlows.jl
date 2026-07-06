"""
    TrajectoryPlots

CTFlows case layer on top of [`PlotEngine`](@ref). It owns the trajectory vocabulary
(`:state`, `:costate`, `:control`), turns a trajectory + a `description` into
[`PlotEngine.Panel`](@ref)s via the semantic accessors, and defines the `Plots.plot` /
`Plots.plot!` methods for the trajectory types.

Design: the public `Plots.plot` methods dispatch on the concrete trajectory types (the
minimal plumbing Julia's extension specificity needs so they win over the abstract
`ExtensionError` stubs), but all logic is written against the **abstract** trajectory
types and small **contracts** ([`_default_description`](@ref)), so the same code serves
every subtype.
"""
module TrajectoryPlots

import DocStringExtensions: TYPEDSIGNATURES, TYPEDEF
import CTBase.Exceptions
using Plots: Plots

using ..PlotEngine: PlotEngine, Panel
using CTFlows.Trajectories: Trajectories
using CTFlows.Integrators: Integrators
using CTModels: CTModels

include("description.jl")
include("panels.jl")
include("plot.jl")

end # module TrajectoryPlots
