# `Flow(VectorField)` compatibility

```@meta
CurrentModule = CTFlows
```

This page is a **living compatibility reference** for the state flow built from a
[`Data.VectorField`](@extref CTBase.Data.VectorField): which state types and call styles
it accepts, each shown with a minimal, executable example. Every ✓ / ⚠ in the table below
is demonstrated by a code block on this page and is re-run on every documentation build,
so the page cannot drift from the code.

Scope: **CPU** only. The table is generated from [`probe/cpu/probe_cpu.jl`](https://github.com/control-toolbox/CTFlows.jl/blob/main/probe/cpu/probe_cpu.jl)
(run it locally with `julia --project=probe/cpu probe/cpu/probe_cpu.jl`). GPU
compatibility is a separate effort — see [`probe/gpu`](https://github.com/control-toolbox/CTFlows.jl/tree/main/probe/gpu).

All examples integrate the scalar exponential decay ``\dot{x} = -x`` (autonomous, fixed)
with the default SciML integrator (`OrdinaryDiffEqTsit5`). The analytic solution is
``x(t) = x_0\,e^{-t}``, so integrating from ``t_0 = 0`` to ``t_f = 1`` maps every initial
condition ``x_0`` to ``x_0\,e^{-1}``.

```@setup vf_compat
using CTFlows
using CTBase.Data
using CTFlows.Flows
using CTFlows.Trajectories
import OrdinaryDiffEqTsit5
using StaticArrays: SA, SVector, MVector, SMatrix, MMatrix
using ForwardDiff: ForwardDiff
```

Two flows are built once — one from an out-of-place vector field, one from an in-place one
— and reused by every example below, so each example isolates the one thing that varies:
the initial condition `x0`.

```@example vf_compat
vf   = Data.VectorField(x -> -x)   # out-of-place: x -> -x
flow = Flows.Flow(vf; reltol=1e-8)
```

```@example vf_compat
vf_ip   = Data.VectorField((du, x) -> (du .= -x); is_autonomous=true, is_variable=false)   # in-place
flow_ip = Flows.Flow(vf_ip; reltol=1e-8)
```

---

## Compatibility table

The two **call styles** are the point call `flow(t0, x0, tf)` → final state `xf`, and the
trajectory call `flow((t0, tf), x0)` → a [`Trajectories.VectorFieldTrajectory`](@ref).
The **OOP / IP** columns are the *vector-field kind* — an out-of-place `x -> -x` versus an
in-place `(du, x) -> (du .= -x)` — independent of the state container. (Which integration
path is taken is chosen automatically from the mutability of `x0`; see
[In-place vector fields](#In-place-vector-fields).)

| State type | OOP point | OOP traj | IP point | IP traj |
|---|:---:|:---:|:---:|:---:|
| Scalar `Real` | ✓ | ✓ | ✓ | ✓ |
| `Vector` `Real` | ✓ | ✓ | ✓ | ✓ |
| `MVector` `Real` | ✓ | ✓ | ✓ | ✓ |
| `SVector` `Real` | ✓ | ✓ | ⚠ | ⚠ |
| `Matrix` `Real` (batch) | ✓ | ✓ | ✓ | ✓ |
| `MMatrix` `Real` | ✓ | ✓ | ✓ | ✓ |
| `SMatrix` `Real` | ✓ | ✓ | ⚠ | ⚠ |
| Scalar `Complex` | ✓ | ✓ | ✓ | ✓ |
| `Vector` `Complex` | ✓ | ✓ | ✓ | ✓ |
| `MVector` `Complex` | ✓ | ✓ | ✓ | ✓ |
| `SVector` `Complex` | ✓ | ✓ | ⚠ | ⚠ |
| `Matrix` `Complex` | ✓ | ✓ | ✓ | ✓ |
| `SMatrix` `Complex` | ✓ | ✓ | ⚠ | ⚠ |
| `ForwardDiff.Dual` scalar | ✓ | ✓ | ✓ | ✓ |
| `ForwardDiff.Dual` `Vector` | ✓ | ✓ | ✓ | ✓ |
| `ForwardDiff.Dual` `MVector` | ✓ | ✓ | ✓ | ✓ |
| `ForwardDiff.Dual` `SVector` | ✓ | ✓ | ⚠ | ⚠ |

### Legend

- **✓** — works; the result matches ``x_0\,e^{-1}`` and is executed on this page.
- **⚠** — works, but emits a performance warning; see note (a).

Every state type is supported on CPU — there is no unsupported (✗) combination. Two
behaviours are worth calling out:

!!! warning "(a) In-place vector field + immutable initial condition"
    An **in-place** vector field with an **immutable** `x0` (`SVector`, `SMatrix`) emits a
    performance `@warn` and falls back to an out-of-place *finalize* RHS. The result is
    correct but the path is slower. Prefer an out-of-place vector field, or a mutable
    `MVector` / `MMatrix`, for static states.

!!! note "Scalar state: point vs trajectory shape"
    For a **scalar** initial condition the *point* call returns a scalar, while the
    *trajectory* call's state accessor returns a **length-1 vector** — state flows preserve
    the vector shape of the solution. Both are shown under [Real states](#Real-states).

---

## Real states

### Scalar

The point call returns a scalar:

```@example vf_compat
flow(0.0, 1.0, 1.0)   # ≈ exp(-1)
```

The trajectory call returns a `VectorFieldTrajectory`; its state accessor is a length-1
vector at each time:

```@example vf_compat
sol = flow((0.0, 1.0), 1.0)
Trajectories.state(sol)(1.0)   # ≈ [exp(-1)]
```

### Vector

```@example vf_compat
flow(0.0, [1.0, 2.0], 1.0)
```

The trajectory's state accessor interpolates at any time in the span:

```@example vf_compat
sol = flow((0.0, 1.0), [1.0, 2.0])
Trajectories.state(sol)(0.5)
```

### `MVector` and `SVector`

Mutable and immutable static vectors both integrate out-of-place:

```@example vf_compat
flow(0.0, MVector{2}(1.0, 2.0), 1.0)
```

```@example vf_compat
flow(0.0, SA[1.0, 2.0], 1.0)
```

### Matrix (batch)

A matrix state integrates every column as an independent trajectory of ``\dot{x} = -x``:

```@example vf_compat
flow(0.0, [1.0 2.0; 3.0 4.0], 1.0)
```

```@example vf_compat
flow(0.0, MMatrix{2,2}(1.0, 3.0, 2.0, 4.0), 1.0)   # mutable
```

```@example vf_compat
flow(0.0, SMatrix{2,2}(1.0, 3.0, 2.0, 4.0), 1.0)   # immutable
```

---

## Complex states

Complex initial conditions work with the same real vector field — the scalar case:

```@example vf_compat
flow(0.0, 1.0 + 2.0im, 1.0)   # ≈ (1 + 2im) * exp(-1)
```

vectors:

```@example vf_compat
flow(0.0, [1.0 + 2.0im, 3.0 + 4.0im], 1.0)
```

and matrices:

```@example vf_compat
flow(0.0, [1.0+2.0im 5.0+6.0im; 3.0+4.0im 7.0+8.0im], 1.0)
```

---

## Automatic differentiation (`ForwardDiff.Dual`)

A `ForwardDiff.Dual` initial condition propagates a sensitivity through the integration —
the basis for differentiating a flow with respect to its initial state:

```@example vf_compat
x0 = ForwardDiff.Dual(1.0, 1.0)   # value 1.0, seed 1.0
xf = flow(0.0, x0, 1.0)
(ForwardDiff.value(xf), ForwardDiff.partials(xf, 1))   # ≈ (exp(-1), exp(-1))
```

The value tracks ``x_0\,e^{-1}`` and the dual part tracks ``\partial x_f / \partial x_0 =
e^{-1}``. Vector duals work the same way:

```@example vf_compat
x0 = [ForwardDiff.Dual(1.0, 1.0), ForwardDiff.Dual(2.0, 0.0)]
flow(0.0, x0, 1.0)
```

!!! note "Grid invariance"
    The SciML integrator's `internalnorm` uses a `real_norm` that ignores dual parts, so
    the integration grid is identical whether the initial condition is a `Real` or a
    `Dual`. See `test/suite/extensions/test_forwarddiff_extension.jl`.

---

## In-place vector fields

An in-place vector field `(du, x) -> (du .= -x)` produces the same results. The flow picks
the integration path from the **mutability** of `x0`: a mutable container (`Vector`,
`MVector`, `Matrix`, `MMatrix`) is integrated truly in place, with no allocation per step:

```@example vf_compat
flow_ip(0.0, [1.0, 2.0], 1.0)
```

```@example vf_compat
flow_ip(0.0, MVector{2}(1.0, 2.0), 1.0)
```

A **scalar** initial condition is also accepted: it is promoted to a length-1 vector before
the mutability dispatch, so the in-place path applies.

```@example vf_compat
flow_ip(0.0, 1.0, 1.0)   # scalar promoted internally
```

### Immutable initial conditions (`SVector` / `SMatrix`)

An **immutable** static array cannot be written in place, so an in-place vector field falls
back to an out-of-place *finalize* RHS and emits a performance warning (note (a)). The
result is still correct:

```@repl vf_compat
flow_ip(0.0, SA[1.0, 2.0], 1.0)   # warns, then returns the correct value
```

For static states, prefer the out-of-place vector field (`flow`) shown above, or use a
mutable `MVector` / `MMatrix`.

---

## See also

- [Building a flow](../flows/building_a_flow.md) — the shortcut constructor and explicit pipeline.
- [Integrating](../flows/integrating.md) — call styles, variable parameters, and integrator options.
- [Compatibility overview](overview.md) — the per-constructor feature matrix and the other flow types.
- [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Flows.StateFlow`](@ref) — the flow types.
- [`CTBase.Data.VectorField`](@extref CTBase.Data.VectorField) — the data wrapper.
