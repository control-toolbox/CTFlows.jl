# `Flow(ocp)` compatibility (control-free)

```@meta
CurrentModule = CTFlows
```

This page is a **living compatibility reference** for `Flow(ocp)` built from a
**control-free** optimal control problem (`ocp::CTModels.Models.Model` with no `control!`
declared): which state/costate types and call styles it accepts, each shown with a
minimal, executable example. Every ✓ / ✗ in the tables below is demonstrated by a code
block on this page and is re-run on every documentation build, so the page cannot drift
from the code.

Scope: **CPU**, default AD backend (`AutoForwardDiff`). The tables are generated from
[`probe/cpu/probe_cpu.jl`](https://github.com/control-toolbox/CTFlows.jl/blob/main/probe/cpu/probe_cpu.jl)
(run it locally with `julia --project=probe/cpu probe/cpu/probe_cpu.jl`). GPU
compatibility is a separate effort — see [`probe/gpu`](https://github.com/control-toolbox/CTFlows.jl/tree/main/probe/gpu).

Unlike every other flow on this site, **the state dimension of an OCP is fixed at
construction** (`CTModels.Building.state!(pre, n)`) — one `Flow(ocp)` does not accept every
container size the way `Flow(VectorField)`/`Flow(HamiltonianVectorField)`/
`Flow(Hamiltonian)` do. This page therefore uses **two** control-free problems, built once:
a scalar one (`n=1`) and a vector one (`n=2`), and every table below tests the scalar
containers against the first and the vector-family containers against the second.

!!! note "Last probed: 2026-07-23"
    This page's table *shape* — which containers and axes are tested — reflects
    [`probe/cpu/probe_cpu.jl`](https://github.com/control-toolbox/CTFlows.jl/blob/main/probe/cpu/probe_cpu.jl)
    as of this date. Every ✓/✗ cell below is still re-executed on **every** documentation
    build regardless (see [Compatibility overview](overview.md)) — only the *scope* of
    what's tested can go stale, not the results shown.

```@setup ocp_free_compat
using CTFlows
using CTModels
using CTFlows.Flows
using CTFlows.Trajectories
import OrdinaryDiffEqTsit5
using StaticArrays: SA, SVector, MVector, SMatrix, MMatrix
using ForwardDiff: ForwardDiff
```

`Flow(ocp)` dispatches on the OCP's [`CTBase.Traits.ControlDependence`](@extref) trait: a
control-free problem builds an `OptimalControlFlow` directly from the OCP's own dynamics
and cost — ``H(t,x,p,v) = p \cdot f(t,x,v) + s\,p^0\,\ell(t,x,v)``. With no Lagrange cost
and dynamics ``\dot x = -x``, this reduces to ``H(x,p) = -p \cdot x``, giving

```math
\dot x = \partial_p H = -x, \qquad \dot p = -\partial_x H = p
\quad\Longrightarrow\quad (x_f, p_f) = (x_0\,e^{-1},\, p_0\,e) \text{ at } t_f = 1.
```

```@example ocp_free_compat
function build_ocp_free(n)
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, n)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r .= -x; nothing))
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> sum(xf))
    return CTModels.Building.build(pre)
end

ocp1 = build_ocp_free(1)   # scalar
ocp2 = build_ocp_free(2)   # vector
f1 = Flows.Flow(ocp1; reltol=1e-8)
f2 = Flows.Flow(ocp2; reltol=1e-8)
```

---

## Hamiltonian call — `f(t0, x0, p0, tf)`

The Hamiltonian point call `f(t0, x0, p0, tf)` returns `(xf, pf)`; the trajectory call
`f((t0, tf), x0, p0)` returns a [`CTModels.Solutions.Solution`](@extref).

| State/costate type | point | traj |
|---|:---:|:---:|
| Scalar `Real` | ✓ | ✓ |
| `Vector` `Real` | ✓ | ✓ |
| `MVector` `Real` | ✓ | ✓ |
| `SVector` `Real` | ✓ | ✓ |
| `Matrix` `Real` (batch) | ✗ (b) | ✗ (b) |
| `MMatrix` `Real` | ✗ (b) | ✗ (b) |
| `SMatrix` `Real` | ✗ (b) | ✗ (b) |
| `Complex` (any container) | ✗ (a) | ✗ (a) |
| `ForwardDiff.Dual` (any container) | ✗ (c) | ✗ (c) |

### Legend

- **✓** — works; the result matches ``(x_0 e^{-1}, p_0 e)`` and is executed on this page.
- **✗** — raises an error; see the corresponding note.

!!! note "(a) Complex is not supported — same cause as `Flow(Hamiltonian)`"
    `Flow(ocp)` is `AutoForwardDiff`-backed internally, exactly like
    [`Flow(Hamiltonian)`](hamiltonian.md): `ArgumentError: Cannot create a dual over scalar
    type ComplexF64`. See [`Flow(Hamiltonian)`'s note (a)](hamiltonian.md#Compatibility-table)
    for the full explanation and the real/imaginary-splitting workaround — it applies
    verbatim here.

!!! note "(b) Matrix (batch) states are not supported"
    Unlike `Flow(VectorField)`, `Flow(HamiltonianVectorField)`, and `Flow(Hamiltonian)` —
    which all support a column-batched `Matrix` state (each column an independent
    trajectory) — `Flow(ocp)`'s internal derivative buffer is always a **length-`n` vector**
    sized from the OCP's *declared* dimension, not from the shape of the value actually
    passed at call time. Feeding a 2-D (batched) state raises `DimensionMismatch:
    cannot broadcast array to have fewer non-singleton dimensions`. This is a structural
    property of how the OCP Hamiltonian is currently wired (`OCPHamiltonianFunction` /
    `Systems._buffer_like(x, T, n)`), not a deliberate restriction.

!!! note "(c) A hand-built Dual collides with the flow's own internal AD"
    Same nested-AD tag collision as [`Flow(Hamiltonian)`](hamiltonian.md#Automatic-differentiation:-sensitivities-of-the-flow):
    `DualMismatchError`. Differentiate the **flow call** with an outer
    `ForwardDiff.jacobian`/`gradient` instead of passing a hand-built `Dual` as `x0`/`p0` —
    see that page's pattern, which applies unchanged here.

### Examples

```@repl ocp_free_compat
x0, p0 = 1.0, 0.5;
f1(0.0, x0, p0, 1.0)   # (xf, pf) ≈ (x0·e⁻¹, p0·e)
```

```@repl ocp_free_compat
sol = f1((0.0, 1.0), x0, p0);
CTModels.Components.state(sol)(1.0), CTModels.Components.costate(sol)(1.0)
```

Vector, `MVector`, and `SVector` states (`ocp2`, `n=2`):

```@repl ocp_free_compat
f2(0.0, [1.0, 2.0], [0.5, 0.3], 1.0)
f2(0.0, MVector{2}(1.0, 2.0), MVector{2}(0.5, 0.3), 1.0)
f2(0.0, SA[1.0, 2.0], SA[0.5, 0.3], 1.0)
```

### Not supported: `Matrix` batch, `Complex`, hand-built `Dual`

```@repl ocp_free_compat
try
    f2(0.0, [1.0 2.0; 3.0 4.0], [0.5 0.3; 0.2 0.1], 1.0)
catch e
    showerror(stdout, e)
end
```

```@repl ocp_free_compat
try
    f1(0.0, 1.0 + 2.0im, 0.5 + 0.1im, 1.0)
catch e
    showerror(stdout, e)
end
```

---

## Basic (state-only) call — `f(t0, x0, tf)`

For a **control-free** OCP, `Flow(ocp)` also exposes a state-only call with **no costate**
(the direct-shooting use case, [#230](https://github.com/control-toolbox/CTFlows.jl/issues/230)),
dispatched by arity on the same `f` object. This path does **not** use automatic
differentiation at all — the state equation is computed exactly — so its compatibility
profile is structurally different from the Hamiltonian table above:

| State type | point | traj |
|---|:---:|:---:|
| Scalar `Real` | ✓ | ✓ |
| `Vector` `Real` | ✓ | ✓ |
| `MVector` `Real` | ✓ | ✓ |
| `SVector` `Real` | ✗ (d) | ✗ (d) |
| `Matrix` `Real` (batch) | ✗ (b) | ✗ (b) |
| Scalar `Complex` | ✓ | ✓ |
| `Vector`/`MVector` `Complex` | ✓ | ✓ |
| `SVector`/`Matrix` `Complex` | ✗ (d) / ✗ (b) | ✗ (d) / ✗ (b) |
| `ForwardDiff.Dual` scalar/`Vector`/`MVector` | ✓ | ✓ |
| `ForwardDiff.Dual` `SVector` | ✗ (d) | ✗ (d) |

Note the reversal from the Hamiltonian table: **`Complex` and `Dual` now work** (no AD on
this path, exactly like [`Flow(VectorField)`](vector_field.md)) — but `SVector` and
`Matrix` fail regardless of element type, for the structural reason below.

!!! note "(d) SVector fails: the internal buffer breaks out-of-place type-constancy"
    The same fixed-size internal buffer behind note (b) always returns a plain `Vector`,
    regardless of the input container. For a mutable state (`Vector`/`MVector`) this
    matches; for an immutable `SVector` it does not, and OrdinaryDiffEq's out-of-place
    solver requires the returned derivative to have the **same type** as the state at every
    step: `TypeNotConstantError: Detected non-constant types in an out-of-place ODE solve`.
    `Matrix` fails for the separate reason in note (b) (dimension, not type-constancy).

### Examples

```@repl ocp_free_compat
xf_basic = f1(0.0, x0, 1.0)
xf_basic ≈ x0 * exp(-1.0)
```

```@repl ocp_free_compat
sol_basic = f1((0.0, 1.0), x0);
Trajectories.state(sol_basic)(1.0)
```

`Complex` and `Dual` work directly — no AD on this path:

```@repl ocp_free_compat
f1(0.0, 1.0 + 2.0im, 1.0)
f1(0.0, ForwardDiff.Dual(1.0, 1.0), 1.0)
```

`SVector` fails even though the Hamiltonian call above accepted it:

```@repl ocp_free_compat
try
    f2(0.0, SA[1.0, 2.0], 1.0)
catch e
    showerror(stdout, e)
end
```

---

## `variable=` / `variable_costate=`

`Flow(ocp)` also accepts a `NonFixed` (variable-dependent) control-free problem. With
``\dot x = v\,x`` (autonomous, `variable!(pre, 1)`), the Hamiltonian is ``H(x,p,v) =
v\,(p\cdot x)``, giving

```math
(x_f, p_f) = (x_0\,e^{v},\, p_0\,e^{-v}) \text{ at } t_f = 1,
```

and — since ``p\cdot x`` is constant along the trajectory (the two exponentials cancel) —
a closed form for the **augmented variable-costate** `variable_costate=true` (see
[Optimal control § Free times](../flows/optimal_control.md#Free-times) for what this
mechanism is for):

```math
p_v(t_f) = -\sum(x_0 \cdot p_0)\,(t_f - t_0).
```

```@example ocp_free_compat
function build_ocp_free_variable(n)
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, n)
    CTModels.Building.variable!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r .= v[1] .* x; nothing))
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> sum(xf))
    return CTModels.Building.build(pre)
end

ocpv1 = build_ocp_free_variable(1)
ocpv2 = build_ocp_free_variable(2)
fv1 = Flows.Flow(ocpv1; reltol=1e-8)
fv2 = Flows.Flow(ocpv2; reltol=1e-8)
```

| State/costate type | `variable=v` | `+ variable_costate=true` |
|---|:---:|:---:|
| Scalar `Real` | ✓ | ✓ |
| `Vector`/`SVector` `Real` | ✓ | ✓ |
| Scalar `Complex` | ✗ (a) | ✗ (a) |
| `Dual` scalar | ✗ (c) | ✗ (c) |

This axis was flagged as a possible gap before measuring it — it turns out **not** to be
irregular: it fails exactly where the Hamiltonian table above fails (`Complex`/`Dual`, same
AD cause), and works everywhere `Real` does, including `variable_costate=true`.

```@repl ocp_free_compat
v = 0.7;
xf, pf = fv1(0.0, x0, p0, 1.0; variable=v);
[xf, pf] ≈ [x0 * exp(v), p0 * exp(-v)]
```

```@repl ocp_free_compat
xf, pf, pvf = fv1(0.0, x0, p0, 1.0; variable=v, variable_costate=true);
pvf ≈ -(x0 * p0)
```

---

## See also

- [Optimal control](../flows/optimal_control.md) — the guide page this reference expands on
  (control-free `Flow(ocp)`, free times, the basic state-only call).
- [Control laws](../flows/control_laws.md), [`Flow(ocp, law)` compatibility](ocp_control_laws.md)
  — the with-control counterpart.
- [`Flow(Hamiltonian)` compatibility](hamiltonian.md) — the `Complex`/nested-`Dual` notes
  this page reuses verbatim.
- [Compatibility overview](overview.md) — the per-constructor feature matrix and the other flow types.
- [`CTFlows.Flows.OptimalControlFlow`](@ref) — the flow type.
