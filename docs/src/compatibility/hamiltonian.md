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

!!! note "Last probed: 2026-07-23"
    This page's table *shape* — which containers and axes are tested — reflects
    [`probe/cpu/probe_cpu.jl`](https://github.com/control-toolbox/CTFlows.jl/blob/main/probe/cpu/probe_cpu.jl)
    as of this date. Every ✓/✗ cell below is still re-executed on **every** documentation
    build regardless (see [Compatibility overview](overview.md)) — only the *scope* of
    what's tested can go stale, not the results shown.

```@setup h_compat
using CTFlows
using CTBase: Data
using CTFlows: Flows
using CTFlows: Trajectories
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5
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

### Legend

- **✓** — works; the result matches the analytic ``(x_f, p_f) = (p_0, -x_0)`` and is
  executed on this page.
- **✗** — raises an error; see the corresponding note.

!!! note "(a) Complex is not supported by the default backend"
    `AutoForwardDiff` cannot differentiate through a `Complex` input: constructing a dual
    number over `ComplexF64` raises `ArgumentError: Cannot create a dual over scalar type
    ComplexF64`. This is a `ForwardDiff.jl` limitation, not specific to CTFlows.

    If your Hamiltonian naturally involves complex state (e.g. from a Schrödinger-type
    equation), it can typically be rewritten as a real system by splitting the state into
    real/imaginary (or conjugate) components — this is not a limitation of CTFlows, just a
    modeling choice that avoids differentiating through `Complex` directly.

The table above is about the flow's *state/costate* input. A separate question — how to
**differentiate the flow itself** with respect to `(x0, p0)`, e.g. for a shooting method —
is covered next.

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

See note (a) above — for a system that is naturally complex, rewrite it as a real system
on the real/imaginary (or conjugate) components instead.

---

## Automatic differentiation: sensitivities of the flow

Since `Flow(Hamiltonian)` is itself `AutoForwardDiff`-backed internally, differentiating it
with respect to `(x0, p0)` — e.g. for a shooting method — means **nested** AD. Do this by
differentiating the **flow call**, never by constructing a `ForwardDiff.Dual` by hand and
passing it as `x0`/`p0`: a hand-built, untagged `Dual` collides with the flow's own internal
tag (`DualMismatchError`), and a hand-supplied custom tag does not fix it either — an
arbitrary marker type lacks `ForwardDiff.Tag`'s internal ordering machinery. Wrapping the
call in an outer `ForwardDiff.jacobian` / `ForwardDiff.gradient` sidesteps this entirely,
because `ForwardDiff` then generates its own properly ordered tag for the perturbation —
this is exactly how a `NonlinearSolve`-style shooting method differentiates a flow that is
itself `ForwardDiff`-backed.

This computes the exact Jacobian of ``(x_f, p_f)`` with respect to ``(x_0, p_0)`` — for the
linear harmonic oscillator it is the constant matrix ``\begin{pmatrix}0&1\\-1&0\end{pmatrix}``:

```@repl h_compat
shoot(z) = collect(hflow(0.0, z[1], z[2], pi/2))
ForwardDiff.jacobian(shoot, [1.0, 0.0])
```

The same closure-wrapping pattern works with `ForwardDiff.gradient` for a scalar shooting
residual. No internal backend change (e.g. switching to `AutoZygote`/`AutoMooncake` to
dodge the nested `Dual`) is needed for this to work.

---

## See also

- [Building a flow](../flows/building_a_flow.md) — the shortcut constructor and explicit pipeline.
- [Integrating](../flows/integrating.md) — call styles, variable parameters (incl. `variable_costate`), and integrator options.
- [GPU flows](../flows/gpu.md) — `method=:gpu`, the `AutoMooncake` default backend, ensembles.
- [Compatibility overview](overview.md) — the per-constructor feature matrix and the other flow types.
- [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Flows.HamiltonianFlow`](@ref) — the flow types.
- [`CTBase.Data.Hamiltonian`](@extref CTBase.Data.Hamiltonian) — the data wrapper.
- [Shape contract](shape_contract.md) — the cross-constructor "1-D = scalar" reference: `Flow(Hamiltonian)` is 1-D = scalar end to end, via the same coercion machinery as `Flow(HamiltonianVectorField)` ([#357](https://github.com/control-toolbox/CTFlows.jl/issues/357)).
