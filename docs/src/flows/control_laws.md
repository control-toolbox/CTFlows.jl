# Control laws

```@meta
CurrentModule = CTFlows
```

When the dynamical system depends on a **control** ``u``, the flow cannot be
integrated directly: the control must be eliminated by a **control law** that
expresses ``u`` as a function of the available state variables. CTFlows supports
three kinds of control laws, each leading to a different flow type.

```@setup flows_laws
using CTFlows
using CTBase.Data
using CTBase.Traits
using CTFlows.Flows
using CTFlows.Trajectories
using CTModels
import OrdinaryDiffEqTsit5
import DifferentiationInterface, ForwardDiff
```

---

## Control law types

All control laws live in [`CTBase.Data`](@extref CTBase.Data) and are constructed
by wrapping a function:

| Law | Constructor | Feedback signature | Available state |
|---|---|---|---|
| `OpenLoop` | `Data.OpenLoop(u)` | `u(t, v)` | none (time only) |
| `ClosedLoop` | `Data.ClosedLoop(u)` | `u(t, x, v)` | state ``x`` |
| `DynClosedLoop` | `Data.DynClosedLoop(u)` | `u(t, x, p, v)` | state + costate ``(x, p)`` |

The trait [`CTBase.Traits.feedback`](@extref) distinguishes the three and drives
dispatch in `Flow` constructors.

---

## Two flow paths

| Law type | Flow type | Dynamics | Trajectory result |
|---|---|---|---|
| `DynClosedLoop` | `HamiltonianFlow` / `OptimalControlFlow` | Hamiltonian (state + costate) | `HamiltonianVectorFieldTrajectory` / `CTModels.Solution` |
| `OpenLoop` / `ClosedLoop` | `ControlledFlow` (state flow) | state only | `StateFlowTrajectory` |

A `DynClosedLoop` law needs the costate ``p`` to evaluate the feedback, so it
produces a **Hamiltonian** flow. An `OpenLoop` or `ClosedLoop` law does not need
``p``, so the control is eliminated upfront and the system is integrated as a
**state** flow.

---

## `Flow(h̃, law)` — pseudo-Hamiltonian + DynClosedLoop

A `Data.PseudoHamiltonian` wraps the
function ``\tilde{H}(t, x, p, u, v)``. Combined with a `DynClosedLoop` law
``u(t, x, p, v)``, the control is substituted to form the closed-loop
Hamiltonian ``H(t, x, p, v) = \tilde{H}(t, x, p, u(t, x, p, v), v)``.

The `hamiltonian_type` keyword controls how AD is applied:

- **`:total`** (default): compose ``\tilde{H}`` with the law into a
  `Data.ComposedHamiltonian` and
  differentiate **through** the law (total derivative).
- **`:partial`**: build a
  [`CTFlows.Systems.PseudoHamiltonianSystem`](@ref) that takes partial
  derivatives of ``\tilde{H}`` at the fixed feedback value ``u``. This coincides
  with `:total` only where the feedback is stationary (``\partial \tilde{H}/\partial u = 0``).

```@example flows_laws
# Pseudo-Hamiltonian: H̃(x, p, u) = p * u - 0.5 * u^2  (maximised at u = p)
h̃ = Data.PseudoHamiltonian((x, p, u) -> p * u - 0.5 * u^2)
law = Data.DynClosedLoop((x, p) -> p)  # u = p

# Total mode (default): AD through the law
f_total = Flows.Flow(h̃, law; reltol=1e-10)

# Partial mode: AD at fixed u
f_partial = Flows.Flow(h̃, law; hamiltonian_type=:partial, reltol=1e-10)
nothing # hide
```

!!! warning "OpenLoop/ClosedLoop rejected"
    A `PseudoHamiltonian` depends on the costate ``p``, which `OpenLoop` and
    `ClosedLoop` laws do not provide. Passing one raises a `PreconditionError`.

---

## `Flow(fc, law)` — controlled vector field + OpenLoop/ClosedLoop

