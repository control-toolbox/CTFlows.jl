# Optimal control

```@meta
CurrentModule = CTFlows
```

`Flows.Flow` accepts an **optimal control problem** —
a [`CTModels.Models.Model`](@extref CTModels.Models.Model) — and builds the flow of
the associated Hamiltonian system directly from the problem structure. The result is
an `OptimalControlFlow`: point calls behave like a `HamiltonianFlow`, while
trajectory calls return a full
[`CTModels.Solutions.Solution`](@extref CTModels.Solutions.Solution).

```@setup flows_ocp
using CTFlows
using CTModels
using CTFlows.Flows
using CTBase.Traits
import OrdinaryDiffEqTsit5
import DifferentiationInterface, ForwardDiff
```

---

## Control-free problems

The no-law constructor `Flow(ocp)` dispatches on the problem's
[`CTBase.Traits.ControlDependence`](@extref) trait:

- **Control-free** (`ControlFree`): the pseudo-Hamiltonian reduces to
  ``H(t, x, p, v) = p \cdot f(t, x, v) + s\,p^0\, \ell(t, x, v)`` (with
  ``p^0 = -1`` and ``s = 1`` for `:min`, ``s = -1`` for `:max`). The state
  equation ``\dot{x} = \partial_p H = f`` is computed **exactly** — no AD — and
  only ``\dot{p} = -\partial_x H`` uses automatic differentiation.
- **With control** (`WithControl`): a `PreconditionError` is thrown. Use
  `Flow(ocp, law)` to pass a control law — see
  [Control laws](control_laws.md).

---

## Building the flow

Define a control-free problem with the CTModels building API
(the exponential dynamics ``\dot{x} = \lambda x`` with a Mayer cost):

```@example flows_ocp
λ = 2.0

pre = CTModels.Building.PreModel()
CTModels.Building.time_dependence!(pre; autonomous=true)
CTModels.Building.time!(pre; t0=0.0, tf=1.0)
CTModels.Building.state!(pre, 1)
CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1] = λ * x[1]; nothing))
CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> xf[1])
ocp = CTModels.Building.build(pre)
nothing # hide
```

Then hand it to `Flows.Flow`:

```@example flows_ocp
f = Flows.Flow(ocp; reltol=1e-10, abstol=1e-10)
```

Keyword options are routed exactly as for `Flow(h::Data.AbstractHamiltonian)`:
integrator options (`reltol`, `abstol`, `alg`, …) go to the SciML strategy, AD
options (`ad_backend`) to the DifferentiationInterface strategy.

---

## Point calls — Hamiltonian semantics

Point evaluation delegates to the inner `HamiltonianFlow` and returns the final
state–costate pair. For ``\dot{x} = \lambda x`` the costate satisfies
``\dot{p} = -\lambda p``:

```@repl flows_ocp
x0, p0 = [1.0], [1.0];
xf, pf = f(0.0, x0, p0, 1.0);
xf   # ≈ exp(λ)
pf   # ≈ exp(-λ)
```

The `variable`, `variable_costate` and `unsafe` keywords work as for any
Hamiltonian flow — see [Integrating](integrating.md).

---

## Trajectory calls — a `CTModels.Solution`

A trajectory call integrates the Hamiltonian system **and** assembles a complete
[`CTModels.Solutions.Solution`](@extref CTModels.Solutions.Solution): state and
costate interpolants, an empty control (the problem is control-free), and the
objective value (Mayer, Lagrange, or Bolza — a Lagrange cost is integrated with the
same integrator).

```@example flows_ocp
sol = f((0.0, 1.0), x0, p0)
```

Use the standard CTModels accessors on the result:

```@repl flows_ocp
CTModels.Components.objective(sol)    # ≈ exp(λ)
CTModels.Components.state(sol)(0.5)   # x(0.5) ≈ exp(λ/2)
CTModels.Components.costate(sol)(0.5) # p(0.5) ≈ exp(-λ/2)
```

---

## Inspecting the wrapper

`OptimalControlFlow` is a thin `AbstractFlow` wrapper around the inner
`HamiltonianFlow`; it exists solely so the trajectory call can rebuild a
`CTModels.Solution` from the problem:

```@repl flows_ocp
Flows.system(f) isa CTFlows.Systems.HamiltonianSystem
Traits.time_dependence(f)
```

---

## See also

- [`CTFlows.Flows.OptimalControlFlow`](@ref) — the wrapper type.
- [`CTFlows.Flows.Flow`](@ref) — the constructor family, including `Flow(ocp)`.
- [`CTModels.Solutions.Solution`](@extref), [`CTModels.Components.objective`](@extref) — the trajectory-call result and its accessors.
- [Control laws](control_laws.md) — `Flow(ocp, law)` for with-control problems.
- [Constrained flows](constrained.md) — `constraint`/`multiplier` path-constraint terms.
- [Building a flow](building_a_flow.md) — AD-backed Hamiltonian flows.
