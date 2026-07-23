# `Flow(fc, law)` compatibility

```@meta
CurrentModule = CTFlows
```

This page is a **living compatibility reference** for `Flow(fc, law)`, built directly from
a [`Data.ControlledVectorField`](@extref CTBase.Data.ControlledVectorField)
``fc(t,x,u,v)`` and a control law — **no optimal control problem involved**. Every ✓ / ✗
in the table below is demonstrated by a code block re-run on every documentation build.

Scope: **CPU**, default AD backend. The table is generated from
[`probe/cpu/probe_cpu.jl`](https://github.com/control-toolbox/CTFlows.jl/blob/main/probe/cpu/probe_cpu.jl).
GPU compatibility is a separate effort — see [`probe/gpu`](https://github.com/control-toolbox/CTFlows.jl/tree/main/probe/gpu).

As documented in [Control laws](../flows/control_laws.md), only an
[`OpenLoop`](@extref CTBase.Data.OpenLoop) or [`ClosedLoop`](@extref CTBase.Data.ClosedLoop)
law is accepted here — `DynClosedLoop` is rejected, since it needs the costate `p`, which a
state flow does not have. The control is eliminated via
[`Data.ComposedVectorField`](@extref CTBase.Data.ComposedVectorField)
``g(t,x,v) = fc(t,x,u(...),v)``, integrated as a plain state flow — **no AD anywhere**, and,
unlike [`Flow(ocp, law)`](ocp_control_laws.md), **no OCP-derived fixed-size buffer**:
`Data.ControlledVectorField` has no in-place variant at all, so `g` is always
out-of-place, and `Systems.build_system(g)` builds exactly the same kind of
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

!!! note "Last probed: 2026-07-23"
    This page's table *shape* — which containers and axes are tested — reflects
    [`probe/cpu/probe_cpu.jl`](https://github.com/control-toolbox/CTFlows.jl/blob/main/probe/cpu/probe_cpu.jl)
    as of this date. Every ✓/✗ cell below is still re-executed on **every** documentation
    build regardless (see [Compatibility overview](overview.md)) — only the *scope* of
    what's tested can go stale, not the results shown.

```@setup fc_compat
using CTFlows
using CTBase.Data
using CTFlows.Flows
using CTFlows.Trajectories
import OrdinaryDiffEqTsit5
using StaticArrays: SA, SVector, MVector, SMatrix, MMatrix
using ForwardDiff: ForwardDiff
```

```@example fc_compat
fc = Data.ControlledVectorField((x, u) -> u .- x)

law_cl = Data.ClosedLoop(x -> -x)
law_ol = Data.OpenLoop(() -> 1.0)

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

**Fully green, measured on `ClosedLoop` — no unsupported combination, unlike
[`Flow(ocp, law)`'s `OpenLoop`/`ClosedLoop` table](ocp_control_laws.md#OpenLoop-ClosedLoop-—-state-flow,-no-internal-AD)**,
whose `SVector`/`Matrix`/trajectory-`Dual` restrictions come entirely from the OCP-derived
fixed-size buffer and objective computation that don't exist on this path. `OpenLoop` shares
the same mechanics (only the control-law arity differs — `u(t,v)` vs `u(t,x,v)`) and is
spot-checked below rather than re-measured cell by cell.

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
(ForwardDiff.value(xf), ForwardDiff.partials(xf, 1))   # ≈ (exp(-2), exp(-2)) — no AD collision
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
try
    Flows.Flow(fc, Data.DynClosedLoop((x, p) -> p); reltol=1e-8)
catch e
    showerror(stdout, e)
end
```

---

## See also

- [Control laws](../flows/control_laws.md) — the guide page this reference expands on
  (`OpenLoop`, `ClosedLoop`, `Flow(fc, law)` vs `Flow(ocp, law)`).
- [`Flow(VectorField)` compatibility](vector_field.md) — the exhaustive state-container
  gallery this page's mechanics inherit (out-of-place, no AD).
- [`Flow(h̃, law)` compatibility](pseudo_hamiltonian.md) — the pseudo-Hamiltonian
  counterpart (`DynClosedLoop` only, AD-backed).
- [`Flow(ocp, law)` compatibility](ocp_control_laws.md) — the OCP-based counterpart, whose
  `Matrix`/`SVector` restrictions (fixed-size buffer,
  [#358](https://github.com/control-toolbox/CTFlows.jl/issues/358)) do **not** apply here.
- [Compatibility overview](overview.md) — the per-constructor feature matrix and the other flow types.
- [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Flows.ControlledFlow`](@ref) — the flow types.
- [`CTBase.Data.ControlledVectorField`](@extref CTBase.Data.ControlledVectorField), [`CTBase.Data.OpenLoop`](@extref CTBase.Data.OpenLoop), [`CTBase.Data.ClosedLoop`](@extref CTBase.Data.ClosedLoop) — the data wrappers.