A `Data.ControlledVectorField`
wraps ``f_c(t, x, u, v)``. Combined with an `OpenLoop` or `ClosedLoop` law, the
control is eliminated via a
`Data.ComposedVectorField`
``g(t, x, v) = f_c(t, x, u(\ldots), v)``, and the result is integrated as a
state flow. The resulting [`ControlledFlow`](@ref CTFlows.Flows.ControlledFlow)
carries no OCP, so trajectory calls return a `StateFlowTrajectory` **without**
an objective.

```@example flows_laws
# Controlled dynamics: ẋ = -x + u
fc = Data.ControlledVectorField((x, u) -> -x + u)
law = Data.ClosedLoop(x -> -x)  # feedback u = -x

f = Flows.Flow(fc, law; reltol=1e-8)
nothing # hide
```

!!! warning "DynClosedLoop rejected"
    A `DynClosedLoop` law needs the costate ``p``, which a state flow does not
    have. Use `Flow(h̃, law)` or `Flow(ocp, law)` instead.

---

## `Flow(ocp, law)` — OCP + control law

For an OCP **with control**, pass a control law to `Flow(ocp, law)`. The
constructor dispatches on the law's feedback trait:

### DynClosedLoop → `OptimalControlFlow`

The OCP's dynamics and cost supply the pseudo-Hamiltonian
``\tilde{H}(t, x, p, u, v) = p \cdot f + s\,p^0\, \ell``. The law closes the
loop and the resulting flow is an
[`OptimalControlFlow`](@ref CTFlows.Flows.OptimalControlFlow) — point calls
behave like a `HamiltonianFlow`, trajectory calls return a
[`CTModels.Solutions.Solution`](@extref CTModels.Solutions.Solution) with the
control reconstructed from the law.

The `hamiltonian_type` keyword (`:total` default, `:partial`) works as in
`Flow(h̃, law)`.

```@example flows_laws
# OCP: ẋ = -x + u, min ∫ 0.5*u^2 dt  (autonomous, fixed, 1-D — scalar convention)
pre = CTModels.Building.PreModel()
CTModels.Building.time_dependence!(pre; autonomous=true)
CTModels.Building.time!(pre; t0=0.0, tf=1.0)
CTModels.Building.state!(pre, 1)
CTModels.Building.control!(pre, 1)
CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1] = -x + u; nothing))
CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
ocp = CTModels.Building.build(pre)
nothing # hide
```

```@example flows_laws
# DynClosedLoop law: u(x, p) = p  (from PMP, maximises H̃ = p*(-x+u) - 0.5*u^2)
law = Data.DynClosedLoop((x, p) -> p)
f_ocp = Flows.Flow(ocp, law; reltol=1e-10)
nothing # hide
```

Point evaluation returns the final state–costate pair:

```@repl flows_laws
x0, p0 = 1.0, 0.5;
xf, pf = f_ocp(0.0, x0, p0, 1.0);
xf
pf
```

Trajectory evaluation returns a `CTModels.Solution`:

```@example flows_laws
sol = f_ocp((0.0, 1.0), x0, p0)
CTModels.Components.objective(sol)
```

### OpenLoop / ClosedLoop → `ControlledFlow`

The OCP's controlled dynamics are extracted as a `ControlledVectorField`, the
law eliminates the control, and the result is a
[`ControlledFlow`](@ref CTFlows.Flows.ControlledFlow) — a **state** flow. Point
calls return the final state (no costate); trajectory calls return a
[`StateFlowTrajectory`](@ref CTFlows.Trajectories.StateFlowTrajectory) with
state, reconstructed control, and objective (Mayer + Lagrange).

```@example flows_laws
# OpenLoop law: u() = 1 (constant, autonomous ⇒ no time argument)
law_ol = Data.OpenLoop(() -> 1.0)
f_cflow = Flows.Flow(ocp, law_ol; reltol=1e-8)
nothing # hide
```

```@repl flows_laws
xf_c = f_cflow(0.0, 1.0, 1.0)
```

