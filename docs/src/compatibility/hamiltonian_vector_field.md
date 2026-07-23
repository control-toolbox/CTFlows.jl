# `Flow(HamiltonianVectorField)` compatibility

```@meta
CurrentModule = CTFlows
```

This page is a **living compatibility reference** for the Hamiltonian flow built from a
[`Data.HamiltonianVectorField`](@extref CTBase.Data.HamiltonianVectorField): which
state/costate types and call styles it accepts, each shown with a minimal, executable
example. Every ✓ / ⚠ in the table below is demonstrated by a code block on this page and
is re-run on every documentation build, so the page cannot drift from the code.

Scope: **CPU** only. The table is generated from [`probe/cpu/probe_cpu.jl`](https://github.com/control-toolbox/CTFlows.jl/blob/main/probe/cpu/probe_cpu.jl)
(run it locally with `julia --project=probe/cpu probe/cpu/probe_cpu.jl`). GPU
compatibility is a separate effort — see [`probe/gpu`](https://github.com/control-toolbox/CTFlows.jl/tree/main/probe/gpu).

All examples integrate the harmonic oscillator ``\dot{x} = p,\ \dot{p} = -x`` (autonomous,
fixed) with the default SciML integrator (`OrdinaryDiffEqTsit5`). The analytic solution is
``x(t) = x_0\cos t + p_0\sin t``, ``p(t) = -x_0\sin t + p_0\cos t``, so integrating from
``t_0 = 0`` to ``t_f = \pi/2`` maps every initial condition ``(x_0, p_0)`` to
``(x_f, p_f) = (p_0, -x_0)``.

!!! note "Last probed: 2026-07-23"
    This page's table *shape* — which containers and axes are tested — reflects
    [`probe/cpu/probe_cpu.jl`](https://github.com/control-toolbox/CTFlows.jl/blob/main/probe/cpu/probe_cpu.jl)
    as of this date. Every ✓/⚠ cell below is still re-executed on **every** documentation
    build regardless (see [Compatibility overview](overview.md)) — only the *scope* of
    what's tested can go stale, not the results shown.

```@setup hvf_compat
using CTFlows
using CTBase.Data
using CTFlows.Flows
using CTFlows.Trajectories
import OrdinaryDiffEqTsit5
using StaticArrays: SA, SVector, MVector, SMatrix, MMatrix
using ForwardDiff: ForwardDiff
```

Two flows are built once — one from an out-of-place Hamiltonian vector field, one from an
in-place one — and reused by every example below, so each example isolates the one thing
that varies: the initial condition `(x0, p0)`.

```@example hvf_compat
hvf   = Data.HamiltonianVectorField((x, p) -> (p, -x))   # out-of-place: (x,p) -> (p,-x)
hflow = Flows.Flow(hvf; reltol=1e-8)
```

```@example hvf_compat
hvf_ip   = Data.HamiltonianVectorField(
    (dx, dp, x, p) -> (dx .= p; dp .= -x); is_autonomous=true, is_variable=false,
)   # in-place
hflow_ip = Flows.Flow(hvf_ip; reltol=1e-8)
```

---

## Compatibility table

The two **call styles** are the point call `hflow(t0, x0, p0, tf)` → final `(xf, pf)`, and
the trajectory call `hflow((t0, tf), x0, p0)` →
[`Trajectories.HamiltonianVectorFieldTrajectory`](@ref). The **OOP / IP** columns are the
*Hamiltonian-vector-field kind* — an out-of-place `(x, p) -> (p, -x)` versus an in-place
`(dx, dp, x, p) -> (dx .= p; dp .= -x)` — independent of the state/costate container.
(Which integration path is taken is chosen automatically from the mutability of
`vcat(x0, p0)`; see [In-place Hamiltonian vector fields](#In-place-Hamiltonian-vector-fields).)

| State/costate type | OOP point | OOP traj | IP point | IP traj |
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

- **✓** — works; the result matches the analytic ``(x_f, p_f) = (p_0, -x_0)`` and is
  executed on this page.
- **⚠** — works, but emits a performance warning; see note (a).

Every state/costate type is supported on CPU — there is no unsupported (✗) combination.

!!! warning "(a) In-place Hamiltonian vector field + immutable initial condition"
    An **in-place** Hamiltonian vector field with an **immutable** `(x0, p0)` (`SVector`,
    `SMatrix`) emits a performance `@warn` and falls back to an out-of-place *finalize*
    RHS. The result is correct but the path is slower. Prefer an out-of-place Hamiltonian
    vector field, or mutable `MVector` / `MMatrix`, for static states.

!!! note "1-D = scalar, end to end"
    Unlike [`Flow(VectorField)`](vector_field.md#Scalar-state:-point-vs-trajectory-shape),
    a **scalar** `(x0, p0)` stays a scalar in *both* call styles: the point call returns a
    scalar `(xf, pf)` pair, and the trajectory accessors `state(sol)(t)` /
    `costate(sol)(t)` also return scalars — not length-1 vectors. This is the
    ecosystem's ["1-D = scalar"](https://github.com/control-toolbox/Handbook/blob/main/philosophy/dimension-and-shape.md)
    convention, already fully implemented here via the `HamiltonianVectorFieldSystem`
    coercion machinery. See [#357](https://github.com/control-toolbox/CTFlows.jl/issues/357)
    for bringing `Flow(VectorField)` in line with this.

---

## Real states

### Scalar

Both call styles return scalars:

```@repl hvf_compat
hflow(0.0, 1.0, 0.0, pi/2)   # (xf, pf) ≈ (0.0, -1.0)
```

```@repl hvf_compat
sol = hflow((0.0, pi/2), 1.0, 0.0);
(Trajectories.state(sol)(pi/2), Trajectories.costate(sol)(pi/2))   # ≈ (0.0, -1.0), both scalars
```

### Vector

```@repl hvf_compat
hflow(0.0, [1.0, 0.0], [0.0, 1.0], pi/2)
```

The trajectory's state/costate accessors interpolate at any time in the span:

```@repl hvf_compat
sol = hflow((0.0, pi/2), [1.0, 0.0], [0.0, 1.0]);
(Trajectories.state(sol)(pi/4), Trajectories.costate(sol)(pi/4))
```

### `MVector` and `SVector`

Mutable and immutable static vectors both integrate out-of-place:

```@repl hvf_compat
hflow(0.0, MVector{2}(1.0, 0.0), MVector{2}(0.0, 1.0), pi/2)
hflow(0.0, SA[1.0, 0.0], SA[0.0, 1.0], pi/2)
```

### Matrix (batch)

A matrix state/costate integrates every column as an independent trajectory of the
harmonic oscillator:

```@repl hvf_compat
hflow(0.0, [1.0 2.0; 3.0 4.0], [0.0 0.0; 1.0 1.0], pi/2)
hflow(0.0, MMatrix{2,2}(1.0, 3.0, 2.0, 4.0), MMatrix{2,2}(0.0, 1.0, 0.0, 1.0), pi/2)   # mutable
hflow(0.0, SMatrix{2,2}(1.0, 3.0, 2.0, 4.0), SMatrix{2,2}(0.0, 1.0, 0.0, 1.0), pi/2)   # immutable
```

---

## Complex states

Complex initial conditions work with the same real Hamiltonian vector field — the scalar
case:

```@repl hvf_compat
hflow(0.0, 1.0 + 2.0im, 0.0 + 0.0im, pi/2)   # ≈ (0+0im, -1-2im)
```

vectors:

```@repl hvf_compat
hflow(0.0, [1.0 + 2.0im, 0.0 + 0.0im], [0.0 + 0.0im, 1.0 + 1.0im], pi/2)
```

and matrices:

```@repl hvf_compat
hflow(0.0, [1.0+2.0im 5.0+6.0im; 3.0+4.0im 7.0+8.0im], [0.0+0.0im 1.0+1.0im; 2.0+2.0im 3.0+3.0im], pi/2)
```

---

## Automatic differentiation (`ForwardDiff.Dual`)

A `ForwardDiff.Dual` initial condition propagates a sensitivity through the integration —
the basis for differentiating a flow with respect to its initial state/costate:

```@repl hvf_compat
x0 = ForwardDiff.Dual(1.0, 1.0)    # value 1.0, seed 1.0
p0 = ForwardDiff.Dual(0.0, 0.0)
xf, pf = hflow(0.0, x0, p0, pi/2)
(ForwardDiff.value(xf), ForwardDiff.value(pf))   # ≈ (0.0, -1.0)
```

Vector duals work the same way:

```@repl hvf_compat
x0 = [ForwardDiff.Dual(1.0, 1.0), ForwardDiff.Dual(0.0, 0.0)]
p0 = [ForwardDiff.Dual(0.0, 0.0), ForwardDiff.Dual(1.0, 0.0)]
hflow(0.0, x0, p0, pi/2)
```

!!! note "Grid invariance"
    As for `Flow(VectorField)`, the SciML integrator's `internalnorm` ignores dual parts,
    so the integration grid is identical whether the initial condition is a `Real` or a
    `Dual`.

### Recommended: differentiate the flow, not one hand-seeded `Dual`

As for `Flow(VectorField)`, wrap the **flow call** in an outer `ForwardDiff.jacobian` /
`ForwardDiff.gradient` to get every partial in one call, rather than hand-seeding a `Dual`
per component. `Flow(HamiltonianVectorField)` has no internal AD backend, so there is no
nesting concern (unlike [`Flow(Hamiltonian)`](hamiltonian.md)):

```@repl hvf_compat
shoot(z) = collect(hflow(0.0, z[1], z[2], pi/2))
ForwardDiff.jacobian(shoot, [1.0, 0.0])   # ≈ [0 1; -1 0]
```

This is the same Jacobian of the same dynamics computed by
[`Flow(Hamiltonian)`](hamiltonian.md#Automatic-differentiation:-sensitivities-of-the-flow) —
a good cross-check that both constructors agree.

---

## In-place Hamiltonian vector fields

An in-place Hamiltonian vector field `(dx, dp, x, p) -> (dx .= p; dp .= -x)` produces the
same results. The state and costate are concatenated via `vcat(x0, p0)` into a single ODE
state; the flow picks the integration path from the **mutability** of that concatenation.
For a mutable container (`Vector`, `MVector`, `Matrix`, `MMatrix`) — and, notably, for a
**scalar** `(x0, p0)` too, since `vcat` of two numbers always produces a mutable `Vector`
— it is integrated truly in place:

```@repl hvf_compat
hflow_ip(0.0, 1.0, 0.0, pi/2)                            # scalar: vcat(x0,p0) is mutable
hflow_ip(0.0, [1.0, 0.0], [0.0, 1.0], pi/2)
hflow_ip(0.0, MVector{2}(1.0, 0.0), MVector{2}(0.0, 1.0), pi/2)
```

### Immutable initial conditions (`SVector` / `SMatrix`)

An **immutable** static array cannot be written in place, so an in-place Hamiltonian
vector field falls back to an out-of-place *finalize* RHS and emits a performance warning
(note (a)). The result is still correct:

```@repl hvf_compat
hflow_ip(0.0, SA[1.0, 0.0], SA[0.0, 1.0], pi/2)   # warns, then returns the correct value
```

For static states, prefer the out-of-place Hamiltonian vector field (`hflow`) shown above,
or use mutable `MVector` / `MMatrix`.

---

## See also

- [Building a flow](../flows/building_a_flow.md) — the shortcut constructor and explicit pipeline.
- [Integrating](../flows/integrating.md) — call styles, variable parameters (incl. `variable_costate`), and integrator options.
- [Compatibility overview](overview.md) — the per-constructor feature matrix and the other flow types.
- [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Flows.HamiltonianFlow`](@ref) — the flow types.
- [`CTBase.Data.HamiltonianVectorField`](@extref CTBase.Data.HamiltonianVectorField) — the data wrapper.
- [#357](https://github.com/control-toolbox/CTFlows.jl/issues/357) — bringing `Flow(VectorField)`'s shape contract in line with this page's.
