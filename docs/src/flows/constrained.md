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
as `constraint`. The model stores it as ``\mathrm{lb} \le c(t,x,u,v) \le \mathrm{ub}``;
the flow normalises it as ``g \ge 0`` (see the sign convention below) from its bounds:

| Bounds stored in the model | `constraint=` | ``g`` |
| --- | --- | --- |
| lower only, ``c \ge \mathrm{lb}`` | `:label` | ``c - \mathrm{lb}`` |
| upper only, ``c \le \mathrm{ub}`` | `:label` | ``\mathrm{ub} - c`` |
| equality, ``c = \mathrm{lb}`` | `:label` | ``c - \mathrm{lb}`` |
| two-sided, ``\mathrm{lb} < \mathrm{ub}`` | `:label => :lower` | ``c - \mathrm{lb}`` |
| two-sided, ``\mathrm{lb} < \mathrm{ub}`` | `:label => :upper` | ``\mathrm{ub} - c`` |

So `x(t) - lb ≥ 0`, `x(t) ≥ lb` and `lb - x(t) ≤ 0` give the same flow. A two-sided
constraint has no active side known from the model: `:label` alone throws an
`IncorrectArgument`, and the side is given as a `Pair`. For a vector constraint, the side
is one `Symbol` for every component, or a tuple with one `Symbol` per component. (A
`Tuple` of labels is a set of constraints, see [Multiple constraints](#Multiple-constraints).)

The same constraint ``x \ge 0.1``, declared in the model as `x ≥ 0.1` and as `0.1 - x ≤ 0`,
gives the flow of the function form ``g = x - 0.1``:

```@example flows_constrained
function ocp_with(f!, lb, ub)
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(
        pre, (r, t, x, u, v) -> (r[1] = -x + u; nothing),
    )
    CTModels.Building.objective!(
        pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2,
    )
    CTModels.Building.constraint!(
        pre, :path; f=f!, lb=lb, ub=ub, label=:xcon,
    )
    return CTModels.Building.build(pre)
end

ocp_lower = ocp_with((r, t, x, u, v) -> (r[1] = x; nothing), 0.1, Inf)
ocp_upper = ocp_with((r, t, x, u, v) -> (r[1] = 0.1 - x; nothing), -Inf, 0.0)
μ(x, p) = c
f_lower = Flows.Flow(ocp_lower, law; constraint=:xcon, multiplier=μ)
f_upper = Flows.Flow(ocp_upper, law; constraint=:xcon, multiplier=μ)
f_fun = Flows.Flow(ocp, law; constraint=(x, u) -> x - 0.1, multiplier=μ)
f_lower(0.0, 1.0, 0.5, 1.0), f_upper(0.0, 1.0, 0.5, 1.0), f_fun(0.0, 1.0, 0.5, 1.0)
```

```@example flows_constrained
z = f_fun(0.0, 1.0, 0.5, 1.0)                                  # hide
@assert all(f_lower(0.0, 1.0, 0.5, 1.0) .≈ z)                  # hide
@assert all(f_upper(0.0, 1.0, 0.5, 1.0) .≈ z)                  # hide
nothing                                                        # hide
```

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

## Constraint duals of a flow

The trajectory call of `Flow(ocp, law; constraint=:label, multiplier=μ)` returns a
`CTModels.Solution` that carries the **duals of the path constraints** of the model,
rebuilt from the multiplier ``\mu`` given to the flow. They are read as for a direct
solve, with `dual(sol, ocp, :label)`, and they follow the same convention (see the
*Multiplier Convention* page of CTSolvers and
[OptimalControl.jl#1014](https://github.com/control-toolbox/OptimalControl.jl/discussions/1014)).

### The convention

The pseudo-Hamiltonian is **always maximised**, for a minimisation and for a
maximisation:

```math
H(t,x,p,u,v) = p \cdot f(t,x,u,v) + p^0\,\ell(t,x,u,v) + \mu \cdot g(t,x,u,v),
\qquad g \ge 0, \quad \mu \ge 0,
```

with ``p^0 = -1`` for `:min` and ``p^0 = +1`` for `:max` (normal case). For `min ∫ℓ` and
`max ∫(-ℓ)` the term ``p^0 \ell`` is the same, so the control, the costate ``p`` and the
multipliers ``\mu`` are the same: only the criterion changes sign. This is the indirect
counterpart of the rule of the direct solvers, which return the multipliers of the
equivalent minimisation.

The dual of a constraint is ``\mu`` itself when the constraint has a single bound, however
it is written: `x ≥ 0.1`, `x - 0.1 ≥ 0` and `0.1 - x ≤ 0` have the same dual ``\mu \ge 0``.
An equality, or a constraint with two finite bounds, has a signed dual, as in the
direct solvers:

| Constraint in the model | `constraint=` | `dual(sol, ocp, :label)` |
| --- | --- | --- |
| single bound, ``c \ge \mathrm{lb}`` or ``c \le \mathrm{ub}`` | `:label` | ``\mu \ge 0`` |
| equality, ``c = \mathrm{lb}`` | `:label` (lower side) | ``-\mu`` |
| equality | `:label => :upper` | ``+\mu`` |
| two-sided, ``\mathrm{lb} < \mathrm{ub}`` | `:label => :lower` | ``-\mu`` |
| two-sided | `:label => :upper` | ``+\mu`` |

The rows of a label are taken from the model, so **the label is the key**: a constraint
given as a function has no label, and its dual cannot be placed (see below). On an arc where
a constraint is not adjoined to the flow, its dual is ``0``.

### A closed form

``\dot x = u``, ``x(0) = -1``, ``\int_0^1 -u\,\mathrm{d}t \to \min``, with the mixed
constraint ``x + u \le 0`` active on the whole arc: ``u = -x``, ``p(t) = e^{t-1} - 1`` and
the multiplier of ``g = -(x + u) \ge 0`` is ``\mu = p + 1 = e^{t-1}``.

```@example flows_constrained
pre = CTModels.Building.PreModel()
CTModels.Building.time_dependence!(pre; autonomous=true)
CTModels.Building.time!(pre; t0=0.0, tf=1.0)
CTModels.Building.state!(pre, 1)
CTModels.Building.control!(pre, 1)
CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1] = u; nothing))
CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> -u)
CTModels.Building.constraint!(
    pre, :path; f=(r, t, x, u, v) -> (r[1] = x + u; nothing), lb=-Inf, ub=0.0,
    label=:mixed,
)
ocp_mixed = CTModels.Building.build(pre)

f_mixed = Flows.Flow(
    ocp_mixed, (x, p) -> -x; constraint=:mixed, multiplier=(x, p) -> p + 1,
    reltol=1e-10, abstol=1e-10,
)
sol_mixed = f_mixed((0.0, 1.0), -1.0, exp(-1) - 1)
d = CTModels.dual(sol_mixed, ocp_mixed, :mixed)
[(t, d(t), exp(t - 1)) for t in (0.0, 0.5, 1.0)]
```

A direct method returns the same dual, up to the discretisation error.

### Several arcs: the dual jumps at the junctions

With a multi-phase flow, each phase brings the duals of its own constraints, and the
switching structure of the solution stores the left and right limits of the duals at each
switching time, so the plot draws the jump of the multiplier at the entry and the exit of
a boundary arc. The problem of issue #440: ``\dot x = u``, ``|u| \le 1``, ``x \ge 0.1``,
``\int_0^2 x^2 \to \min``, ``x(0) = 1``, ``x(2) = 1/2``; on the boundary arc
``[0.9, 1.6]``, ``u = 0`` and ``\mu = 2x = 0.2``.

```@example flows_constrained
pre = CTModels.Building.PreModel()
CTModels.Building.time_dependence!(pre; autonomous=true)
CTModels.Building.time!(pre; t0=0.0, tf=2.0)
CTModels.Building.state!(pre, 1)
CTModels.Building.control!(pre, 1)
CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1] = u; nothing))
CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> x^2)
CTModels.Building.constraint!(
    pre, :path; f=(r, t, x, u, v) -> (r[1] = x; nothing), lb=0.1, ub=Inf, label=:xmin,
)
ocp_440 = CTModels.Building.build(pre)

opts = (; reltol=1e-10, abstol=1e-10)
f_minus = Flows.Flow(ocp_440, (x, p) -> -1; label="u = -1", opts...)
f_bound = Flows.Flow(
    ocp_440, (x, p) -> 0; constraint=:xmin, multiplier=(x, p) -> 2x, label="boundary",
    opts...,
)
f_plus = Flows.Flow(ocp_440, (x, p) -> 1; label="u = +1", opts...)
φ = f_minus * (0.9, f_bound) * (1.6, f_plus)
sol_440 = φ((0.0, 2.0), 1.0, -0.982237546583301)
d = CTModels.dual(sol_440, ocp_440, :xmin)
d(0.5), d(1.2), d(1.8)
```

```@example flows_constrained
plot(sol_440, :state, :control, :path, :dual)
```

### Without a label, and the other constraints

- A constraint given as a **function** (or as an explicit `StateConstraint`,
  `MixedConstraint`, …) has no label: the solution carries **no dual**, and
  `dual(sol, ocp, :label)` throws a `PreconditionError` that says so. When the problem has
  path constraints, the flow warns once when it is built. Give the constraint by its label,
  `constraint=:label` (or `:label => side`), to get its dual. In a multi-phase flow, one
  unlabelled phase is enough to lose the duals of the whole solution.
- The duals of the **boundary** constraints and of the **box** constraints (state, control,
  variable) are not rebuilt by a flow: `dual(sol, ocp, :label)` throws a
  `PreconditionError` for them. An unknown label throws an `IncorrectArgument`, as for
  any solution.

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
state-constraint example. See `test/cron/integration/test_double_integrator_state.jl` (part
of the weekly test suite).

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
