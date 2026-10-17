# `Flow(fc, law)` compatibility

```@meta
CurrentModule = CTFlows
```

Which state types and call styles `Flow(fc, law)` accepts, for a
[`Data.ControlledVectorField`](@extref CTBase.Data.ControlledVectorField) ``fc(t,x,u,v)``
and a control law, with **no optimal control problem**, on **CPU**. Every cell has an executed example; see [Compatibility](overview.md) for how the pages stay true.

As documented in [Control laws](../flows/control_laws.md), only an
[`OpenLoop`](@extref CTBase.Data.OpenLoop) or [`ClosedLoop`](@extref CTBase.Data.ClosedLoop)
law is accepted here — `DynClosedLoop` is rejected, since it needs the costate `p`, which a
state flow does not have. The control is eliminated via
[`Data.ComposedVectorField`](@extref CTBase.Data.ComposedVectorField)
``g(t,x,v) = fc(t,x,u(...),v)``, integrated as a plain state flow — **no AD anywhere**, and
no OCP-derived buffer to size: `Data.ControlledVectorField` has no in-place variant at all,
so `g` is always out-of-place, and `Systems.build_system(g)` builds exactly the same kind of
`VectorFieldSystem` as [`Flow(VectorField)`](vector_field.md)'s out-of-place path.

The dynamics used on this page are the same as
[`Control laws`](../flows/control_laws.md)/[`Flow(ocp, law)`](ocp_control_laws.md)'s
example, ``fc(x,u) = u - x``, with **both** feedback kinds:

```math
\text{ClosedLoop } u=-x: \quad \dot x = -2x \;\Rightarrow\; x_f = x_0\,e^{-2}
\qquad
\text{OpenLoop } u\equiv 1: \quad \dot x = 1-x \;\Rightarrow\; x_f = 1+(x_0-1)\,e^{-1}
```

at ``t_f = 1``.

```@setup fc_compat
using CTFlows
using CTBase: Data
using CTFlows: Flows
using CTFlows: Trajectories
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5
using StaticArrays: SA, SVector, MVector, SMatrix, MMatrix
using ForwardDiff: ForwardDiff
```

```@example fc_compat
fc = Data.ControlledVectorField((x, u) -> u .- x)

law_cl = Data.ClosedLoop(x -> -x)
law_ol = Data.OpenLoop(t -> 1.0)

flow_cl = Flows.Flow(fc, law_cl; reltol=1e-8)
flow_ol = Flows.Flow(fc, law_ol; reltol=1e-8)
```

---

## Compatibility table

| State type | point | traj |
|---|:---:|:---:|
| Scalar `Real` | ✓ | ✓ |
| `Vector`/`MVector`/`SVector` `Real` | ✓ | ✓ |
| `Matrix`/`MMatrix`/`SMatrix` `Real` (batch) | ✓ | ✓ |
| Scalar/`Vector`/`MVector`/`SVector`/`Matrix`/`SMatrix` `Complex` | ✓ | ✓ |
| `ForwardDiff.Dual` scalar/`Vector`/`MVector`/`SVector` | ✓ | ✓ |

**Fully green, measured on `ClosedLoop` — no unsupported combination**, matching
[`Flow(ocp, law)`'s `OpenLoop`/`ClosedLoop` table](ocp_control_laws.md#OpenLoop-ClosedLoop-—-state-flow,-no-internal-AD)
on every state-shape axis. The one difference is the trajectory-`Dual` case: that table's OCP objective computation is not
`Dual`-transparent, whereas `Flow(fc, law)` computes no objective at all, so it has no
counterpart restriction. `OpenLoop` shares the same mechanics as `ClosedLoop` here (only the
control-law arity differs — `u(t,v)` vs `u(t,x,v)`) and is spot-checked below rather than
re-measured cell by cell.

---

## Real, `Complex`, and `Dual` states — `ClosedLoop`

```@repl fc_compat
flow_cl(0.0, 1.0, 1.0)   # scalar, ≈ exp(-2)
```

```@repl fc_compat
flow_cl(0.0, SA[1.0, 2.0], 1.0)
sol = flow_cl((0.0, 1.0), [1.0, 2.0]);
Trajectories.state(sol)(1.0)
```

```@repl fc_compat
flow_cl(0.0, MMatrix{2,2}(1.0, 3.0, 2.0, 4.0), 1.0)   # mutable
flow_cl(0.0, SMatrix{2,2}(1.0, 3.0, 2.0, 4.0), 1.0)   # immutable
```

```@repl fc_compat
flow_cl(0.0, 1.0 + 2.0im, 1.0)
```

```@repl fc_compat
x0 = ForwardDiff.Dual(1.0, 1.0)
xf = flow_cl(0.0, x0, 1.0)
# ≈ (exp(-2), exp(-2)): no AD collision
(ForwardDiff.value(xf), ForwardDiff.partials(xf, 1))
```

Unlike [`Flow(h̃, law)`](pseudo_hamiltonian.md) or [`Flow(ocp, law)`'s `DynClosedLoop`
path](ocp_control_laws.md), there is **no internal AD** here, so a hand-built `Dual` never
collides with anything — it just propagates a sensitivity through the integration, exactly
like [`Flow(VectorField)`](vector_field.md#Automatic-differentiation-(ForwardDiff.Dual)).

---

## `OpenLoop`

```@repl fc_compat
flow_ol(0.0, 1.0, 1.0)   # ≈ 1 + (1.0 - 1) * exp(-1) = 1.0
flow_ol(0.0, 0.0, 1.0)   # ≈ 1 + (0.0 - 1) * exp(-1)
```

```@repl fc_compat
flow_ol(0.0, SA[1.0 + 2.0im, 0.0 + 0.0im], 1.0)
```

---

## `DynClosedLoop` — rejected

```@repl fc_compat
Flows.Flow(fc, Data.DynClosedLoop((x, p) -> p); reltol=1e-8)
```

---

## See also

- [Control laws](../flows/control_laws.md) — the guide page this reference expands on
  (`OpenLoop`, `ClosedLoop`, `Flow(fc, law)` vs `Flow(ocp, law)`).
- [`Flow(VectorField)` compatibility](vector_field.md) — the exhaustive state-container
  gallery this page's mechanics inherit (out-of-place, no AD).
- [`Flow(h̃, law)` compatibility](pseudo_hamiltonian.md) — the pseudo-Hamiltonian
  counterpart (`DynClosedLoop` only, AD-backed).
- [`Flow(ocp, law)` compatibility](ocp_control_laws.md) — the OCP-based counterpart.
- [Compatibility overview](overview.md) — the per-constructor feature matrix and the other flow types.
- [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Flows.ControlledFlow`](@ref) — the flow types.
- [`CTBase.Data.ControlledVectorField`](@extref CTBase.Data.ControlledVectorField), [`CTBase.Data.OpenLoop`](@extref CTBase.Data.OpenLoop), [`CTBase.Data.ClosedLoop`](@extref CTBase.Data.ClosedLoop) — the data wrappers.
