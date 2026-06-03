# Building a flow

```@meta
CurrentModule = CTFlows
```

A **flow** is a callable that integrates a system from an initial condition to a final
time. Building one involves three steps:

```
Data  →  build_system  →  build_integrator  →  build_flow  →  Flow
```

The shortcut constructor `Flows.Flow(data; opts...)` collapses all three steps into one
call. This page explains both paths.

```@setup flows_building
using CTFlows
using CTFlows.Data
using CTFlows.Traits
using CTFlows.Systems
using CTFlows.Integrators
using CTFlows.Flows
using CTFlows.Solutions
import OrdinaryDiffEqTsit5
```

---

## Shortcut: `Flows.Flow`

The simplest way to build a flow is to pass data directly to `Flows.Flow`:

```@example flows_building
# From a VectorField → StateFlow
vf   = Data.VectorField(x -> -x)
flow = Flows.Flow(vf; reltol=1e-8, abstol=1e-8)
```

```@example flows_building
# From a HamiltonianVectorField → HamiltonianFlow
hvf  = Data.HamiltonianVectorField((x, p) -> (p, -x))
hflow = Flows.Flow(hvf; reltol=1e-10)
```

```@example flows_building
using LinearAlgebra

# From a scalar Hamiltonian (AD computes the derivatives) → HamiltonianFlow
import DifferentiationInterface, ForwardDiff
h    = Data.Hamiltonian((x, p) -> 0.5 * (dot(x, x) + dot(p, p)))
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
- `Systems.rhs(sys)` — the ODE right-hand side function `(du, u, p, t) -> …`
- `Traits.time_dependence(sys)`, `Traits.variable_dependence(sys)` — delegated from the data

### Step 2 — Build the integrator

```@example flows_building
integ = Integrators.build_integrator(; reltol=1e-8, abstol=1e-8)
```

The default integrator is `SciML` (backed by `OrdinaryDiffEqTsit5` when loaded).
See [Integrating](integrating.md) for how to choose a different algorithm.

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

Both `StateFlow` and `HamiltonianFlow` are concrete subtypes of `AbstractFlow`.
Their trait parameters mirror the underlying data:

```@example flows_building
Traits.time_dependence(flow)      # Autonomous (inherited from vf)
Traits.variable_dependence(flow)  # Fixed
```

### `AbstractSystem` contract

Any concrete system must implement:

- `rhs(system)` — returns an ODE function `(du, u, p, t) -> nothing`

Traits are propagated automatically from the data layer:

- `Traits.time_dependence(system)`
- `Traits.variable_dependence(system)`

### `AbstractFlow` contract

Any concrete flow must implement:

- `system(flow)` — the associated `AbstractSystem`
- `integrator(flow)` — the associated `AbstractIntegrator`

Calling a flow delegates through `_invoke_flow` which builds the ODE problem,
solves it, and wraps the result — see [Integrating](integrating.md).

---

## Hamiltonian vector field getter

For a `HamiltonianFlow`, you can retrieve the underlying `HamiltonianVectorField`
at any time:

```@example flows_building
# HamiltonianVectorField-backed flow
hvf_back = Flows.hamiltonian_vector_field(hflow)
```

For an AD-backed flow (built from `Hamiltonian`), the getter materialises the
vector field on demand:

```@example flows_building
hvf_ad = Flows.hamiltonian_vector_field(hflow_ad)
```

---

## API reference

```@docs
CTFlows.Flows.Flow
CTFlows.Flows.build_flow
CTFlows.Systems.build_system
CTFlows.Integrators.build_integrator
CTFlows.Flows.AbstractFlow
CTFlows.Flows.AbstractStateFlow
CTFlows.Flows.AbstractHamiltonianFlow
CTFlows.Flows.StateFlow
CTFlows.Flows.HamiltonianFlow
CTFlows.Flows.system
CTFlows.Flows.integrator
CTFlows.Systems.AbstractSystem
CTFlows.Systems.rhs
```
