# `Flow(h̃vf, law)` compatibility

```@meta
CurrentModule = CTFlows
```

This page is a **living compatibility reference** for `Flow(h̃vf, law)`, built from a
[`Data.PseudoHamiltonianVectorField`](@extref CTBase.Data.PseudoHamiltonianVectorField)
`h̃vf(t,x,p,u,v) = (ẋ,ṗ)` — the derivatives of a pseudo-Hamiltonian **already
differentiated by hand**, with an explicit control argument `u` — and a control law that
closes the loop. **No AD, no OCP involved.** Every ✓ / ⚠ in the table below is
demonstrated by a code block re-run on every documentation build.

Scope: **CPU** only. The table is generated from
[`probe/cpu/probe_cpu.jl`](https://github.com/control-toolbox/CTFlows.jl/blob/main/probe/cpu/probe_cpu.jl)
(run it locally with `julia --project=probe/cpu probe/cpu/probe_cpu.jl`). GPU
compatibility is a separate effort — see
[`probe/gpu`](https://github.com/control-toolbox/CTFlows.jl/tree/main/probe/gpu).

As documented in [Control laws](../flows/control_laws.md), only a
[`DynClosedLoop`](@extref CTBase.Data.DynClosedLoop) law is accepted here — `OpenLoop` and
`ClosedLoop` are rejected, since a pseudo-Hamiltonian vector field needs the costate `p`
that those laws do not provide.

`Flow(h̃vf, law)` is the **vector-field analogue** of
[`Flow(h̃, law)`](pseudo_hamiltonian.md): that constructor differentiates a scalar `H̃` by
AD (`:total`/`:partial`); this one takes the derivatives directly, so there is **no
`hamiltonian_type` option** — only one mode. Instead, the axis that matters here is the
same one as [`Flow(HamiltonianVectorField)`](hamiltonian_vector_field.md): whether `h̃vf`
is out-of-place or in-place.

Same reference dynamics as [`Flow(h̃, law)`'s page](pseudo_hamiltonian.md), pre-differentiated
by hand instead of via AD: ``\tilde H(x,p,u) = p\cdot u - \tfrac12\lVert u\rVert^2``, law
``u = p`` (the stationary point, ``\partial\tilde H/\partial u = p-u = 0``) gives
``H(x,p) = \tfrac12\lVert p\rVert^2``, hence

```math
\dot x = \partial_p H = p, \qquad \dot p = -\partial_x H = 0
\;\Longrightarrow\;
x_f = x_0 + p_0, \qquad p_f = p_0 \quad\text{at } t_f = 1,
```

so `h̃vf(x,p,u) = (\dot x, \dot p) = (u, 0)` is the already-differentiated vector field
supplied directly — no AD anywhere in this constructor.

!!! note "Last probed: 2026-07-24"
    This page's table *shape* — which containers and axes are tested — reflects
    [`probe/cpu/probe_cpu.jl`](https://github.com/control-toolbox/CTFlows.jl/blob/main/probe/cpu/probe_cpu.jl)
    as of this date. Every ✓/⚠ cell below is still re-executed on **every** documentation
    build regardless (see [Compatibility overview](overview.md)) — only the *scope* of
    what's tested can go stale, not the results shown.

```@setup phvf_compat
using CTFlows
using CTBase.Data
using CTFlows.Flows
using CTFlows.Trajectories
import OrdinaryDiffEqTsit5
using StaticArrays: SA, SVector, MVector, SMatrix, MMatrix
using ForwardDiff: ForwardDiff
```

Two flows are built once — one from an out-of-place `h̃vf`, one from an in-place one —
sharing the same `DynClosedLoop` law, and reused by every example below:

```@example phvf_compat
h̃vf    = Data.PseudoHamiltonianVectorField((x, p, u) -> (u, zero(p)))   # out-of-place
law    = Data.DynClosedLoop((x, p) -> p)
hflow  = Flows.Flow(h̃vf, law; reltol=1e-8)
```

```@example phvf_compat
h̃vf_ip = Data.PseudoHamiltonianVectorField(
    (dx, dp, x, p, u) -> (dx .= u; dp .= 0); is_inplace=true,
)   # in-place
hflow_ip = Flows.Flow(h̃vf_ip, law; reltol=1e-8)
```

---

## Compatibility table

The two **call styles** are the point call `hflow(t0, x0, p0, tf)` → final `(xf, pf)`, and
the trajectory call `hflow((t0, tf), x0, p0)` →
[`CTFlows.Trajectories.HamiltonianVectorFieldTrajectory`](@ref).
The **OOP / IP** columns are the *pseudo-Hamiltonian-vector-field kind* — independent of
the state/costate container, exactly as for
[`Flow(HamiltonianVectorField)`](hamiltonian_vector_field.md#Compatibility-table).

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

- **✓** — works; the result matches the analytic ``(x_f,p_f)=(x_0+p_0,p_0)`` and is
  executed on this page.
- **⚠** — works, but emits a performance warning; see note (a).

Every state/costate type is supported on CPU — there is no unsupported (✗) combination,
**including `Complex` and `ForwardDiff.Dual`**: since `Flow(h̃vf, law)` has no internal AD
backend (unlike [`Flow(h̃, law)`](pseudo_hamiltonian.md), which fails on `Complex` and a
hand-built `Dual`), this constructor's profile matches
[`Flow(HamiltonianVectorField)`](hamiltonian_vector_field.md) exactly — measured, not
assumed.

!!! warning "(a) In-place pseudo-Hamiltonian vector field + immutable initial condition"
    An **in-place** `h̃vf` with an **immutable** `(x0, p0)` (`SVector`, `SMatrix`) emits a
    performance `@warn` and falls back to an out-of-place *finalize* RHS. The result is
    correct but the path is slower — same fallback as
    [`Flow(HamiltonianVectorField)`](hamiltonian_vector_field.md#warning-a-in-place-hamiltonian-vector-field-immutable-initial-condition).
    Prefer an out-of-place `h̃vf`, or mutable `MVector` / `MMatrix`, for static states.

---

## Real states

```@repl phvf_compat
x0, p0 = 1.0, 0.5;
xf, pf = hflow(0.0, x0, p0, 1.0);
xf ≈ x0 + p0, pf ≈ p0
```

```@repl phvf_compat
hflow(0.0, SA[1.0, 2.0], SA[0.5, 0.3], 1.0)
```

```@repl phvf_compat
sol = hflow((0.0, 1.0), [1.0, 2.0], [0.5, 0.3]);
Trajectories.state(sol)(1.0), Trajectories.costate(sol)(1.0)
```

---

## In-place pseudo-Hamiltonian vector fields

An in-place `h̃vf` produces the same results for mutable containers:

```@repl phvf_compat
hflow_ip(0.0, [1.0, 2.0], [0.5, 0.3], 1.0)
hflow_ip(0.0, MVector{2}(1.0, 2.0), MVector{2}(0.5, 0.3), 1.0)
```

An **immutable** static array (`SVector`/`SMatrix`) falls back to an out-of-place
*finalize* RHS and warns (note (a)); the result is still correct:

```@repl phvf_compat
hflow_ip(0.0, SA[1.0, 2.0], SA[0.5, 0.3], 1.0)   # warns, then returns the correct value
```

---

## `OpenLoop`/`ClosedLoop` — rejected

A pseudo-Hamiltonian vector field ``\tilde h(t,x,p,u,v)`` depends on the costate ``p``,
which `OpenLoop`/`ClosedLoop` control laws do not provide:

```@repl phvf_compat
try
    Flows.Flow(h̃vf, Data.ClosedLoop(x -> -x); reltol=1e-8)
catch e
    showerror(stdout, e)
end
```

---

## See also

- [Control laws](../flows/control_laws.md) — the guide page this reference expands on
  (`DynClosedLoop`, `Flow(h̃vf, law)` vs `Flow(h̃, law)`).
- [`Flow(HamiltonianVectorField)` compatibility](hamiltonian_vector_field.md) — the no-AD
  sibling on the control-free side of the grid, and the shared in-place/immutable-`u0`
  warning.
- [`Flow(h̃, law)` compatibility](pseudo_hamiltonian.md) — the AD-based sibling (same
  dynamics, differentiated instead of supplied directly), whose `Complex`/`Dual`
  restrictions do **not** apply here.
- [Compatibility overview](overview.md) — the per-constructor feature matrix and the other flow types.
- [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Flows.HamiltonianFlow`](@ref) — the flow types.
- [`CTBase.Data.PseudoHamiltonianVectorField`](@extref CTBase.Data.PseudoHamiltonianVectorField),
  [`CTBase.Data.DynClosedLoop`](@extref CTBase.Data.DynClosedLoop) — the data wrappers.
