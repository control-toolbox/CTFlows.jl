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
x0, p0 = 1.0, 1.0;
xf, pf = f(0.0, x0, p0, 1.0);
xf   # ≈ exp(λ)
pf   # ≈ exp(-λ)
```

The `variable`, `variable_costate` and `unsafe` keywords work as for any
Hamiltonian flow — see [Integrating](integrating.md).

---

## Free times

`Flow(ocp)` builds an `OptimalControlFlow` around an inner `HamiltonianFlow`, so the
same free-time shooting technique described in
[Integrating § Variable costate](integrating.md#Variable-costate) applies directly: a
free ``t_0`` or ``t_f`` is passed as (a component of) the `variable`, and `t1` in
`f(t0, x0, p0, t1; variable=v)` is the **evaluation time** — independent of `v`, even
when `v` *represents* the free endpoint being shot on.

Because the augmented costate is initialised at ``p_v(t_0) = 0``, the mitigated
transversality residuals can be evaluated from the OCP's own Hamiltonian —
`H = Systems.hamiltonian(f)` — with an **opposite sign convention** at each end:

```math
p_{t_0}(t_f) = -H(t_0, x_0, p_0, v), \qquad p_{t_f}(t_f) = H(t_f, x_f, p_f, v).
```

See `test/suite/flows/test_variable_costate_free_time.jl` for worked examples that
exercise this ``p_v`` mechanism (free ``t_0``, free ``t_f``, and both at once), and
[Integrating § Free times](integrating.md#Free-times) for the derivation. This settles
issues [#231](https://github.com/control-toolbox/CTFlows.jl/issues/231) and
[#183](https://github.com/control-toolbox/CTFlows.jl/issues/183). (The Goddard tests
close their free final time with the classical ``H \equiv 0`` condition instead — not
the ``p_v`` adjoint.)

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

Because the result is a `CTModels.Solution`, it plots directly once `Plots` is loaded —
state and costate on a shared time axis (the control panel is empty, the problem being
control-free):

```@setup flows_ocp
using Plots
Base.showable(::MIME"image/png", ::Plots.Plot) = false
```

```@example flows_ocp
plot(sol)
```

---

## Basic flow — no costate (direct shooting)

For a **control-free** OCP, `Flow(ocp)` also exposes a **state-only** call, with no
costate — the direct-shooting use case
([#230](https://github.com/control-toolbox/CTFlows.jl/issues/230)). Same `f` object,
dispatched on arity (3 positional arguments instead of 4):

```@repl flows_ocp
xf_basic = f(0.0, x0, 1.0)
xf_basic ≈ xf
```

A trajectory call returns a
[`StateFlowTrajectory`](@ref CTFlows.Trajectories.StateFlowTrajectory) with `law =
nothing`: state and objective are available, but the flow carries neither a control nor
a costate, so `control`/`costate` raise a `PreconditionError`:

```@example flows_ocp
sol_basic = f((0.0, 1.0), x0)
```

```@repl flows_ocp
using CTFlows.Trajectories
Trajectories.state(sol_basic)(0.5)
Trajectories.objective(sol_basic)   # ≈ exp(λ)
```

`Flow(ocp, law)` has no such basic call when `law` is `DynClosedLoop`: its dynamics
depend on the costate `p(t)`, so `f(t0, x0, tf)` raises a `PreconditionError`
suggesting `f(t0, x0, p0, tf)` instead. For an `OpenLoop`/`ClosedLoop` law, the
state-only equivalent already exists as the
[`ControlledFlow`](@ref CTFlows.Flows.ControlledFlow) returned by `Flow(ocp, law)` —
see [Control laws](control_laws.md).

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
