# `Flow(Hamiltonian)` compatibility

```@meta
CurrentModule = CTFlows
```

This page is a **living compatibility reference** for the Hamiltonian flow built from a
**scalar** [`Data.Hamiltonian`](@extref CTBase.Data.Hamiltonian) function: which
state/costate types and call styles it accepts, each shown with a minimal, executable
example. Every ✓ / ⚠ / ✗ in the table below is demonstrated by a code block on this page
and is re-run on every documentation build, so the page cannot drift from the code.

Scope: **CPU**, default AD backend (`AutoForwardDiff`). The table is generated from
[`probe/cpu/probe_cpu.jl`](https://github.com/control-toolbox/CTFlows.jl/blob/main/probe/cpu/probe_cpu.jl)
(run it locally with `julia --project=probe/cpu probe/cpu/probe_cpu.jl`). GPU compatibility
(`method=:gpu`, default backend `AutoMooncake`) is a separate effort — see
[GPU flows](../flows/gpu.md) and [`probe/gpu`](https://github.com/control-toolbox/CTFlows.jl/tree/main/probe/gpu).

Unlike [`Flow(VectorField)`](vector_field.md) and
[`Flow(HamiltonianVectorField)`](hamiltonian_vector_field.md), a scalar `Hamiltonian` has
**no in-place variant** — there is no mutability trait on `Data.Hamiltonian` at all. The
flow computes ``\dot{x} = \partial_p H``, ``\dot{p} = -\partial_x H`` by **automatic
differentiation** instead of from a user-supplied vector field, so the axis that varies on
this page is not OOP/IP but the **input type accepted by the AD backend**.

All examples use the harmonic oscillator ``H(x,p) = \tfrac12\left(\lVert x\rVert^2 +
\lVert p\rVert^2\right)`` (autonomous, fixed) — the same dynamics as
[`Flow(HamiltonianVectorField)`](hamiltonian_vector_field.md), so the analytic solution is
identical: ``(x_f, p_f) = (p_0, -x_0)`` at ``t_f = \pi/2``.

```@setup h_compat
using CTFlows
using CTBase.Data
using CTFlows.Flows
using CTFlows.Trajectories
import OrdinaryDiffEqTsit5
using StaticArrays: SA, SVector, MVector, SMatrix, MMatrix
using ForwardDiff: ForwardDiff
```

The flow is built once — no `ad_backend` keyword needed, since `AutoForwardDiff` is
already the CPU default:

```@example h_compat
h     = Data.Hamiltonian((x, p) -> 0.5 * (sum(abs2, x) + sum(abs2, p)))
hflow = Flows.Flow(h; reltol=1e-8)
```

An explicit backend, or a GPU one, can be selected the same way:
`Flows.Flow(h; ad_backend=ADTypes.AutoForwardDiff())` — see [GPU flows](../flows/gpu.md)
for `method=:gpu` and `AutoMooncake`/`AutoZygote`.

---

## Compatibility table

The two **call styles** are the point call `hflow(t0, x0, p0, tf)` → final `(xf, pf)`, and
the trajectory call `hflow((t0, tf), x0, p0)` →
[`Trajectories.HamiltonianVectorFieldTrajectory`](@ref). There is no OOP/IP split.

| State/costate type | point | traj |
|---|:---:|:---:|
| Scalar `Real` | ✓ | ✓ |
| `Vector` `Real` | ✓ | ✓ |
| `MVector` `Real` | ✓ | ✓ |
| `SVector` `Real` | ✓ | ✓ |
| `Matrix` `Real` (batch) | ✓ | ✓ |
| `MMatrix` `Real` | ✓ | ✓ |
| `SMatrix` `Real` | ✓ | ✓ |
| `Complex` (any container) | ✗ (a) | ✗ (a) |
| `ForwardDiff.Dual`, hand-built | ✗ (b) | ✗ (b) |
| `ForwardDiff.Dual`, via outer `ForwardDiff.jacobian`/`gradient` | ✓ (c) | — |

### Legend

- **✓** — works; the result matches the analytic ``(x_f, p_f) = (p_0, -x_0)`` and is
  executed on this page.
- **✗** — raises an error; see the corresponding note.

!!! note "(a) Complex is not supported by the default backend"
    `AutoForwardDiff` cannot differentiate through a `Complex` input: constructing a dual
    number over `ComplexF64` raises `ArgumentError: Cannot create a dual over scalar type
    ComplexF64`. This is a `ForwardDiff.jl` limitation, not specific to CTFlows — a
    complex-capable AD backend would need to be selected via `ad_backend=` instead (not
    covered by this page).

!!! warning "(b)/(c) ForwardDiff.Dual as x0 — hand-built fails, the outer-AD pattern works"
    Passing a **hand-built** `ForwardDiff.Dual` (e.g. `ForwardDiff.Dual(1.0, 1.0)`,
    an *untagged* `Dual{Nothing,...}`) as `x0`/`p0` fails: the flow's own internal AD is
    also `AutoForwardDiff`, so this nests two Duals, and `ForwardDiff` refuses the
    combination — `DualMismatchError: Cannot determine ordering of Dual tags Nothing and
    ForwardDiff.Tag{...}`. A **hand-supplied custom tag** (`ForwardDiff.Dual{MyTag}(...)`)
    does **not** fix this either — it was tested and still raises the same error, because
    an arbitrary marker type lacks `ForwardDiff.Tag`'s internal ordering machinery.
    The pattern that *does* work — and is the correct way to differentiate a
    `Flow(Hamiltonian)` with respect to `(x0, p0)` — is to never construct a `Dual` by
    hand: wrap the **flow call** in an outer `ForwardDiff.jacobian` / `ForwardDiff.gradient`
    instead, shown below. This is exactly how a `NonlinearSolve`-style shooting method
    differentiates a flow that is itself `ForwardDiff`-backed.

---

## Real states

### Scalar

```@repl h_compat
hflow(0.0, 1.0, 0.0, pi/2)   # (xf, pf) ≈ (0.0, -1.0)
```

```@repl h_compat
sol = hflow((0.0, pi/2), 1.0, 0.0);
(Trajectories.state(sol)(pi/2), Trajectories.costate(sol)(pi/2))   # both scalars
```

### Vector

```@repl h_compat
hflow(0.0, [1.0, 0.0], [0.0, 1.0], pi/2)
```

### `MVector` and `SVector`

```@repl h_compat
hflow(0.0, MVector{2}(1.0, 0.0), MVector{2}(0.0, 1.0), pi/2)
hflow(0.0, SA[1.0, 0.0], SA[0.0, 1.0], pi/2)
```

### Matrix (batch)

`H` is separable and quadratic (`sum(abs2, x)`), so it reduces a matrix state/costate to a
scalar the same way it does a vector, and the induced dynamics are independent per column:

```@repl h_compat
hflow(0.0, [1.0 2.0; 3.0 4.0], [0.0 0.0; 1.0 1.0], pi/2)
hflow(0.0, MMatrix{2,2}(1.0, 3.0, 2.0, 4.0), MMatrix{2,2}(0.0, 1.0, 0.0, 1.0), pi/2)   # mutable
hflow(0.0, SMatrix{2,2}(1.0, 3.0, 2.0, 4.0), SMatrix{2,2}(0.0, 1.0, 0.0, 1.0), pi/2)   # immutable
```

---

## Complex states — not supported

```@repl h_compat
try
    hflow(0.0, 1.0 + 2.0im, 0.0 + 0.0im, pi/2)
catch e
    showerror(stdout, e)
end
```

See note (a) above — use a complex-capable `ad_backend` if this is needed.

---

## Automatic differentiation: sensitivities of the flow

### What does *not* work

```@repl h_compat
try
    x0 = ForwardDiff.Dual(1.0, 1.0)   # hand-built, untagged
    p0 = ForwardDiff.Dual(0.0, 0.0)
    hflow(0.0, x0, p0, pi/2)
catch e
    showerror(stdout, e)
end
```

### The recommended pattern

Differentiate the **flow call**, not a hand-built `Dual`. This computes the exact Jacobian
of ``(x_f, p_f)`` with respect to ``(x_0, p_0)`` — for the linear harmonic oscillator it is
the constant matrix ``\begin{pmatrix}0&1\\-1&0\end{pmatrix}``:

```@repl h_compat
shoot(z) = collect(hflow(0.0, z[1], z[2], pi/2))
ForwardDiff.jacobian(shoot, [1.0, 0.0])
```

The same closure-wrapping pattern works with `ForwardDiff.gradient` for a scalar shooting
residual, and is how a `NonlinearSolve`-based shooting method should differentiate a
`Flow(Hamiltonian)` — the outer `ForwardDiff` call generates a properly ordered tag, so no
internal backend change (e.g. switching to `AutoZygote`/`AutoMooncake` to dodge the nested
`Dual`) is needed for this to work.

---

## See also

- [Building a flow](../flows/building_a_flow.md) — the shortcut constructor and explicit pipeline.
- [Integrating](../flows/integrating.md) — call styles, variable parameters (incl. `variable_costate`), and integrator options.
- [GPU flows](../flows/gpu.md) — `method=:gpu`, the `AutoMooncake` default backend, ensembles.
- [Compatibility overview](overview.md) — the per-constructor feature matrix and the other flow types.
- [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Flows.HamiltonianFlow`](@ref) — the flow types.
- [`CTBase.Data.Hamiltonian`](@extref CTBase.Data.Hamiltonian) — the data wrapper.
- [#357](https://github.com/control-toolbox/CTFlows.jl/issues/357) — `Flow(Hamiltonian)` is already "1-D = scalar" end to end, via the same coercion machinery as `Flow(HamiltonianVectorField)`.
