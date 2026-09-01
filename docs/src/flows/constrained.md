# Constrained flows

```@meta
CurrentModule = CTFlows
```

`Flow(ocp, law; constraint, multiplier)` augments the pseudo-Hamiltonian with a **path
constraint** term, for OCPs whose Pontryagin's Maximum Principle carries a state or mixed
constraint alongside the control. This chapter covers the API, the sign convention, the
`hamiltonian_type` semantics for constrained flows (`:total` vs `:partial`, and *why* they
agree on a constrained arc), and two worked examples.

```@setup flows_constrained
using CTFlows
using CTBase: Data
using CTBase: Traits
using CTFlows: Flows
using CTModels
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5
using DifferentiationInterface: DifferentiationInterface
using ForwardDiff: ForwardDiff
```

---

## The augmented pseudo-Hamiltonian

Given the OCP's own pseudo-Hamiltonian ``\tilde{H}(t,x,p,u,v) = p \cdot f + s\,p^0\,\ell``
(see [Optimal control](optimal_control.md)), a **path constraint** ``g(t,x,u,v) \ge 0``
with **multiplier** ``\mu(t,x,p,v)`` augments it as

```math
\tilde{H}_c(t,x,p,u,v) = \tilde{H}(t,x,p,u,v) + \mu(t,x,p,v)^\top g(t,x,u,v).
```

Pass `constraint`/`multiplier` to `Flow(ocp, law; …)` alongside a `DynClosedLoop` law —
they must be given **together**:

```@example flows_constrained
# OCP: ẋ = -x + u, min ∫ 0.5*u^2 dt  (autonomous, fixed, 1-D — scalar convention)
pre = CTModels.Building.PreModel()
CTModels.Building.time_dependence!(pre; autonomous=true)
CTModels.Building.time!(pre; t0=0.0, tf=1.0)
CTModels.Building.state!(pre, 1)
CTModels.Building.control!(pre, 1)
CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1] = -x + u; nothing))
CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
ocp = CTModels.Building.build(pre)

law = Data.DynClosedLoop((x, p) -> p)   # u = p (from ∂H̃/∂u = p - u = 0)
c = 0.3
f = Flows.Flow(
    ocp, law;
    constraint=Data.StateConstraint(x -> x),
    multiplier=Data.Multiplier((x, p) -> c),
    reltol=1e-10,
)
nothing # hide
```

A raw `Function` is accepted directly for `constraint`/`multiplier` (wrapped in a
`MixedConstraint`/`Multiplier` with the OCP's own time/variable dependence, just like
`Flow(ocp, u::Function)` — see [Control laws](control_laws.md)):

```@example flows_constrained
f2 = Flows.Flow(ocp, law; constraint=(x, u) -> x, multiplier=(x, p) -> c, reltol=1e-10)
xf, pf = f2(0.0, 1.0, 0.5, 1.0)
xf, pf
```

A labelled `:path` constraint from the OCP itself also resolves — pass its `Symbol` label
as `constraint`.

---

## Sign convention

`Flow(ocp, law; constraint, multiplier)` uses ``g \ge 0`` with ``H = \tilde{H} + \mu \cdot
g``. This is the opposite sign from Pontryagin's Maximum Principle as usually stated with a
constraint ``c(x) \le 0`` and multiplier ``\eta \le 0`` (Maurer's formulation): the two are
related by

```math
g = -c, \qquad \mu = -\eta.
```

Under `g ≥ 0`, the multiplier is ``\mu \ge 0`` on an active (boundary) arc, and
``\mu \equiv 0`` off it.

---

## Multiple constraints

A single constraint carrier — a `:path` label or a raw function — can already be
**vector-valued** (returning a vector, paired with a vector `multiplier`): the
``\mu \cdot g`` pairing is dimension-agnostic, so this needs no special support.

To combine **separately-defined** constraints, pass **tuples** of matched length:

```@example flows_constrained
g1(x, u) = x
g2(x, u) = 1.0 - x
μ1(x, p) = 0.4
μ2(x, p) = 0.1
ft = Flows.Flow(ocp, law; constraint=(g1, g2), multiplier=(μ1, μ2), reltol=1e-10)
nothing # hide
```

Each `gᵢ`/`μᵢ` is resolved independently (raw functions, `:path` labels, or explicit
carriers can be mixed within the tuple); the flow sums ``\sum_i \mu_i \cdot g_i``. Both
tuples must be given together, and both must have the same length — otherwise
`Flow` throws a `CTBase.Exceptions.IncorrectArgument`.

---

## `hamiltonian_type` for constrained flows

The `hamiltonian_type` keyword (`:total` default, `:partial`) works as for unconstrained
flows (see [Control laws](control_laws.md)), extended to the constraint term:

- **`:total`**: compose ``\tilde{H}_c`` with the law into a
  `CTBase.Data.ComposedHamiltonian` and differentiate **through** the law **and** the
  multiplier (total derivative in ``x``, ``p``, ``v``).
- **`:partial`**: freeze **both** the control ``u_\star = \gamma(t,x,p,v)`` **and** the
  multiplier ``\mu_\star = \mu(t,x,p,v)`` at their feedback values, then differentiate
  ``\tilde{H} + \mu_\star^\top g`` at those fixed values — ``g`` is differentiated in
  ``(x,p,v)``, ``\mu`` is not.

```@example flows_constrained
ft_ = Flows.Flow(
    ocp, law; constraint=Data.StateConstraint(x -> x),
    multiplier=Data.Multiplier((x, p) -> c), hamiltonian_type=:total, reltol=1e-10,
)
fp_ = Flows.Flow(
    ocp, law; constraint=Data.StateConstraint(x -> x),
    multiplier=Data.Multiplier((x, p) -> c), hamiltonian_type=:partial, reltol=1e-10,
)
x0, p0, tf = 1.0, 0.5, 1.0
ft_(0.0, x0, p0, tf), fp_(0.0, x0, p0, tf)   # constant μ, stationary law ⇒ agree
```

### Why `:total` and `:partial` agree on a constrained arc

Pontryagin's Maximum Principle with a state constraint ``c(x) \le 0`` (Maurer's
formulation; ``c = -g`` in this package's convention — see above) gives a
pseudo-Hamiltonian ``H(x,p,u,\eta) = \langle p, F_0(x) + u\,F_1(x)\rangle + \eta\,c(x)``.
On an active arc the *true* (closed-loop) Hamiltonian bakes in the optimal control
``u_c(x)`` and multiplier ``\eta_c(z)`` (``z = (x,p)``); its symplectic gradient decomposes
as

```math
H_c'(z) \;=\; \underbrace{\partial_z H}_{\texttt{:partial}}
\;+\; \underbrace{(\partial_u H)\,u_c'(z)}_{=\,H_1(z)\,u_c'(z)}
\;+\; \underbrace{(\partial_\eta H)\,\eta_c'(z)}_{=\,c(x)\,\eta_c'(z)}.
```

`:partial` is exactly ``\partial_z H`` — the genuine PMP field with the control and
multiplier frozen at their feedback values — correct **everywhere**. `:total` adds the two
extra chain-rule terms. Both vanish **on the arc**:

- ``c(x)\,\eta_c'(z)`` vanishes because ``c \equiv 0`` on the arc (any constraint order).
- ``H_1(z)\,u_c'(z)`` vanishes either because ``H_1 \equiv 0`` (an invariant of the
  constrained dynamics — order 1: ``\Sigma^0_1``; order 2: a richer invariant), or because
  ``u_c'\equiv 0`` (order 2: a constant control on the arc).

