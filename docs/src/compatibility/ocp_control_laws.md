# `Flow(ocp, law)` compatibility

```@meta
CurrentModule = CTFlows
```

This page is a **living compatibility reference** for `Flow(ocp, law)`, built from an OCP
**with control** and a control law: which state/costate types and call styles each of the
three feedback kinds (`DynClosedLoop`, `OpenLoop`, `ClosedLoop`) accepts, each shown with a
minimal, executable example. Every ✓ / ✗ is demonstrated by a code block re-run on every
documentation build.

Scope: **CPU**, default AD backend. The tables are generated from
[`probe/cpu/probe_cpu.jl`](https://github.com/control-toolbox/CTFlows.jl/blob/main/probe/cpu/probe_cpu.jl).
GPU compatibility is a separate effort — see [`probe/gpu`](https://github.com/control-toolbox/CTFlows.jl/tree/main/probe/gpu).

As on [`Flow(ocp)`'s page](ocp_free.md), the state dimension is fixed at OCP construction,
so this page uses two problems built once — scalar (`n=1`) and vector (`n=2`) — and every
table tests the scalar containers against the first, the vector-family ones against the
second.

!!! note "Last probed: 2026-07-24"
    This page's table *shape* — which containers and axes are tested — reflects
    [`probe/cpu/probe_cpu.jl`](https://github.com/control-toolbox/CTFlows.jl/blob/main/probe/cpu/probe_cpu.jl)
    as of this date. Every ✓/✗ cell below is still re-executed on **every** documentation
    build regardless (see [Compatibility overview](overview.md)) — only the *scope* of
    what's tested can go stale, not the results shown. Until 2026-07-24, `Matrix`-family
    states failed on every path here and `SVector` failed on the non-AD
    (`OpenLoop`/`ClosedLoop`) path — the same fixed-size internal buffer as
    [`Flow(ocp)`](ocp_free.md), tracked as
    [#358](https://github.com/control-toolbox/CTFlows.jl/issues/358). Both are now fixed;
    the tables below reflect current (fixed) behaviour.

```@setup ocp_laws_compat
using CTFlows
using CTModels
using CTBase: Data
using CTFlows: Flows
using CTFlows: Trajectories
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5
using StaticArrays: SA, SVector, MVector
using ForwardDiff: ForwardDiff
```

As documented in [Control laws](../flows/control_laws.md), the constructor dispatches on
the law's feedback trait into **two structurally different flow types**:

| Law type | Flow type | Dynamics | Internal AD |
|---|---|---|---|
| `DynClosedLoop` | `OptimalControlFlow` (Hamiltonian) | state + costate | yes (`AutoForwardDiff`) |
| `OpenLoop` / `ClosedLoop` | `ControlledFlow` (state flow) | state only | no |

The OCP used on this page (the same one as [`Control laws`](../flows/control_laws.md)):
``\dot x = u - x``, ``\min \int_0^1 \tfrac12 u^2\,dt``.

```@example ocp_laws_compat
function build_ocp_ctrl(n)
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, n)
    CTModels.Building.control!(pre, n)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r .= u .- x; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * sum(abs2, u))
    return CTModels.Building.build(pre)
end

ocp1 = build_ocp_ctrl(1)
ocp2 = build_ocp_ctrl(2)
```

---

## `DynClosedLoop` — Hamiltonian flow, `:total` vs `:partial`

The law `u = p` is the stationary point of the pseudo-Hamiltonian
``\tilde H = p(u-x) - \tfrac12 u^2`` (``\partial\tilde H/\partial u = p - u = 0``), so the
composed Hamiltonian is ``H(x,p) = -p\cdot x + \tfrac12 p^2``, giving

```math
\dot x = -x + p, \qquad \dot p = p
\;\Longrightarrow\;
p_f = p_0\,e, \qquad x_f = \frac{x_0}{e} + \frac{p_0}{2}\left(e - \frac1e\right)
\quad\text{at } t_f=1.
```

```@example ocp_laws_compat
law = Data.DynClosedLoop((x, p) -> p)

f1_total = Flows.Flow(ocp1, law; reltol=1e-8)                                # :total (default)
f2_total = Flows.Flow(ocp2, law; reltol=1e-8)
f1_partial = Flows.Flow(ocp1, law; hamiltonian_type=:partial, reltol=1e-8)
f2_partial = Flows.Flow(ocp2, law; hamiltonian_type=:partial, reltol=1e-8)
```

Because the feedback is stationary, `:total` (AD *through* the law) and `:partial` (AD at
fixed `u`) agree exactly — the two columns below are a genuine consistency cross-check, not
two independent measurements:

| State type | `:total` point | `:total` traj | `:partial` point | `:partial` traj |
|---|:---:|:---:|:---:|:---:|
| Scalar `Real` | ✓ | ✓ | ✓ | ✓ |
| `Vector` `Real` | ✓ | ✓ | ✓ | ✓ |
| `MVector` `Real` | ✓ | ✓ | ✓ | ✓ |
| `SVector` `Real` | ✓ | ✓ | ✓ | ✓ |
| `Matrix`/`MMatrix`/`SMatrix` `Real` | ✓ | ✓ | ✓ | ✓ |
| `Complex` (any container) | ✗ (a) | ✗ (a) | ✗ (a) | ✗ (a) |
| `ForwardDiff.Dual` (any container) | ✗ (c) | ✗ (c) | ✗ (c) | ✗ (c) |

Notes (a)/(c) are exactly [`Flow(ocp)`'s notes (a)/(c)](ocp_free.md): `Complex` fails the
same `AutoForwardDiff` way, and a hand-built `Dual` collides with the flow's own AD the same
way — neither is specific to having a control law. `Matrix`/`MMatrix`/`SMatrix` states work
here too, fixed as of 2026-07-24 ([#358](https://github.com/control-toolbox/CTFlows.jl/issues/358)).

```@repl ocp_laws_compat
x0, p0 = 1.0, 0.5;
xf, pf = f1_total(0.0, x0, p0, 1.0);
xf ≈ x0/exp(1.0) + (p0/2)*(exp(1.0) - 1/exp(1.0)), pf ≈ p0*exp(1.0)
```

```@repl ocp_laws_compat
f1_partial(0.0, x0, p0, 1.0)   # matches f1_total exactly — stationary feedback
```

```@repl ocp_laws_compat
f2_total(0.0, SA[1.0, 2.0], SA[0.5, 0.3], 1.0)
f2_total(0.0, [1.0 2.0; 3.0 4.0], [0.5 0.3; 0.2 0.1], 1.0)
```

---

## `DynClosedLoop`, constrained — does adding `constraint=`/`multiplier=` keep working?

Using a **constant** `constraint=(x,u)->1.0` and `multiplier=(x,p)->0.3`: the product
``\mu\cdot g \equiv 0.3`` is a pure constant added to ``\tilde H_c``, so it contributes
nothing to ``\partial\tilde H_c/\partial x`` or ``\partial\tilde H_c/\partial p`` — the
dynamics, and hence the analytic reference above, are **unchanged**. This isolates "does the
constrained path still run" from "is the constrained physics right" (already covered by the
constrained-flow tests), and directly answers the question this table exists to answer:

```@example ocp_laws_compat
f1c_total = Flows.Flow(
    ocp1, law; constraint=(x, u) -> 1.0, multiplier=(x, p) -> 0.3, reltol=1e-8
)
f2c_total = Flows.Flow(
    ocp2, law; constraint=(x, u) -> 1.0, multiplier=(x, p) -> 0.3, reltol=1e-8
)
```

| State type | `:total` point | `:total` traj | `:partial` point | `:partial` traj |
|---|:---:|:---:|:---:|:---:|
| Scalar `Real` | ✓ | ✓ | ✓ | ✓ |
| `Vector`/`MVector`/`SVector` `Real` | ✓ | ✓ | ✓ | ✓ |
| `Matrix`-family `Real` | ✓ | ✓ | ✓ | ✓ |
| `Complex` (any container) | ✗ (a) | ✗ (a) | ✗ (a) | ✗ (a) |
| `ForwardDiff.Dual` (any container) | ✗ (c) | ✗ (c) | ✗ (c) | ✗ (c) |

**Measured: the ✓/✗ footprint is identical to the unconstrained table above, cell for
cell.** Adding a path constraint does not change what state types the flow accepts.

```@repl ocp_laws_compat
f1c_total(0.0, x0, p0, 1.0) == f1_total(0.0, x0, p0, 1.0)
```

---

## `OpenLoop` / `ClosedLoop` — state flow, no internal AD

`Flow(ocp, ClosedLoop(x -> -x))` eliminates the control (``u = -x``), giving
``\dot x = -2x \Rightarrow x_f = x_0\,e^{-2}``. This path has **no AD anywhere** — the
control law and the dynamics are both evaluated directly:

```@example ocp_laws_compat
law_cl = Data.ClosedLoop(x -> -x)
fcl1 = Flows.Flow(ocp1, law_cl; reltol=1e-8)
fcl2 = Flows.Flow(ocp2, law_cl; reltol=1e-8)
```

| State type | point | traj |
|---|:---:|:---:|
| Scalar `Real` | ✓ | ✓ |
| `Vector`/`MVector`/`SVector` `Real` | ✓ | ✓ |
| `Matrix`-family `Real` | ✓ | ✓ |
| Scalar/`Vector`/`MVector`/`SVector` `Complex` | ✓ | ✓ |
| `Matrix`-family `Complex` | ✓ | ✓ |
| `ForwardDiff.Dual` scalar/`Vector`/`MVector`/`SVector` | ✓ | ✗ (e) |

`Complex` and `Dual` work here (no AD in the RHS), like [`Flow(ocp)`'s basic
call](ocp_free.md) — `SVector`/`Matrix`-family now work too, fixed as of 2026-07-24
([#358](https://github.com/control-toolbox/CTFlows.jl/issues/358)) — **one asymmetry
remains**:

!!! note "(e) Dual works at a point, but not in a trajectory"
    `ForwardDiff.Dual` states integrate correctly for the **point** call, but the
    **trajectory** call raises `MethodError: no method matching Float64(::ForwardDiff.Dual{...})`.
    The trajectory path additionally computes the OCP objective (Mayer + Lagrange) from the
    reconstructed control and state, and that computation is not `Dual`-transparent — unlike
    the point call, which only integrates the state. If you need a trajectory with a `Dual`
    state, this is the concrete blocker to work around.

```@repl ocp_laws_compat
xf = fcl1(0.0, x0, 1.0)
xf ≈ x0 * exp(-2.0)
```

```@repl ocp_laws_compat
fcl1(0.0, ForwardDiff.Dual(1.0, 1.0), 1.0)   # point call: works
```

```@repl ocp_laws_compat
try
    fcl1((0.0, 1.0), ForwardDiff.Dual(1.0, 1.0))   # trajectory call: fails (note e)
catch e
    showerror(stdout, e)
end
```

```@repl ocp_laws_compat
sol = fcl2((0.0, 1.0), [1.0, 2.0]);
Trajectories.state(sol)(1.0), Trajectories.control(sol)(1.0)
```

`SVector` and `Matrix` (batch) both work, point and trajectory:

```@repl ocp_laws_compat
fcl2(0.0, SA[1.0, 2.0], 1.0)
fcl2(0.0, [1.0 2.0; 3.0 4.0], 1.0)
```

---

## See also

- [Control laws](../flows/control_laws.md) — the guide page this reference expands on
  (`DynClosedLoop`/`OpenLoop`/`ClosedLoop`, `hamiltonian_type`, the convenience constructor).
- [Constrained flows](../flows/constrained.md) — the `constraint=`/`multiplier=` API this
  page's constrained table exercises.
- [`Flow(ocp)` compatibility](ocp_free.md) — the control-free counterpart, and the source of
  notes (a)/(c) reused verbatim here.
- [`Flow(Hamiltonian)` compatibility](hamiltonian.md) — the shared `Complex`/nested-`Dual`
  root cause.
- [Compatibility overview](overview.md) — the per-constructor feature matrix and the other flow types.
- [`CTFlows.Flows.OptimalControlFlow`](@ref), [`CTFlows.Flows.ControlledFlow`](@ref) — the flow types.
