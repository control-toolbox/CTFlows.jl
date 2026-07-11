# Flows

```@meta
CurrentModule = CTFlows
```

The [`CTFlows.Flows`](@ref CTFlows.Flows) submodule is the central abstraction of
CTFlows. A **flow** is a callable object that integrates a dynamical system over a time
interval: you hand it an initial condition and a final time, and it returns the result.

CTFlows builds flows through a **four-layer pipeline**:

```
Data → Systems → Integrators → Flows → Trajectories
```

Each layer has a single responsibility:

| Layer | Submodule | What it produces |
|---|---|---|
| **Data** | [`CTBase.Data`](@extref CTBase.Data) | Typed function wrappers (`VectorField`, `Hamiltonian`, `HamiltonianVectorField`) |
| **Systems** | [`Systems`](@ref CTFlows.Systems) | ODE right-hand side + traits (`VectorFieldSystem`, `HamiltonianSystem`, …) |
| **Integrators** | [`Integrators`](@ref CTFlows.Integrators) | ODE solver strategy (`SciML`) |
| **Flows** | [`Flows`](@ref CTFlows.Flows) | Callable integration object (`StateFlow`, `HamiltonianFlow`, `OptimalControlFlow`, `ControlledFlow`) |
| **Trajectories** | [`Trajectories`](@ref CTFlows.Trajectories) | Result container with semantic accessors (`state`, `costate`, `control`, `time_grid`) |

## Reading order

| Page | Topic | Key types |
|---|---|---|
| [Building a flow](building_a_flow.md) | Assembling the pipeline | `build_system`, `build_flow`, `Flow` |
| [Integrating](integrating.md) | Calling a flow, configuration objects, integrator options | `StateEndPointConfig`, `StateTrajectoryConfig` |
| [Trajectories](trajectories.md) | Reading the result | `state`, `costate`, `time_grid`, `plot` |
| [Multi-phase flows](multiphase.md) | Concatenating flows with switching times | `MultiPhaseStateFlow`, `*` |
| [Optimal control](optimal_control.md) | Flows from optimal control problems | `OptimalControlFlow`, `Flow(ocp)` |
| [Control laws](control_laws.md) | Flows with control laws | `ControlledFlow`, `Flow(ocp, law)`, `OpenLoop`, `ClosedLoop`, `DynClosedLoop` |
| [Constrained flows](constrained.md) | Path-constraint terms on `Flow(ocp, law)` | `constraint`, `multiplier`, `hamiltonian_type` |
| [SciML flows](sciml.md) | Flows from SciML functions and problems | `Flow(::ODEFunction)`, `SciMLProblemFlow` |

The **data layer** (wrapping functions as `VectorField`, `Hamiltonian`,
`HamiltonianVectorField`) and the **trait system** (`Autonomous`, `Fixed`,
`InPlace`, …) live in CTBase — see [`CTBase.Data`](@extref CTBase.Data) and
[`CTBase.Traits`](@extref CTBase.Traits) in the CTBase documentation.

## Qualified access

CTFlows exports nothing at the package level. Bring submodules into scope explicitly:

```@example flows_overview
using CTFlows
using CTFlows.Flows        # StateFlow, HamiltonianFlow, Flow, build_flow
using CTBase.Data         # VectorField, Hamiltonian, HamiltonianVectorField
using CTFlows.Systems      # build_system
using CTFlows.Integrators  # SciML, build_integrator
using CTFlows.Trajectories    # VectorFieldTrajectory, state, time_grid
using CTBase.Traits       # Autonomous, NonAutonomous, Fixed, NonFixed, InPlace, OutOfPlace
using CTFlows.Configs      # StateEndPointConfig, StateTrajectoryConfig, …
import OrdinaryDiffEqTsit5 # activates the SciML extension
nothing # hide
```

## Minimal end-to-end example

The fastest path from a function to an integrated trajectory:

```@example flows_overview
# 1. Wrap the dynamics as a VectorField
#    The function x -> -x is autonomous (no t) and fixed (no variable parameter)
vf = Data.VectorField(x -> -x)

# 2. Build the flow directly from the data (shortcut constructor)
flow = Flows.Flow(vf; reltol=1e-8, abstol=1e-8)

# 3a. Point integration: final state only
xf = flow(0.0, [1.0, 0.0], 1.0)

# 3b. Trajectory integration: full time history
sol = flow((0.0, 1.0), [1.0, 0.0])

# 4. Read the result
ts = Trajectories.time_grid(sol)   # vector of time points
x  = Trajectories.state(sol)       # callable: x(t) → state at time t
x(0.5)                          # interpolate at t = 0.5
```

The shortcut `Flows.Flow(vf; opts...)` hides steps 2–3 of the pipeline
(`build_system` → `build_integrator` → `build_flow`). See
[Building a flow](building_a_flow.md) for the explicit form.

## Mathematical setting

We work on a state space ``\mathcal{X} \subseteq \mathbb{R}^n``.

- A **vector field** is a map ``X : \mathcal{X} \to \mathbb{R}^n`` (or with time and/or
  variable arguments).
- A **Hamiltonian** is a scalar map ``H : T^*\mathcal{X} \to \mathbb{R}``,
  ``(x, p) \mapsto H(x,p)`` defined on the cotangent bundle.
- A **Hamiltonian vector field** is the map
  ``\vec{H} : T^*\mathcal{X} \to \mathbb{R}^n \times \mathbb{R}^n``,
  ``(x, p) \mapsto (\partial_p H, -\partial_x H)``.

Which extra arguments appear (``t``, ``v``) is encoded by the **trait system** —
see [`CTBase.Traits`](@extref CTBase.Traits).
