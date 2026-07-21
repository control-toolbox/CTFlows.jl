# `Flow(VectorField)` compatibility

```@meta
CurrentModule = CTFlows
```

This page lists the state types and call styles supported by
[`Flows.Flow`](@ref) when built from a [`Data.VectorField`](@extref CTBase.Data.VectorField).
Each row of the table is backed by a minimal, executable example.

All examples use the exponential decay ``\dot{x} = -x`` (autonomous, fixed)
and the default SciML integrator (`OrdinaryDiffEqTsit5`).

```@setup vf_compat
using CTFlows
using CTBase.Data
using CTFlows.Flows
using CTFlows.Trajectories
import OrdinaryDiffEqTsit5
using StaticArrays: SA, MVector, SVector
using ForwardDiff: ForwardDiff
```

---

## Compatibility table

| State type | OOP (pt / traj) | IP (pt / traj) | Notes |
|---|---|---|---|
| Scalar `Real` | ✓ / — | ✗ (a) | |
| Vector `Real` | ✓ / ✓ | ✓ / ✓ | |
| `SVector` | ✓ / ✓ | ⚠ / — | (b) |
| `MVector` | ✓ / ✓ | ✓ / ✓ | |
| Matrix (batch) | ✓ / ✓ | ✓ / ✓ | |
| Scalar `Complex` | ✓ / — | ✗ (a) | |
| Vector `Complex` | ✓ / — | ✓ / — | |
| `SVector` `Complex` | ✓ / — | ⚠ / — | (b) |
| Matrix `Complex` | ✓ / — | ✓ / — | |
| `ForwardDiff.Dual` scalar | ✓ / — | ✗ (a) | Grid invariance |
| `ForwardDiff.Dual` vector | ✓ / — | ✓ / — | |

### Legend

- **pt** — point call `flow(t0, x0, tf)` → returns `xf`
- **traj** — trajectory call `flow((t0, tf), x0)` → returns trajectory
- **✓** — tested end-to-end with SciML integrator
- **—** — not tested (may work, no regression test)
- **⚠** — works with a warning
- **✗** — not supported
- **(a)** — IP VF requires a mutable container; scalar or immutable
  `x0` is rejected (`ArgumentError`)
- **(b)** — IP VF + `SVector` (immutable) warns and falls back to
  `rhs_oop_finalize`

---

## Scalar `Real`

```@example vf_compat
vf = Data.VectorField(x -> -x)
flow = Flows.Flow(vf; reltol=1e-8)
xf = flow(0.0, 1.0, 1.0)
```

The analytic solution is ``x(t) = x_0 e^{-t}``, so `xf ≈ exp(-1)`.

---

## Vector `Real`

### OOP

```@example vf_compat
vf = Data.VectorField(x -> -x)
flow = Flows.Flow(vf; reltol=1e-8)
xf = flow(0.0, [1.0, 2.0], 1.0)
```

```@example vf_compat
sol = flow((0.0, 1.0), [1.0, 2.0])
Trajectories.state(sol)(0.5)
```

### IP

```@example vf_compat
vf_ip = Data.VectorField(
    (du, x) -> (du .= -x); is_autonomous=true, is_variable=false,
)
flow_ip = Flows.Flow(vf_ip; reltol=1e-8)
xf_ip = flow_ip(0.0, [1.0, 2.0], 1.0)
```

---

## `SVector`

### OOP

```@example vf_compat
vf = Data.VectorField(x -> -x)
flow = Flows.Flow(vf; reltol=1e-8)
xf = flow(0.0, SA[1.0, 2.0], 1.0)
```

```@example vf_compat
sol = flow((0.0, 1.0), SA[1.0, 2.0])
Trajectories.state(sol)(0.5)
```

### IP

```@example vf_compat
vf_ip = Data.VectorField(
    (du, x) -> (du .= -x); is_autonomous=true, is_variable=false,
)
flow_ip = Flows.Flow(vf_ip; reltol=1e-8)
xf_ip = flow_ip(0.0, SA[1.0, 2.0], 1.0)
```

!!! warning "Note (b)"
    An in-place vector field combined with an immutable `SVector` initial
    condition triggers a warning and falls back to the `rhs_oop_finalize`
    closure. The result is correct but the path is less efficient.

---

## `MVector`

### OOP

```@example vf_compat
vf = Data.VectorField(x -> -x)
flow = Flows.Flow(vf; reltol=1e-8)
xf = flow(0.0, MVector{2}(1.0, 2.0), 1.0)
```

### IP

```@example vf_compat
vf_ip = Data.VectorField(
    (du, x) -> (du .= -x); is_autonomous=true, is_variable=false,
)
flow_ip = Flows.Flow(vf_ip; reltol=1e-8)
xf_ip = flow_ip(0.0, MVector{2}(1.0, 2.0), 1.0)
```

---

## Matrix (batch)

### OOP

```@example vf_compat
vf = Data.VectorField(x -> -x)
flow = Flows.Flow(vf; reltol=1e-8)
X0 = [1.0 2.0; 3.0 4.0]
Xf = flow(0.0, X0, 1.0)
```

