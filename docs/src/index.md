# CTFlows.jl

```@meta
CurrentModule = CTFlows
```

`CTFlows.jl` is the **flow integration layer** of the
[control-toolbox ecosystem](https://github.com/control-toolbox). Given a dynamical
system (a vector field, a Hamiltonian, a Hamiltonian vector field, or an **optimal
control problem**), it builds a callable **flow** that integrates the system from any
initial condition to any final time, with a pluggable ODE solver and automatic
differentiation where derivatives are needed.

!!! info "Who this documentation is for"
    This documentation is for **advanced users** who build flows from the data layer,
    write shooting methods or need control over the integration, and for **developers**
    of CTFlows and of the packages that build on it. To solve optimal control problems,
    start with the [OptimalControl.jl documentation](https://control-toolbox.org/OptimalControl.jl/stable/),
    which re-exports the flows described here.

!!! info "CTFlows in the ecosystem"
    **CTFlows** handles **integration**. **Modelling** optimal control problems is
    [CTModels.jl](https://github.com/control-toolbox/CTModels.jl); the data layer, traits
    and AD primitives are [CTBase.jl](https://github.com/control-toolbox/CTBase.jl); the
    ODE integrator strategy is [CTSolvers.jl](https://github.com/control-toolbox/CTSolvers.jl);
    **differential-geometric tools** (Lie and Poisson brackets, lifts) are
    [CTLie.jl](https://github.com/control-toolbox/CTLie).

## Quick start

```@example index
using CTFlows
using CTBase: Data
using CTFlows: Flows
using CTFlows: Trajectories
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5   # activates the SciML integrator

vf = Data.VectorField(x -> -x)            # ẋ = -x: autonomous, no variable
flow = Flows.Flow(vf; reltol=1e-8)

xf = flow(0.0, [1.0, 0.0], 1.0)           # point call: the state at tf
sol = flow((0.0, 1.0), [1.0, 0.0])        # trajectory call
x = Trajectories.state(sol)               # callable: x(t)
xf, x(0.5)
```

!!! note "Qualified access"
    CTFlows exports nothing at the package level. Every symbol lives in a submodule
    (`CTBase.Data`, `CTFlows.Flows`, …) and is reached through a qualified path, after
    `using CTFlows: Submodule`.

The same constructor builds a flow directly from an **optimal control problem**, a
[`CTModels.Models.Model`](@extref CTModels.Models.Model), with no Hamiltonian to write by
hand: `Flows.Flow(ocp)` for a control-free problem, `Flows.Flow(ocp, law)` with a control
law. See [Optimal control](flows/optimal_control.md) and [Control laws](flows/control_laws.md).

## Architecture

CTFlows is a pipeline:

```text
Data → Systems → Integrators → Flows → Trajectories
```

| Layer | Submodule | Key types and functions |
|---|---|---|
| Data | [`CTBase.Data`](@extref CTBase.Data) | `VectorField`, `Hamiltonian`, `HamiltonianVectorField`, `PseudoHamiltonian`, `PseudoHamiltonianVectorField`, `ControlledVectorField`, `OpenLoop`, `ClosedLoop`, `DynClosedLoop` |
| Configs | [`CTFlows.Configs`](@ref CTFlows.Configs) | `StateEndPointConfig`, `StateTrajectoryConfig`, `HamiltonianEndPointConfig`, `HamiltonianTrajectoryConfig`, `AugmentedHamiltonianEndPointConfig`; output grids `UniformGrid`, `AdaptiveGrid` |
| Systems | [`CTFlows.Systems`](@ref CTFlows.Systems) | `VectorFieldSystem`, `HamiltonianVectorFieldSystem`, `HamiltonianSystem`, `PseudoHamiltonianSystem`, `PseudoHamiltonianVectorFieldSystem`, `ConstrainedPseudoHamiltonianSystem`; accessors `hamiltonian`, `control_law`, … |
| Integrators | [`CTFlows.Integrators`](@ref CTFlows.Integrators) | `SciML` (from CTSolvers), `build_problem`, `build_options` |
| Flows | [`CTFlows.Flows`](@ref CTFlows.Flows) | `Flow`, `StateFlow`, `HamiltonianFlow`, `OptimalControlFlow`, `ControlledFlow` |
| Trajectories | [`CTFlows.Trajectories`](@ref CTFlows.Trajectories) | `VectorFieldTrajectory`, `HamiltonianVectorFieldTrajectory`, `StateFlowTrajectory` |
| Multi-phase | [`CTFlows.MultiPhase`](@ref CTFlows.MultiPhase) | `MultiPhaseStateFlow`, `MultiPhaseHamiltonianFlow`, the `*` operator |
| Plotting | [`CTFlows.TrajectoryPlots`](@ref CTFlows.TrajectoryPlots) | `build_figure`, rendered by the Plots or Makie extension |

The data layer lives in [`CTBase.Data`](@extref CTBase.Data); the ODE integrator strategy
is provided by [`CTSolvers.Integrators`](@extref CTSolvers.Integrators) and re-exported
through [`CTFlows.Integrators`](@ref CTFlows.Integrators).

The shortcut `Flows.Flow(data; opts...)` runs all the steps in one call. The explicit
pipeline (`build_system`, `SciML`, `build_flow`) gives control over each one.

## Reading paths

**Advanced users**, writing flows and shooting methods:

1. [Getting Started](getting-started.md): installation and a first flow.
2. [Building a flow](flows/building_a_flow.md) and [Integrating](flows/integrating.md):
   the constructors, the call styles, output grids, variables, integrator options.
3. [Trajectories](flows/trajectories.md) and [Multi-phase flows](flows/multiphase.md):
   reading and plotting results, concatenating flows with switching times and jumps.
4. [Optimal control](flows/optimal_control.md), [Control laws](flows/control_laws.md),
   [Constrained flows](flows/constrained.md): flows from an optimal control problem.
5. [Compatibility](compatibility/overview.md): which state types and call styles each
   constructor accepts.

**Developers**, extending CTFlows or building on it:

1. [Flows overview](flows/overview.md): the layers and their mathematical setting.
2. [Extending CTFlows](dev/extending.md): the contracts a new system, flow or integrator
   implements.
3. [GPU flows](flows/gpu.md) and [GPU internals](dev/gpu-internals.md): device support,
   how it is routed, how it is tested.
4. [SciML flows](flows/sciml.md): the SciML extension.
5. The API reference, one page per submodule, and the internals.
