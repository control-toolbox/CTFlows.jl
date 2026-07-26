# Building a flow

```@meta
CurrentModule = CTFlows
```

A **flow** is a callable that integrates a system from an initial condition to a final
time. Building one involves three steps:

```
Data  →  build_system  →  SciML  →  build_flow  →  Flow
```

The shortcut constructor `Flows.Flow(data; opts...)` collapses all three steps into one
call. This page explains both paths.

```@setup flows_building
using CTFlows
using CTBase.Data
using CTBase.Traits
using CTFlows.Systems
using CTFlows.Integrators
using CTFlows.Flows
using CTFlows.Trajectories
using CTFlows.Configs
import OrdinaryDiffEqTsit5
```

---

## Shortcut: `Flows.Flow`

The simplest way to build a flow is to pass data directly to `Flows.Flow`:

```@example flows_building
# From a VectorField → StateFlow
vf = Data.VectorField(x -> -x)
flow = Flows.Flow(vf; reltol=1e-8, abstol=1e-8)
```

```@example flows_building
# From a HamiltonianVectorField → HamiltonianFlow
hvf = Data.HamiltonianVectorField((x, p) -> (p, -x))
hflow = Flows.Flow(hvf; reltol=1e-10)
```

```@example flows_building
# From a scalar Hamiltonian (AD computes the derivatives) → HamiltonianFlow
import DifferentiationInterface, ForwardDiff
using LinearAlgebra
h = Data.Hamiltonian((x, p) -> 0.5 * (dot(x, x) + dot(p, p)))
hflow_ad = Flows.Flow(h; reltol=1e-10)
```

