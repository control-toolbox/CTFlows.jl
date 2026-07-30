# Trajectories

```@meta
CurrentModule = CTFlows
```

A trajectory integration returns a **solution object** that wraps the raw ODE result
and exposes semantic accessors. The [`CTFlows.Trajectories`](@ref CTFlows.Trajectories)
submodule provides these wrappers.

```@setup flows_solutions
using CTFlows
using CTBase: Data
using CTFlows: Flows
using CTFlows: Trajectories
using CTFlows: Integrators
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5

vf  = Data.VectorField(x -> -x)
flow = Flows.Flow(vf; reltol=1e-8)
hvf  = Data.HamiltonianVectorField((x, p) -> (p, -x))
hflow = Flows.Flow(hvf; reltol=1e-10)

# a controlled (state) flow: ẋ = -x + u with feedback u = -x, no OCP attached
fc    = Data.ControlledVectorField((x, u) -> -x + u)
cflow = Flows.Flow(fc, Data.ClosedLoop(x -> -x); reltol=1e-8)

x0, p0 = [1.0, 0.0], [0.0, 1.0]
sol  = flow((0.0, 1.0), x0)
hsol = hflow((0.0, 1.0), x0, p0)
csol = cflow((0.0, 1.0), [1.0])
```

---

## Solution types

A **trajectory** call returns one of three CTFlows containers, depending on the flow:

| Type | Produced by | Content |
|---|---|---|
| `VectorFieldTrajectory` | `StateFlow` trajectory call | state trajectory |
| `HamiltonianVectorFieldTrajectory` | `HamiltonianFlow` trajectory call | state + costate trajectories |
| `StateFlowTrajectory` | `ControlledFlow` trajectory call | state + reconstructed control (+ objective when from an OCP) |

A fourth result appears one level up: a trajectory call on an `OptimalControlFlow`
(a control-free `Flow(ocp)`, or `Flow(ocp, law)` with a `DynClosedLoop` law) returns a
[`CTModels.Solutions.Solution`](@extref CTModels.Solutions.Solution) rather than a CTFlows
container — see [Optimal control](optimal_control.md). All four share the same accessor
vocabulary (`state`, `costate`, `control`, `objective`) and the same `plot` recipe.

---

## VectorFieldTrajectory

```@example flows_solutions
sol   # produced by flow((t0, tf), x0)
```

### Accessors

