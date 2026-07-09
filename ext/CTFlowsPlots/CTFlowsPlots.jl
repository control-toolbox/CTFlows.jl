"""
    CTFlowsPlots

Package extension providing plotting for CTFlows trajectory types
(`VectorFieldTrajectory`, `HamiltonianVectorFieldTrajectory`, `ControlledTrajectory`).
Activated automatically when `Plots` is loaded together with `CTFlows`.

The rendering engine lives in `CTBase.Plotting` (with its `CTBasePlots` backend); this
extension is only the [`TrajectoryPlots`](@ref) case layer that maps trajectories onto
that engine and defines the `Plots.plot` / `Plots.plot!` methods.
"""
module CTFlowsPlots

include(joinpath(@__DIR__, "TrajectoryPlots", "TrajectoryPlots.jl"))
using .TrajectoryPlots: TrajectoryPlots

end # module CTFlowsPlots
