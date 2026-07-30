"""
    TrajectoryPlots

CTFlows case layer on top of the generic [`CTBase.Plotting`](@ref) engine. It owns the
trajectory vocabulary (`:state`, `:costate`, `:control`), turns a trajectory + a
`description` into [`CTBase.Plotting.Panel`](@ref)s via the semantic accessors, lowers
and assembles them into a `Plotting.Figure`, and defines the `Plots.plot` /
`Plots.plot!` methods for the trajectory types.

Design: the public `Plots.plot` methods dispatch on the concrete trajectory types (the
minimal plumbing Julia's extension specificity needs so they win over the abstract
`ExtensionError` stubs), but all logic is written against the **abstract** trajectory
types and small **contracts** ([`_default_description`](@ref)), so the same code serves
every subtype. This module holds no rendering geometry — that lives in `CTBase.Plotting`
and its `CTBasePlots` backend.
"""
module TrajectoryPlots

using DocStringExtensions: TYPEDSIGNATURES, TYPEDEF
using CTBase: Exceptions
using CTBase: Plotting
using Plots: Plots

using CTFlows: Trajectories
using CTFlows: Integrators
using CTModels: CTModels

include("description.jl")
include("panels.jl")
include("plot.jl")

end # module TrajectoryPlots