So `:total` and `:partial` **coincide on a constrained arc**, and a shooting method's entry
conditions put the trajectory exactly there — this is why both modes converge to the same
solution in practice, as the two worked examples below demonstrate.

---

## Plotting a constrained trajectory

A constrained `Flow(ocp, law; constraint, multiplier)` with a `DynClosedLoop` law is an
`OptimalControlFlow`, so a trajectory call returns a `CTModels.Solution` with the control
reconstructed from the law — plot it directly once `Plots` is loaded:

```@setup flows_constrained
using Plots
```

```@example flows_constrained
sol = f((0.0, 1.0), 1.0, 0.5)   # trajectory call on the constrained flow f
plot(sol)
```

---

## Worked example: Goddard problem (order 1)

The [Goddard rocket problem](https://en.wikipedia.org/wiki/Goddard_problem) (maximise final
mass under a velocity path constraint, free final time) has four arcs — two bang arcs
(``u=0``, ``u=1``), a singular arc, and a velocity-boundary arc where the state constraint
is active. On the boundary arc, ``H_1 \equiv 0`` is a genuine invariant of the order-1
constrained dynamics (``\Sigma^0_1``): both `:total` and `:partial` converge, from the
known solution and from a perturbed Newton restart, to the **same** shooting solution
(residual `< 1e-7` in both modes). This is also an end-to-end integration test of the whole
convenience surface — raw-function control law, raw-function constraint (`MixedConstraint`,
``\partial g/\partial u = 0``), raw-function multiplier, and a `NonFixed` free final time —
built directly from a `CTModels.Model` and rebuilt across all four arcs with `Flow(ocp,
law; constraint, multiplier)`, then reconstructed across phases with the `*` multi-phase
operator (see [Multi-phase flows](multiphase.md)) into a single `CTModels.Solution`. See
`test/suite/integration/test_goddard_ocp.jl` in the repository.

## Worked example: double integrator (order 2)

The time-minimal double integrator with a **second-order** position constraint
``q \le a`` (``\ddot{q} = u``) has a boundary arc where the constrained dynamics sit in a
different corner of the theory: the boundary control is **constant** (``u_c \equiv 0``) and
the multiplier is identically zero (``\mu \equiv 0``) on the arc — so `H_1\,u_c'` vanishes
because ``u_c' \equiv 0`` rather than because ``H_1 \equiv 0``, a distinct reason for the
same `:total` ≡ `:partial` equivalence. The costate **jumps** at the two junctions between
the interior and boundary arcs (`f1 * (t1, jump, f2)`, see [Multi-phase
flows](multiphase.md)), and the reconstructed multi-phase solution's control is exactly
``0`` on the boundary arc and non-zero on both interior arcs. Ported from the OptimalControl.jl
state-constraint example. See `test/suite/integration/test_double_integrator_state.jl`.

---

## See also

- [`CTFlows.Flows.Flow(ocp::CTModels.Models.Model, law::CTBase.Data.ControlLaw)`](@ref) —
  the constructor accepting `constraint`/`multiplier`.
- `CTFlows.Flows._resolve_constraint`, `CTFlows.Flows._resolve_multiplier` — spec
  resolution (label, carrier, function, tuple).
- [`CTBase.Data.StateConstraint`](@extref), [`CTBase.Data.ControlConstraint`](@extref),
  [`CTBase.Data.MixedConstraint`](@extref), [`CTBase.Data.Multiplier`](@extref) — explicit
  constructors.
- [Control laws](control_laws.md) — `hamiltonian_type`, the raw-function convenience.
- [Multi-phase flows](multiphase.md) — `*` concatenation, costate jumps.
- [Optimal control](optimal_control.md) — the unconstrained pseudo-Hamiltonian.
