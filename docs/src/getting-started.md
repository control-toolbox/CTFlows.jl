# Getting Started

```@meta
CurrentModule = CTFlows
```

This page gets you from installation to your first integrated trajectory in five
minutes.

## Installation

```julia
import Pkg
Pkg.add("CTFlows")
```

To integrate anything you also need an ODE solver backend. The default strategy is
**SciML**, activated by loading an OrdinaryDiffEq solver package:

```julia
Pkg.add("OrdinaryDiffEqTsit5")
```

## Mental model

Three ideas explain most of the API:

1. **No top-level exports.** CTFlows exports nothing at the package level. Every
   symbol lives in a submodule and is reached via a qualified path
   (`CTFlows.Flows.Flow`) or an explicit `using CTFlows.Flows`. The same holds for
   the data layer, which lives in CTBase (`CTBase.Data.VectorField`).
2. **A pipeline of small layers.** Data (your functions, wrapped) → Systems (ODE
   right-hand side) → Integrators (solver strategy) → Flows (the callable object) →
   Trajectories (the result). The shortcut `Flows.Flow(data; opts...)` runs the
   whole pipeline in one call.
3. **Extension-backed features.** The actual ODE solving, plotting, and SciML
   interoperability are Julia package extensions: they activate when you load
   `OrdinaryDiffEqTsit5` (or another solver), `Plots`, or `SciMLBase`.

## 5-minute walkthrough

Bring the relevant submodules into scope and load a solver:

```@example getting_started
using CTFlows
using CTBase.Data          # VectorField, Hamiltonian, HamiltonianVectorField
using CTFlows.Flows        # Flow
using CTFlows.Trajectories # time_grid, state, costate
import OrdinaryDiffEqTsit5 # activates the SciML integrator extension
nothing # hide
```

### Wrap the dynamics

A vector field is any function of the state. Wrapping it as a
[`Data.VectorField`](@extref CTBase.Data.VectorField) records its traits
(autonomous or not, with or without a variable parameter):

```@example getting_started
vf = Data.VectorField(x -> -x)   # autonomous, fixed
nothing # hide
```

### Build the flow

```@example getting_started
flow = Flows.Flow(vf; reltol=1e-8, abstol=1e-8)
```

### Integrate

Point form returns only the final state:

```@repl getting_started
xf = flow(0.0, [1.0, 0.0], 1.0)
```

Trajectory form returns the full history:

```@example getting_started
sol = flow((0.0, 1.0), [1.0, 0.0])
```

### Read the result

```@repl getting_started
ts = Trajectories.time_grid(sol);
(ts[1], ts[end])
x = Trajectories.state(sol);
x(0.5)
```

`Trajectories.state(sol)` is callable and interpolates: `x(t)` gives the state at
any `t` inside the integration interval.

### Hamiltonian systems

The same API drives Hamiltonian dynamics on state–costate pairs
``(x, p)``:

```@example getting_started
hvf = Data.HamiltonianVectorField((x, p) -> (p, -x))
hflow = Flows.Flow(hvf; reltol=1e-10)
nothing # hide
```

```@repl getting_started
xf, pf = hflow(0.0, [1.0, 0.0], [0.0, 1.0], 1.0);
xf
pf
```

You can also start from a scalar Hamiltonian and let automatic differentiation
derive the vector field — see [Building a flow](flows/building_a_flow.md).

### Optimal control problems

This is the entry point most users of the control-toolbox ecosystem actually reach
for: `Flow(ocp)` builds a flow directly from an **optimal control problem** — a
[`CTModels.Models.Model`](@extref CTModels.Models.Model) — with no Hamiltonian to
write by hand.

```@example getting_started
using CTModels

pre = CTModels.Building.PreModel()
CTModels.Building.time_dependence!(pre; autonomous=true)
CTModels.Building.time!(pre; t0=0.0, tf=1.0)
CTModels.Building.state!(pre, 1)
CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1] = -x[1]; nothing))
CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> xf[1])
ocp = CTModels.Building.build(pre)

f = Flows.Flow(ocp; reltol=1e-10)
nothing # hide
```

Point evaluation returns the final state–costate pair (Hamiltonian semantics):

```@repl getting_started
xf, pf = f(0.0, [1.0], [1.0], 1.0);
xf
pf
```

A trajectory call assembles a full `CTModels.Solution` — state, costate, and the
objective value:

```@example getting_started
sol = f((0.0, 1.0), [1.0], [1.0])
```

```@repl getting_started
CTModels.Components.objective(sol)
```

This is a *control-free* problem (no `u` in the dynamics). For a problem **with**
a control, pass a control law — `Flow(ocp, law)` — see
[Control laws](flows/control_laws.md). See
[Optimal control](flows/optimal_control.md) for the full picture, including the
basic no-costate call `f(t0, x0, tf)` for direct shooting.

### Plotting the result

Load `Plots` and any solution object draws directly — here the state and costate of
the `CTModels.Solution` on a shared time axis:

```@setup getting_started
using Plots
Base.showable(::MIME"image/png", ::Plots.Plot) = false
```

```@example getting_started
plot(sol)
```

## Where to go next

- [Optimal control](flows/optimal_control.md) — flows built directly from a `CTModels` problem.
- [Control laws](flows/control_laws.md) — `Flow(ocp, law)`, `OpenLoop` / `ClosedLoop` / `DynClosedLoop`.
- [Flows overview](flows/overview.md) — the full pipeline and the mathematical setting.
- [Integrating](flows/integrating.md) — call styles, variable parameters, solver options.
- [Multi-phase flows](flows/multiphase.md) — concatenation with switching times and jumps.
- [SciML flows](flows/sciml.md) — wrap an existing `ODEFunction` or `ODEProblem`.
- [GPU flows](flows/gpu.md) — running a flow on a device, and the rules your own functions must follow.
