# Trajectories

```@meta
CurrentModule = CTFlows
```

A trajectory integration returns a **solution object** that wraps the raw ODE result
and exposes semantic accessors. The [`CTFlows.Trajectories`](@ref CTFlows.Trajectories)
submodule provides these wrappers.

```@setup flows_solutions
using CTFlows
using CTFlows.Data
using CTFlows.Flows
using CTFlows.Trajectories
using CTFlows.Integrators
import OrdinaryDiffEqTsit5

vf  = Data.VectorField(x -> -x)
flow = Flows.Flow(vf; reltol=1e-8)
hvf  = Data.HamiltonianVectorField((x, p) -> (p, -x))
hflow = Flows.Flow(hvf; reltol=1e-10)

x0, p0 = [1.0, 0.0], [0.0, 1.0]
sol  = flow((0.0, 1.0), x0)
hsol = hflow((0.0, 1.0), x0, p0)
```

---

## Solution types

| Type | Produced by | Content |
|---|---|---|
| `VectorFieldSolution` | `StateFlow` trajectory call | state trajectory |
| `HamiltonianVectorFieldSolution` | `HamiltonianFlow` trajectory call | state + costate trajectories |

---

## VectorFieldSolution

```@example flows_solutions
sol   # produced by flow((t0, tf), x0)
```

### Accessors

```@example flows_solutions
ts = Trajectories.time_grid(sol)      # vector of time points
ts[1], ts[end]
```

```@example flows_solutions
x = Trajectories.state(sol)           # callable: x(t) → state at time t
x(0.0)                             # initial state (exact)
```

```@example flows_solutions
x(0.5)                             # interpolated at t = 0.5
```

```@example flows_solutions
x.(ts)                             # broadcast over the time grid
```

`state(sol)` returns `sol` itself, which is callable. The two forms `state(sol)(t)`
and `sol(t)` are equivalent. `time_grid` is an alias for `times`.

### Point integration vs trajectory

Point integration (`flow(t0, x0, tf)`) returns the final state directly as a
`Vector`, **not** a solution object:

```@example flows_solutions
xf = flow(0.0, x0, 1.0)   # Vector, not VectorFieldSolution
typeof(xf)
```

Use trajectory integration (`flow((t0, tf), x0)`) when you need the full history.

---

## HamiltonianVectorFieldSolution

```@example flows_solutions
hsol   # produced by hflow((t0, tf), x0, p0)
```

### Accessors

```@example flows_solutions
ts_h = Trajectories.time_grid(hsol)
```

```@example flows_solutions
x_h = Trajectories.state(hsol)      # state trajectory: x(t)
p_h = Trajectories.costate(hsol)    # costate trajectory: p(t)
x_h(0.0), p_h(0.0)
```

```@example flows_solutions
x_h(0.5), p_h(0.5)
```

---

## Plotting

Load `Plots` (or any Plots-compatible backend) to unlock `plot` on solution objects:

```julia
using Plots
plot(sol)    # plots each component of the state trajectory
plot(hsol)   # plots state and costate components
```

The plot recipe is provided by the `CTFlowsPlots` extension (activated automatically
when `Plots` is loaded).

---

## Low-level: integration result

Under the hood, solution objects wrap an `AbstractIntegrationResult` which exposes:

- `Integrators.times(result)` — the time grid
- `Integrators.evaluate_at(result, t)` — interpolated value at `t`
- `Integrators.final_state(result)` — the final value

These are used internally by the solution wrappers and normally not called directly.

---

## See also

- [`CTFlows.Trajectories.VectorFieldSolution`](@ref), [`CTFlows.Trajectories.HamiltonianVectorFieldSolution`](@ref) — solution container types.
- [`CTFlows.Trajectories.state`](@ref), [`CTFlows.Trajectories.costate`](@ref) — trajectory accessors.
- [`CTFlows.Trajectories.time_grid`](@ref), [`CTFlows.Integrators.times`](@ref) — time grid accessors.
- [`CTFlows.Integrators.final_state`](@ref), [`CTFlows.Integrators.evaluate_at`](@ref) — low-level result accessors.
