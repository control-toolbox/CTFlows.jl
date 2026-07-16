# CTFlows.jl

```@meta
CurrentModule = CTFlows
```

`CTFlows.jl` is the **flow integration layer** of the
[control-toolbox ecosystem](https://github.com/control-toolbox). Given a dynamical
system — a vector field, a Hamiltonian, or a Hamiltonian vector field — it builds a
callable **flow** that integrates the system from any initial condition to any final
time, with a pluggable ODE solver and optional automatic differentiation.

!!! info "CTFlows in the ecosystem"
    **CTFlows** handles **integration**. For **modelling** optimal control problems see
    [CTModels.jl](https://github.com/control-toolbox/CTModels.jl); for **solving NLPs**
    see [CTSolvers.jl](https://github.com/control-toolbox/CTSolvers.jl); for
    **differential-geometric tools** (Lie brackets, Poisson brackets, lifts) see
    [CTLie.jl](https://github.com/control-toolbox/CTLie); the umbrella package is
    [OptimalControl.jl](https://github.com/control-toolbox/OptimalControl.jl).

## Quick start

```julia
using CTFlows
using CTBase.Data, CTFlows.Flows, CTFlows.Trajectories
import OrdinaryDiffEqTsit5   # activates the SciML integrator extension

# 1. Wrap the dynamics
vf = Data.VectorField(x -> -x)          # autonomous, fixed, out-of-place

# 2. Build the flow
flow = Flows.Flow(vf; reltol=1e-8)

# 3. Integrate — point form (final state)
xf = flow(0.0, [1.0, 0.0], 1.0)

# 4. Integrate — trajectory form (full history)
sol = flow((0.0, 1.0), [1.0, 0.0])
t   = Trajectories.time_grid(sol)
x   = Trajectories.state(sol)           # callable: x(t) → state at time t
x(0.5)                                  # interpolate
```

!!! note "Qualified access"
    CTFlows exports nothing at the package level. Every symbol lives in a submodule
    (`CTBase.Data`, `CTFlows.Flows`, …) and is reached via a qualified path or a
    `using CTFlows.SubModule` import.

## Architecture

CTFlows is organised as a pipeline:

```
Data → Systems → Integrators → Flows → Trajectories
```

| Layer | Submodule | Key types |
|---|---|---|
| Data | [`CTBase.Data`](@extref CTBase.Data) | `VectorField`, `Hamiltonian`, `HamiltonianVectorField`, `PseudoHamiltonian`, `ControlledVectorField`, `OpenLoop`, `ClosedLoop`, `DynClosedLoop` |
| Configs | [`CTFlows.Configs`](@ref CTFlows.Configs) | `StateEndPointConfig`, `HamiltonianTrajectoryConfig`, `AugmentedHamiltonianEndPointConfig` |
| Systems | [`CTFlows.Systems`](@ref CTFlows.Systems) | `VectorFieldSystem`, `HamiltonianSystem`, `PseudoHamiltonianSystem` |
| Integrators | [`CTFlows.Integrators`](@ref CTFlows.Integrators) | `SciML` |
| Flows | [`CTFlows.Flows`](@ref CTFlows.Flows) | `StateFlow`, `HamiltonianFlow`, `OptimalControlFlow`, `ControlledFlow` |
| Trajectories | [`CTFlows.Trajectories`](@ref CTFlows.Trajectories) | `VectorFieldTrajectory`, `HamiltonianVectorFieldTrajectory`, `StateFlowTrajectory` |
| Multi-phase | [`CTFlows.MultiPhase`](@ref CTFlows.MultiPhase) | `MultiPhaseStateFlow` |

The data layer (`VectorField`, `Hamiltonian`, `HamiltonianVectorField`) lives in [`CTBase.Data`](@extref CTBase.Data); the ODE integrator
strategy is provided by
[`CTSolvers.Integrators`](@extref CTSolvers.Integrators) and re-exported through
[`CTFlows.Integrators`](@ref CTFlows.Integrators).

The shortcut `Flows.Flow(data; opts...)` collapses all pipeline steps into a single
call. The explicit pipeline (`build_system` → `build_integrator` → `build_flow`)
gives full control over each step.

## Guides

| Guide | Contents |
|---|---|
| [Getting Started](getting-started.md) | Installation, mental model, 5-minute walkthrough |
| [Flows](flows/overview.md) | End-to-end pipeline: data → systems → flows → trajectories, multi-phase |
| [Building a flow](flows/building_a_flow.md) | Shortcut and explicit constructors |
| [Integrating](flows/integrating.md) | Call styles, configuration objects, integrator options |
| [Trajectories](flows/trajectories.md) | Reading the result: `state`, `costate`, `time_grid`, plotting |
| [Multi-phase flows](flows/multiphase.md) | Concatenating flows with switching times and jumps |
| [Optimal control](flows/optimal_control.md) | Flows from optimal control problems (`Flow(ocp)`) |
| [Control laws](flows/control_laws.md) | `Flow(ocp, law)`, `Flow(h̃, law)`, `Flow(fc, law)` — `OpenLoop`, `ClosedLoop`, `DynClosedLoop` |
| [SciML flows](flows/sciml.md) | Flows from `ODEFunction` / `ODEProblem` (SciML extension) |