```@example flows_laws
sol_c = f_cflow((0.0, 1.0), 1.0)
Trajectories.objective(sol_c)   # ≈ 0.5 * 1^2 * 1 = 0.5
```

---

## Convenience: `Flow(ocp, u::Function)`

A plain function `u` is wrapped in a `DynClosedLoop` law automatically, with
time/variable dependence inferred from the OCP:

```julia
f = Flows.Flow(ocp, (x, p) -> p; reltol=1e-10)  # autonomous, fixed
```

The function `u` **must** have the natural arity matching the OCP's traits:
`(x, p)`, `(t, x, p)`, `(x, p, v)`, or `(t, x, p, v)`. To use a law whose
traits differ from the OCP's, construct the `DynClosedLoop` explicitly.

---

## `ControlledFlow` type

A [`ControlledFlow`](@ref CTFlows.Flows.ControlledFlow) wraps:

- an inner state `Flow` integrating the closed-loop dynamics ``\dot{x} = g(t, x, v)``,
- an optional OCP (for the objective),
- the control law (for reconstructing ``u(t)``).

It is a subtype of `AbstractFlow` with `StateDynamics`. Point evaluation
returns the final state (no costate); trajectory evaluation returns a
`StateFlowTrajectory`.

---

## `StateFlowTrajectory`

A [`StateFlowTrajectory`](@ref CTFlows.Trajectories.StateFlowTrajectory) is
the result of a trajectory call on a `ControlledFlow`. It provides:

| Accessor | Returns | Notes |
|---|---|---|
| `state(sol)` | callable `x(t)` | state trajectory (scalar coercion for 1-D state) |
| `control(sol)` | callable `u(t)` | reconstructed from the law: `u(t) = law(t, x(t), v)` |
| `objective(sol)` | `Real` or `nothing` | Mayer + Lagrange (only when built from an OCP) |
| `time_grid(sol)` | vector of time points | |
| `costate(sol)` | — | **errors**: a state flow has no costate |

```@example flows_laws
x_c = Trajectories.state(sol_c)
u_c = Trajectories.control(sol_c)
x_c(0.5), u_c(0.5)
```

---

## Summary table

| Constructor | Law type | Resulting flow | Trajectory type |
|---|---|---|---|
| `Flow(h̃, law)` | `DynClosedLoop` | `HamiltonianFlow` | `HamiltonianVectorFieldTrajectory` |
| `Flow(fc, law)` | `OpenLoop` / `ClosedLoop` | `ControlledFlow` | `StateFlowTrajectory` (no objective) |
| `Flow(ocp, law)` | `DynClosedLoop` | `OptimalControlFlow` | `CTModels.Solution` |
| `Flow(ocp, law)` | `OpenLoop` / `ClosedLoop` | `ControlledFlow` | `StateFlowTrajectory` (with objective) |
| `Flow(ocp, u::Function)` | `DynClosedLoop` (auto) | `OptimalControlFlow` | `CTModels.Solution` |

---

## See also

- [`CTFlows.Flows.ControlledFlow`](@ref), [`CTFlows.Flows.OptimalControlFlow`](@ref) — flow types.
- [`CTFlows.Trajectories.StateFlowTrajectory`](@ref) — trajectory with reconstructed control.
- [`CTFlows.Trajectories.control`](@ref), [`CTFlows.Trajectories.objective`](@ref) — controlled trajectory accessors.
- [`CTBase.Data.OpenLoop`](@extref), [`CTBase.Data.ClosedLoop`](@extref), [`CTBase.Data.DynClosedLoop`](@extref) — control law constructors.
- `Data.PseudoHamiltonian`, `Data.ControlledVectorField` — data types for controlled systems.
- [Optimal control](optimal_control.md) — `Flow(ocp)` for control-free problems.
- [Constrained flows](constrained.md) — `constraint`/`multiplier` on `Flow(ocp, law)`.
- [Building a flow](building_a_flow.md) — the general pipeline.
