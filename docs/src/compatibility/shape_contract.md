# Shape contract: "1-D = scalar" across `Flow` constructors

```@meta
CurrentModule = CTFlows
```

This page is the **single cross-constructor reference** for the ecosystem's
["1-D = scalar"](https://github.com/control-toolbox/Handbook/blob/main/philosophy/dimension-and-shape.md)
convention: a one-dimensional state (or costate) must be a **scalar** end to end — never a
length-1 container — in every user-facing function, `Flow` call, and returned trajectory
accessor. It consolidates what used to be a handful of scattered per-page admonitions
into one table and one set of runnable examples, and records the design decision behind
[issue #357](https://github.com/control-toolbox/CTFlows.jl/issues/357): **which**
constructors this convention applies to, and why one deliberately sits outside it.

Every ✓ / ✗ example below is a Documenter `@example`/`@repl` block re-run on every
documentation build, so this page cannot drift from the code. Scope: **CPU** only, same as
every other page in this section.

```@setup shape_compat
using CTFlows
using CTBase.Data
using CTFlows.Flows
using CTFlows.Trajectories
using SciMLBase: SciMLBase
import OrdinaryDiffEqTsit5
```

---

## The rule

[`CTFlows.Systems._coerce_state`](@ref) is the coercion applied at
every point call and trajectory accessor governed by this convention:

- a bare `Number` (`::Real`, `::Complex`) stays a scalar — trivially, it already is one;
- a **length-1** `AbstractVector` (`[2.0]`, `SA[2.0]`, …) *collapses* to its single element,
  via `Systems._safe_only` (a GPU-safe `only`);
- a **length ≥ 2** `AbstractVector`, or any `AbstractMatrix` (batch mode), is left
  untouched (`identity`) — this convention only ever *removes* a spurious length-1
  wrapper, never changes any other shape.

The same rule is applied on the **input** side too: a state-flow's RHS wrapper reads the
initial state's shape once (at the first call, from the config) and builds the matching
`only`/`identity` coercion for the user's function — so a `Data.VectorField` or
`SciMLBase.ODEFunction` written against a scalar `x` is called with a genuine scalar even
when `x0` was supplied as `[2.0]`.

## The dividing line

The fix for #357 does **not** split constructors by "control-toolbox object vs. SciML
object" — it splits them by **whether the call reaches CTFlows' own `Systems`/
`Trajectories` dispatch at all**:

- `Flow(::SciMLBase.AbstractODEFunction)` (see [`Flow(SciML)`](sciml.md)) wraps the
  function in `CTFlowsSciMLFlows.SciMLFunctionSystem`, which implements
  `Systems.AbstractSystem` and shares the exact same `build_trajectory` dispatch as
  `VectorFieldSystem` — so it **is** in scope, even though it wraps a SciML type.
- `Flow(::SciMLBase.AbstractODEProblem)` (see [`Flow(SciML)`](sciml.md)) wraps the
  fully-assembled problem in `SciMLProblemFlow`, which calls `SciMLBase.remake` +
  `CommonSolve.solve` **directly** — it never constructs a CTFlows `AbstractSystem` and
  never reaches `Trajectories.build_trajectory`, so there is nothing for this convention to
  attach to. This is a genuine bypass, not an oversight: coercing here would mean silently
  reshaping a value the user handed straight to their own `SciMLBase.ODEProblem`.

## Compliance table

| Constructor | Reaches CTFlows dispatch? | Coercion mechanism | 1-D = scalar? | Reference |
|---|:---:|---|:---:|---|
| `Flow(::VectorField)` | ✓ | `Systems._coerce_state` | ✓ | [`Flow(VectorField)`](vector_field.md) |
| `Flow(::HamiltonianVectorField)` | ✓ | `Systems._coerce_state` | ✓ | [`Flow(HamiltonianVectorField)`](hamiltonian_vector_field.md) |
| `Flow(::Hamiltonian)` | ✓ | `Systems._coerce_state` | ✓ | [`Flow(Hamiltonian)`](hamiltonian.md) |
| `Flow(h̃, DynClosedLoop)` | ✓ | `Systems._coerce_state` (`PseudoHamiltonianSystem`) | ✓ | [`Flow(h̃, law)`](pseudo_hamiltonian.md) |
| `Flow(fc, law)` | ✓ | `Flows._dim_coerce` (from `length(x0)`) | ✓ | [`Flow(fc, law)`](controlled_vector_field.md) |
| `Flow(ocp)` / `Flow(ocp, law)` | ✓ | `Flows._dim_coerce` (from the OCP's declared `state_dimension`) | ✓ | [`Flow(ocp)`](ocp_free.md) / [`Flow(ocp, law)`](ocp_control_laws.md) |
| `Flow(::SciMLBase.AbstractODEFunction)` | ✓ | `Systems._coerce_state` (`SciMLFunctionSystem`) | ✓ *(new, #357)* | [`Flow(SciML)`](sciml.md) |
| `Flow(::SciMLBase.AbstractODEProblem)` | ✗ (direct `remake`+`solve`) | — none — | ✗ *(by design)* | [`Flow(SciML)`](sciml.md) |

**✓** a scalar or length-1 `Vector`/`SVector` state (or costate) collapses to a scalar, in
both the point and trajectory call styles. **✗** the state keeps whatever container shape
it was given — deliberately, for `Flow(::ODEProblem)`.

The `Flow(fc, law)`/`Flow(ocp[, law])` rows use `Flows._dim_coerce` — a second,
dimension-int-driven implementation of the same rule, layered *outside* an inner
`VectorFieldSystem`-based flow (see [`CTFlows.Flows.ControlledFlow`](@ref)). Because `only` is
idempotent on an already-scalar value, this outer coercion is a safe no-op once the inner
flow has already collapsed the state — the two mechanisms compose without double-applying
anything.

---

## Demonstrated: the two constructors this issue fixed

### `Flow(::VectorField)`

```@example shape_compat
vf = Data.VectorField(x -> -x)
flow = Flows.Flow(vf; reltol=1e-8)
flow(0.0, [1.0], 1.0)   # a length-1 Vector x0 → a scalar xf, not [exp(-1)]
```

```@repl shape_compat
sol = flow((0.0, 1.0), [1.0]);
Trajectories.state(sol)(1.0)   # scalar too — the trajectory accessor is coerced the same way
```

### `Flow(::SciMLBase.AbstractODEFunction)`

```@example shape_compat
f = SciMLBase.ODEFunction{false}((u, p, t) -> -p .* u)
flow_f = Flows.Flow(f; reltol=1e-8)
flow_f(0.0, [1.0], 1.0; variable=1.0)   # same collapse — SciMLFunctionSystem shares the fix
```

## Contrasted: the constructor this issue deliberately excludes

```@example shape_compat
prob = SciMLBase.ODEProblem(f, [1.0], (0.0, 1.0), 1.0)
pflow = Flows.Flow(prob; reltol=1e-8)
pflow(0.0, [1.0], 1.0; variable=1.0)   # stays a length-1 Vector — no CTFlows dispatch, no coercion
```

The same `[1.0]` state produces a **scalar** through `Flow(::ODEFunction)` and a
**length-1 `Vector`** through `Flow(::ODEProblem)` — same numeric dynamics, deliberately
different shape, because only one of the two reaches the dispatch this convention lives
on.

---

## See also

- [1-D = scalar (Handbook)](https://github.com/control-toolbox/Handbook/blob/main/philosophy/dimension-and-shape.md) — the ecosystem-wide convention this page implements for `CTFlows.jl`.
- [Issue #357](https://github.com/control-toolbox/CTFlows.jl/issues/357) — the audit and fix this page documents.
- [Compatibility overview](overview.md) — the per-constructor feature matrix and the other flow types.
- [`Flow(VectorField)`](vector_field.md), [`Flow(HamiltonianVectorField)`](hamiltonian_vector_field.md), [`Flow(Hamiltonian)`](hamiltonian.md), [`Flow(SciML)`](sciml.md) — the per-constructor compatibility pages.
- [`CTFlows.Systems._coerce_state`](@ref) — the shared coercion mechanism.