```@example vf_compat
sol = flow((0.0, 1.0), X0)
Trajectories.state(sol)(0.5)
```

### IP

```@example vf_compat
vf_ip = Data.VectorField(
    (du, x) -> (du .= -x); is_autonomous=true, is_variable=false,
)
flow_ip = Flows.Flow(vf_ip; reltol=1e-8)
Xf_ip = flow_ip(0.0, [1.0 2.0; 3.0 4.0], 1.0)
```

---

## Scalar `Complex`

```@example vf_compat
vf = Data.VectorField(x -> -x)
flow = Flows.Flow(vf; reltol=1e-8)
xf = flow(0.0, 1.0 + 2.0im, 1.0)
```

The analytic solution is ``x(t) = x_0 e^{-t}``, so
`xf ≈ (1+2i) * exp(-1)`.

!!! note "Note (a)"
    In-place vector fields cannot operate on a scalar initial condition.
    Use an out-of-place vector field for scalar states.

---

## Vector `Complex`

### OOP

```@example vf_compat
vf = Data.VectorField(x -> -x)
flow = Flows.Flow(vf; reltol=1e-8)
xf = flow(0.0, [1.0+2.0im, 3.0+4.0im], 1.0)
```

### IP

```@example vf_compat
vf_ip = Data.VectorField(
    (du, x) -> (du .= -x); is_autonomous=true, is_variable=false,
)
flow_ip = Flows.Flow(vf_ip; reltol=1e-8)
xf_ip = flow_ip(
    0.0, [1.0+2.0im, 3.0+4.0im], 1.0,
)
```

---

## `SVector` `Complex`

### OOP

```@example vf_compat
vf = Data.VectorField(x -> -x)
flow = Flows.Flow(vf; reltol=1e-8)
xf = flow(0.0, SA[1.0+2.0im, 3.0+4.0im], 1.0)
```

### IP

```@example vf_compat
vf_ip = Data.VectorField(
    (du, x) -> (du .= -x); is_autonomous=true, is_variable=false,
)
flow_ip = Flows.Flow(vf_ip; reltol=1e-8)
xf_ip = flow_ip(0.0, SA[1.0+2.0im, 3.0+4.0im], 1.0)
```

!!! warning "Note (b)"
    Same behaviour as the real `SVector` case: the in-place vector field
    warns and falls back to `rhs_oop_finalize`.

---

## Matrix `Complex`

### OOP

```@example vf_compat
vf = Data.VectorField(x -> -x)
flow = Flows.Flow(vf; reltol=1e-8)
X0 = [1.0+2.0im 5.0+6.0im; 3.0+4.0im 7.0+8.0im]
Xf = flow(0.0, X0, 1.0)
```

### IP

```@example vf_compat
vf_ip = Data.VectorField(
    (du, x) -> (du .= -x); is_autonomous=true, is_variable=false,
)
flow_ip = Flows.Flow(vf_ip; reltol=1e-8)
Xf_ip = flow_ip(0.0, X0, 1.0)
```

---

## `ForwardDiff.Dual` scalar

```@example vf_compat
vf = Data.VectorField(x -> -x)
flow = Flows.Flow(vf; reltol=1e-8)
x0 = ForwardDiff.Dual(1.0, 1.0)
xf = flow(0.0, x0, 1.0)
```

`ForwardDiff.value(xf) ≈ exp(-1)`. The dual part propagates the
sensitivity of ``x_f`` with respect to ``x_0``.

!!! note "Grid invariance"
    The SciML integrator's `internalnorm` uses a `real_norm` that ignores
    dual parts, so the integration grid is identical whether the initial
    condition is a `Real` or a `Dual`. See
    `test/suite/extensions/test_forwarddiff_extension.jl`.

---

## `ForwardDiff.Dual` vector

### OOP

```@example vf_compat
vf = Data.VectorField(x -> -x)
flow = Flows.Flow(vf; reltol=1e-8)
x0 = [ForwardDiff.Dual(1.0, 1.0), ForwardDiff.Dual(2.0, 0.0)]
xf = flow(0.0, x0, 1.0)
```

### IP

```@example vf_compat
vf_ip = Data.VectorField(
    (du, x) -> (du .= -x); is_autonomous=true, is_variable=false,
)
flow_ip = Flows.Flow(vf_ip; reltol=1e-8)
x0 = [ForwardDiff.Dual(1.0, 1.0), ForwardDiff.Dual(2.0, 0.0)]
xf_ip = flow_ip(0.0, x0, 1.0)
```

---

## See also

- [Building a flow](building_a_flow.md) — the shortcut constructor and
  explicit pipeline.
- [Integrating](integrating.md) — call styles, variable parameters, and
  integrator options.
- [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Flows.StateFlow`](@ref) —
  flow types.
- [`CTBase.Data.VectorField`](@extref CTBase.Data.VectorField) — the data wrapper.
