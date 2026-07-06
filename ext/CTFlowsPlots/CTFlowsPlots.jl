"""
    CTFlowsPlots

Package extension providing plotting for CTFlows trajectory types
(`VectorFieldTrajectory`, `HamiltonianVectorFieldTrajectory`, `ControlledTrajectory`).
Activated automatically when `Plots` is loaded together with `CTFlows`.

Two modules:
- [`PlotEngine`](@ref) — a generic, domain-free rendering engine (liftable to CTBase).
- [`TrajectoryPlots`](@ref) — the CTFlows case layer that maps trajectories onto the
  engine and defines the `Plots.plot` / `Plots.plot!` methods.
"""
module CTFlowsPlots

# The two sub-modules. PlotEngine first (TrajectoryPlots depends on it).
include(joinpath(@__DIR__, "PlotEngine", "PlotEngine.jl"))
using .PlotEngine: PlotEngine

include(joinpath(@__DIR__, "TrajectoryPlots", "TrajectoryPlots.jl"))
using .TrajectoryPlots: TrajectoryPlots

end # module CTFlowsPlots