| Accessor | Returns | Notes |
|---|---|---|
| `state(sol)` | callable `x(t)` | returns `sol` itself, which is callable |
| `time_grid(sol)` | vector of time points | alias for `times(sol)` |
| `final_state(sol)` | `Vector` | the final state `x(tf)` |
| `status(sol)` / `successful(sol)` | retcode / `Bool` | solver outcome (see [Solver status](#Solver-status-and-final-state)) |

```@example flows_solutions
ts = Trajectories.time_grid(sol)   # vector of time points
ts[1], ts[end]
```

```@example flows_solutions
x = Trajectories.state(sol)        # callable: x(t) → state at time t
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
xf = flow(0.0, x0, 1.0)   # Vector, not VectorFieldTrajectory
typeof(xf)
```

Use trajectory integration (`flow((t0, tf), x0)`) when you need the full history.

---

## HamiltonianVectorFieldTrajectory

```@example flows_solutions
hsol   # produced by hflow((t0, tf), x0, p0)
```

### Accessors

| Accessor | Returns | Notes |
|---|---|---|
| `state(sol)` | callable `x(t)` | state trajectory |
| `costate(sol)` | callable `p(t)` | costate trajectory |
| `time_grid(sol)` | vector of time points | alias for `times(sol)` |
| `final_state(sol)` | `(xf, pf)` | final state–costate pair |
| `status(sol)` / `successful(sol)` | retcode / `Bool` | solver outcome |

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

## StateFlowTrajectory

A `StateFlowTrajectory` is produced by a trajectory call on a
`ControlledFlow` (see [Control laws](control_laws.md)). It wraps a state
trajectory with a reconstructed control and an optional objective.

### Accessors

| Accessor | Returns | Notes |
|---|---|---|
| `state(sol)` | callable `x(t)` | state trajectory (scalar coercion for 1-D) |
| `control(sol)` | callable `u(t)` | reconstructed from the law: `u(t) = law(t, x(t), v)` |
| `objective(sol)` | `Real` | Mayer + Lagrange — **errors** unless built from an OCP |
| `time_grid(sol)` | vector of time points | alias for `times(sol)` |
| `final_state(sol)` | `Vector` | the final state `x(tf)` |
| `status(sol)` / `successful(sol)` | retcode / `Bool` | solver outcome |
| `costate(sol)` | — | **errors**: a state flow has no costate |

The `cflow` in this page's setup is a `ControlledFlow` built from `Flow(fc, law)` (no
OCP), so its trajectory `csol` carries a state and a reconstructed control:

```@example flows_solutions
x_c = Trajectories.state(csol)     # x(t)
u_c = Trajectories.control(csol)   # u(t) = law(t, x(t), v)
x_c(0.5), u_c(0.5)
```

`objective(csol)` and `costate(csol)` raise a `PreconditionError` here: this flow has no
OCP (so no cost) and is a state flow (so no costate). Build from an OCP —
`Flow(ocp, law)` — to get the objective; see [Control laws](control_laws.md).

---

## Solver status and final state

Every trajectory forwards the integrator's outcome and its final value from the
underlying result — the same accessors work on all three container types:

```@example flows_solutions
Integrators.status(sol), Integrators.successful(sol)
```

```@example flows_solutions
Integrators.final_state(sol)  # xf — a state flow returns the state
```

```@example flows_solutions
Integrators.final_state(hsol) # (xf, pf) — a Hamiltonian flow returns the pair
```

`status` returns the integrator's return code and `successful` a `Bool`. A **point**
call raises a `SolverFailure` on a non-success code unless `unsafe=true`; a trajectory
call always returns, so inspect `successful(sol)` to check convergence (see
[Integrating](integrating.md#Unsafe-mode)).

---

## Plotting

Load `Plots` (or any Plots-compatible backend) to unlock `plot` on solution objects.
The plot recipe is provided by the `CTFlowsPlots` extension (activated automatically
when `Plots` is loaded):

```@setup flows_solutions
using Plots
Base.showable(::MIME"image/png", ::Plots.Plot) = false
```

```@example flows_solutions
plot(sol)    # plots each component of the state trajectory
```

```@example flows_solutions
plot(hsol)   # plots state and costate components
```

### Plot options

Each container draws a default set of panels: `VectorFieldTrajectory` → state,
`HamiltonianVectorFieldTrajectory` → state + costate, `StateFlowTrajectory` → state +
control. Pass description symbols (`:state`, `:costate`, `:control`) to select panels,
and keywords to tune the layout:

| Keyword | Values | Effect |
|---|---|---|
| `layout` | `:split` (default) / `:group` | one subplot per component, or all in one cell |
| `control` | `:components` (default) / `:norm` / `:all` | each control, its norm, or both |
| `time` | `:default` (default) / `:normalize` | real time, or rescaled to ``[0, 1]`` |
| `state_style`, `costate_style`, `control_style` | `NamedTuple` / `:none` | per-group Plots attributes, or hide the group |
| `size` | `(w, h)` | figure size in pixels |

```@example flows_solutions
plot(hsol, :state; layout=:group, time=:normalize)   # only the state, grouped, [0,1] time
```

---

## Low-level: integration result

Under the hood, solution objects wrap an `AbstractIntegrationResult` which exposes:

- `Integrators.times(result)` — the time grid
- `Integrators.evaluate_at(result, t)` — interpolated value at `t`
- `Integrators.final_state(result)` — the final value

These are used internally by the solution wrappers and normally not called directly.

---

## See also

- [`CTFlows.Trajectories.VectorFieldTrajectory`](@ref), [`CTFlows.Trajectories.HamiltonianVectorFieldTrajectory`](@ref), [`CTFlows.Trajectories.StateFlowTrajectory`](@ref) — solution container types.
- [`CTFlows.Trajectories.state`](@ref), [`CTFlows.Trajectories.costate`](@ref), [`CTFlows.Trajectories.control`](@ref), [`CTFlows.Trajectories.objective`](@ref) — trajectory accessors.
- [`CTFlows.Trajectories.time_grid`](@ref), [`CTSolvers.Integrators.times`](@extref) — time grid accessors.
- [`CTSolvers.Integrators.final_state`](@extref), [`CTSolvers.Integrators.status`](@extref), [`CTSolvers.Integrators.successful`](@extref), [`CTSolvers.Integrators.evaluate_at`](@extref) — result / status accessors.