Options passed as keyword arguments are forwarded to the integrator strategy;
see [Integrating](integrating.md#integrator-options) for the full list.

---

## Explicit pipeline

The explicit form gives full control over each step.

### Step 1 — Build the system

`build_system` wraps data into an `AbstractSystem` that exposes the ODE
right-hand side:

```@example flows_building
# VectorField → VectorFieldSystem
sys = Systems.build_system(vf)
```

```@example flows_building
# HamiltonianVectorField → HamiltonianVectorFieldSystem
hsys = Systems.build_system(hvf)
```

A system exposes:

```@repl flows_building
Traits.time_dependence(sys)
Traits.variable_dependence(sys)
```

```@example flows_building
config = Configs.StateEndPointConfig(0.0, [1.0, 0.0], 1.0)
```

```@example flows_building
Systems.get_ip_rhs(sys, config)
```

```@example flows_building
Systems.get_oop_rhs(sys, config)
```

### Step 2 — Build the integrator

The integrator is a strategy object; construct it directly with its options.

```@example flows_building
integ = Integrators.SciML(; reltol=1e-8, abstol=1e-8)
```

`SciML` is the integrator strategy provided by CTSolvers (backed by
`OrdinaryDiffEqTsit5` when loaded). See [Integrating](integrating.md) for how to choose
a different algorithm.

### Step 3 — Combine into a flow

```@example flows_building
flow_explicit = Flows.build_flow(sys, integ)
```

This produces the same `StateFlow` as the shortcut:

```@example flows_building
typeof(flow_explicit) == typeof(flow)
```

---

## Flow types

| Input data | Flow type |
|---|---|
| `VectorField` | `StateFlow` |
| `HamiltonianVectorField` | `HamiltonianFlow` |
| `Hamiltonian` (with AD) | `HamiltonianFlow` |
| `PseudoHamiltonian` + `DynClosedLoop` law | `HamiltonianFlow` |
| `PseudoHamiltonianVectorField` + `DynClosedLoop` law | `HamiltonianFlow` |
| `ControlledVectorField` + `OpenLoop`/`ClosedLoop` law | `ControlledFlow` |
| OCP (control-free) | `OptimalControlFlow` |
| OCP (with control) + `DynClosedLoop` law | `OptimalControlFlow` |
| OCP (with control) + `OpenLoop`/`ClosedLoop` law | `ControlledFlow` |
| OCP (with control) + `u::Function` | `OptimalControlFlow` (auto `DynClosedLoop`) |

Both `StateFlow` and `HamiltonianFlow` are concrete subtypes of `AbstractFlow`.
`ControlledFlow` is a state-flow wrapper carrying a control law (see
[Control laws](control_laws.md)).
`OptimalControlFlow` wraps a `HamiltonianFlow` with the OCP reference (see
[Optimal control](optimal_control.md)).
Their trait parameters mirror the underlying data:

```@repl flows_building
Traits.time_dependence(flow)      # Autonomous (inherited from vf)
Traits.variable_dependence(flow)  # Fixed
```

### `AbstractSystem` contract

Any concrete system must implement:

- `get_ip_rhs(system, config)` — returns the in-place ODE function `(du, u, p, t) -> nothing`
- `get_oop_rhs(system, config)` — returns the out-of-place ODE function `(u, p, t) -> du`

Hamiltonian systems supporting variable-costate integration additionally implement
`get_ip_rhs_augmented(system, config)`. Eager systems (e.g. `VectorFieldSystem`)
ignore `config` and return pre-computed closures; lazy systems (e.g.
`HamiltonianSystem`) read the initial conditions from `config` to build
type-specific closures.

Traits are propagated automatically from the data layer:

- `Traits.time_dependence(system)`
- `Traits.variable_dependence(system)`

### `AbstractFlow` contract

Any concrete flow must implement:

- `system(flow)` — the associated `AbstractSystem`
- `integrator(flow)` — the associated `AbstractIntegrator`

```@example flows_building
Flows.system(flow)      # the VectorFieldSystem wrapped by this StateFlow
```

```@example flows_building
Flows.integrator(flow)  # the SciML integrator strategy
```

Calling a flow delegates through `_invoke_flow` which builds the ODE problem,
solves it, and wraps the result — see [Integrating](integrating.md).

---

## Flow getters

Every flow answers a small, uniform set of getters. Which ones are meaningful depends
on how the flow was built; calling an inapplicable getter raises a clear
`IncorrectArgument`.

`system`, `integrator`, and `vector_field` are available on all flows (the first two
are shown in the `AbstractFlow` contract above). For a `StateFlow`, `vector_field`
returns the underlying `AbstractVectorField` directly:

```@repl flows_building
Flows.vector_field(flow)
```

For a `HamiltonianFlow`, `vector_field` is an alias of `hamiltonian_vector_field` and
returns ``X_H = (\partial_p H, -\partial_x H)``:

```@repl flows_building
Flows.vector_field(hflow)
Flows.hamiltonian_vector_field(hflow)
Flows.vector_field(hflow) === Flows.hamiltonian_vector_field(hflow)
```

For an AD-backed `HamiltonianFlow` (built from a scalar `Hamiltonian`), the Hamiltonian
itself is also available:

```@repl flows_building
Flows.hamiltonian(hflow_ad)
Flows.hamiltonian_vector_field(hflow_ad)
```

`hamiltonian_vector_field` (and therefore `vector_field`) also covers flows built
from a pseudo-Hamiltonian or an OCP together with a control law — the Hamiltonian is
then a `CTBase.Data.ComposedHamiltonian` (`:total` mode) or reconstructed from a
`PseudoHamiltonianSystem` (`:partial` mode). The pseudo-Hamiltonian getters
(`pseudo_hamiltonian`, `control_law`, `pseudo_hamiltonian_gradient`,
`pseudo_variable_gradient`) and `variable_gradient` are shown on
[Control laws](control_laws.md) and [Integrating](integrating.md) respectively.

---

## See also

- [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Flows.StateFlow`](@ref), [`CTFlows.Flows.HamiltonianFlow`](@ref) — concrete flow types.
- [`CTFlows.Flows.build_flow`](@ref), [`CTFlows.Systems.build_system`](@ref), [`CTSolvers.Integrators.SciML`](@extref) — pipeline builders.
- [`CTFlows.Flows.AbstractFlow`](@ref), [`CTFlows.Flows.AbstractStateFlow`](@ref), [`CTFlows.Flows.AbstractHamiltonianFlow`](@ref) — abstract supertypes.
- [`CTFlows.Flows.system`](@ref), [`CTFlows.Flows.integrator`](@ref) — flow accessors.
- [`CTFlows.Systems.AbstractSystem`](@ref), [`CTFlows.Systems.get_ip_rhs`](@ref), [`CTFlows.Systems.get_oop_rhs`](@ref) — system contract.
- [`CTFlows.Systems.vector_field`](@ref), [`CTFlows.Flows.hamiltonian_vector_field`](@ref) — vector field getters (state and Hamiltonian flows).
