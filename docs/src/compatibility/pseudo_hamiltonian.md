# `Flow(h̃, law)` compatibility

```@meta
CurrentModule = CTFlows
```

This page is a **living compatibility reference** for `Flow(h̃, law)`, built directly from
a [`Data.PseudoHamiltonian`](@extref CTBase.Data.PseudoHamiltonian) ``\tilde H(t,x,p,u,v)``
and a control law — **no optimal control problem involved**. Every ✓ / ✗ in the table below
is demonstrated by a code block re-run on every documentation build.

Scope: **CPU**, default AD backend. The table is generated from
[`probe/cpu/probe_cpu.jl`](https://github.com/control-toolbox/CTFlows.jl/blob/main/probe/cpu/probe_cpu.jl).
GPU compatibility is a separate effort — see [`probe/gpu`](https://github.com/control-toolbox/CTFlows.jl/tree/main/probe/gpu).

As documented in [Control laws](../flows/control_laws.md), only a
[`DynClosedLoop`](@extref CTBase.Data.DynClosedLoop) law is accepted here — `OpenLoop` and
`ClosedLoop` are rejected, since a pseudo-Hamiltonian needs the costate `p` that those laws
do not provide. Unlike [`Flow(ocp, law)`](ocp_control_laws.md), there is **no OCP
involved**: [`Systems.PseudoHamiltonianSystem`](@ref)/`Data.ComposedHamiltonian` wrap the
user's `H̃` function **directly**, with no OCP-derived fixed-size buffer — so, as measured
below, this constructor's compatibility profile matches
[`Flow(Hamiltonian)`](hamiltonian.md), not the more restricted `Flow(ocp, law)`.

The dynamics used on this page generalize
[`Control laws`](../flows/control_laws.md)'s scalar example
(``\tilde H = p(u-x) - \tfrac12 u^2``) to any container:
``\tilde H(x,p,u) = p\cdot u - \tfrac12\lVert u\rVert^2``, with the law ``u = p`` — still
the stationary point (``\partial\tilde H/\partial u = p - u = 0``). This gives
``H(x,p) = \tfrac12\lVert p\rVert^2``, hence

```math
\dot x = \partial_p H = p, \qquad \dot p = -\partial_x H = 0
\;\Longrightarrow\;
x_f = x_0 + p_0, \qquad p_f = p_0 \quad\text{at } t_f = 1.
```

!!! note "Last probed: 2026-07-23"
    This page's table *shape* — which containers and axes are tested — reflects
    [`probe/cpu/probe_cpu.jl`](https://github.com/control-toolbox/CTFlows.jl/blob/main/probe/cpu/probe_cpu.jl)
    as of this date. Every ✓/✗ cell below is still re-executed on **every** documentation
    build regardless (see [Compatibility overview](overview.md)) — only the *scope* of
    what's tested can go stale, not the results shown.

```@setup ph_compat
using CTFlows
using CTBase.Data
using CTFlows.Flows
using CTFlows.Trajectories
import OrdinaryDiffEqTsit5
using StaticArrays: SA, SVector, MVector, SMatrix, MMatrix
using ForwardDiff: ForwardDiff
```

The flow is built once, in both `hamiltonian_type` modes:

```@example ph_compat
h̃ = Data.PseudoHamiltonian((x, p, u) -> sum(p .* u) - 0.5 * sum(abs2, u))
law = Data.DynClosedLoop((x, p) -> p)

hflow_total = Flows.Flow(h̃, law; reltol=1e-8)                                  # :total (default)
hflow_partial = Flows.Flow(h̃, law; hamiltonian_type=:partial, reltol=1e-8)
```

---

## Compatibility table

Because the feedback is stationary, `:total` (AD *through* the law) and `:partial` (AD at
fixed `u`) agree exactly — the two pairs of columns are a genuine consistency cross-check,
not two independent measurements, exactly as on [`Flow(ocp, law)`'s
table](ocp_control_laws.md#DynClosedLoop-Hamiltonian-flow,-total-vs-partial):

| State/costate type | `:total` point | `:total` traj | `:partial` point | `:partial` traj |
|---|:---:|:---:|:---:|:---:|
| Scalar `Real` | ✓ | ✓ | ✓ | ✓ |
| `Vector`/`MVector`/`SVector` `Real` | ✓ | ✓ | ✓ | ✓ |
| `Matrix`/`MMatrix`/`SMatrix` `Real` (batch) | ✓ | ✓ | ✓ | ✓ |
| `Complex` (any container) | ✗ (a) | ✗ (a) | ✗ (a) | ✗ (a) |
| `ForwardDiff.Dual` (any container) | ✗ (b) | ✗ (b) | ✗ (b) | ✗ (b) |

Unlike [`Flow(ocp, law)`](ocp_control_laws.md) (fixed-size internal buffer, `Matrix`-family
✗), **the full `Matrix` family works here** — measured, not assumed: confirms the "wraps
`H̃` directly" hypothesis above.

!!! note "(a) Complex is not supported"
    Same cause as [`Flow(Hamiltonian)`'s note (a)](hamiltonian.md#Compatibility-table): the
    default `AutoForwardDiff` backend cannot differentiate through a `Complex` input.

!!! note "(b) A hand-built `ForwardDiff.Dual` collides with the flow's own AD"
    Same cause as [`Flow(Hamiltonian)`'s nested-AD
    section](hamiltonian.md#Automatic-differentiation:-sensitivities-of-the-flow):
    `Flow(h̃, law)` is itself `AutoForwardDiff`-backed, so passing a hand-built `Dual` as
    `x0`/`p0` raises `DualMismatchError` rather than working. To differentiate the flow
    itself (e.g. for a shooting method), wrap the **flow call** in an outer
    `ForwardDiff.jacobian`/`gradient` instead — the same pattern documented there.

---

## Real states

```@repl ph_compat
x0, p0 = 1.0, 0.5;
xf, pf = hflow_total(0.0, x0, p0, 1.0);
xf ≈ x0 + p0, pf ≈ p0
```

```@repl ph_compat
hflow_partial(0.0, x0, p0, 1.0)   # matches hflow_total exactly — stationary feedback
```

```@repl ph_compat
hflow_total(0.0, SA[1.0, 2.0], SA[0.5, 0.3], 1.0)
```

```@repl ph_compat
sol = hflow_total((0.0, 1.0), [1.0, 2.0], [0.5, 0.3]);
Trajectories.state(sol)(1.0), Trajectories.costate(sol)(1.0)
```

```@repl ph_compat
hflow_total(0.0, MMatrix{2,2}(1.0, 3.0, 2.0, 4.0), MMatrix{2,2}(0.0, 1.0, 0.0, 1.0), 1.0)   # mutable
hflow_total(0.0, SMatrix{2,2}(1.0, 3.0, 2.0, 4.0), SMatrix{2,2}(0.0, 1.0, 0.0, 1.0), 1.0)   # immutable
```

---

## Complex and `Dual` states — not supported

```@repl ph_compat
try
    hflow_total(0.0, 1.0 + 2.0im, 0.0 + 0.0im, 1.0)
catch e
    showerror(stdout, e)
end
```

```@repl ph_compat
try
    hflow_total(0.0, ForwardDiff.Dual(1.0, 1.0), ForwardDiff.Dual(0.0, 0.0), 1.0)
catch e
    showerror(stdout, e)
end
```

See notes (a)/(b) above — for `Complex`, rewrite the system on real/imaginary components;
for differentiating the flow, wrap the **call** in an outer `ForwardDiff.jacobian`/`gradient`
as shown on [`Flow(Hamiltonian)`'s page](hamiltonian.md).

---

## `OpenLoop`/`ClosedLoop` — rejected

A pseudo-Hamiltonian ``\tilde H(t,x,p,u,v)`` depends on the costate ``p``, which
`OpenLoop`/`ClosedLoop` control laws do not provide:

```@repl ph_compat
try
    Flows.Flow(h̃, Data.ClosedLoop(x -> -x); reltol=1e-8)
catch e
    showerror(stdout, e)
end
```

---

## See also

- [Control laws](../flows/control_laws.md) — the guide page this reference expands on
  (`DynClosedLoop`, `hamiltonian_type`, `Flow(h̃, law)` vs `Flow(ocp, law)`).
- [`Flow(Hamiltonian)` compatibility](hamiltonian.md) — the shared `Complex`/nested-`Dual`
  root cause, and how to actually differentiate an AD-backed flow.
- [`Flow(ocp, law)` compatibility](ocp_control_laws.md) — the OCP-based counterpart, whose
  `Matrix`-family restriction (fixed-size buffer, [#358](https://github.com/control-toolbox/CTFlows.jl/issues/358))
  does **not** apply here.
- [Compatibility overview](overview.md) — the per-constructor feature matrix and the other flow types.
- [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Flows.HamiltonianFlow`](@ref) — the flow types.
- [`CTBase.Data.PseudoHamiltonian`](@extref CTBase.Data.PseudoHamiltonian), [`CTBase.Data.DynClosedLoop`](@extref CTBase.Data.DynClosedLoop) — the data wrappers.
