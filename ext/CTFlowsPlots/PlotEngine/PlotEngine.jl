"""
    PlotEngine

Generic, domain-free plotting engine. It renders an ordered list of [`Panel`](@ref)s
(each a titled group of time series) into a laid-out, styled `Plots.Plot`, and knows
nothing about states, controls, trajectories or optimal control.

This is the reusable core: it is designed to be lifted into CTBase later and shared by
any case layer (CTFlows trajectories, CTModels solutions, …). It depends only on `Plots`,
`LinearAlgebra` and `CTBase.Exceptions` — never on domain modules.

Public API: [`Panel`](@ref), [`render`](@ref), [`render!`](@ref).
"""
module PlotEngine

import DocStringExtensions: TYPEDSIGNATURES, TYPEDEF
import CTBase.Exceptions
using Plots: Plots

include("panel.jl")
include("render.jl")

export Panel
export render, render!

end # module PlotEngine
