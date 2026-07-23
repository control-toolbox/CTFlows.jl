# `Flow(::ODEFunction)` / `Flow(::ODEProblem)` compatibility

```@meta
CurrentModule = CTFlows
```

This page is a **living compatibility reference** for the two SciML-backed flow
constructors — `Flow(f::SciMLBase.AbstractODEFunction)` and
`Flow(prob::SciMLBase.AbstractODEProblem)`: which state types and call styles each
accepts, each shown with a minimal, executable example. Every ✓ / ⚠ / ✗ in the tables
below is demonstrated by a code block on this page and is re-run on every documentation
build, so the page cannot drift from the code.

Scope: **CPU** only. The tables are generated from [`probe/cpu/probe_cpu.jl`](https://github.com/control-toolbox/CTFlows.jl/blob/main/probe/cpu/probe_cpu.jl)
(run it locally with `julia --project=probe/cpu probe/cpu/probe_cpu.jl`). GPU
compatibility is a separate effort — see [`probe/gpu`](https://github.com/control-toolbox/CTFlows.jl/tree/main/probe/gpu).

All examples integrate the scalar exponential decay ``\dot{x} = -p\,x`` with ``p = 1.0``
(the default SciML integrator, `OrdinaryDiffEqTsit5`) — the same analytic solution as the
[`Flow(VectorField)`](vector_field.md) page: ``x(1) = x_0\,e^{-1}``.

!!! note "Last probed: 2026-07-23"
    This page's table *shape* — which containers and axes are tested — reflects
    [`probe/cpu/probe_cpu.jl`](https://github.com/control-toolbox/CTFlows.jl/blob/main/probe/cpu/probe_cpu.jl)
    as of this date. Every ✓/⚠/✗ cell below is still re-executed on **every** documentation
    build regardless (see [Compatibility overview](overview.md)) — only the *scope* of
    what's tested can go stale, not the results shown.

```@setup sciml_compat
using CTFlows
using CTFlows.Flows
using CTFlows.Integrators
using CTFlows.Trajectories
using SciMLBase: SciMLBase
import OrdinaryDiffEqTsit5
using StaticArrays: SA, SVector, MVector, SMatrix, MMatrix
using ForwardDiff: ForwardDiff
```

The two constructors have very different mechanics — one goes through the standard
CTFlows pipeline, the other bypasses it — so each gets its own section and its own table.

---

## `Flow(::ODEFunction)`

`Flow(f::SciMLBase.AbstractODEFunction)` wraps `f` in a `SciMLFunctionSystem` and runs
the **standard CTFlows pipeline** (`build_flow`), exactly like [`Flow(VectorField)`](vector_field.md):
the integration path (in-place vs out-of-place) is chosen from `ismutable(u0)`, with the
same warn-and-fallback for an in-place function called with an immutable `x0`.

The one structural difference: a SciML function always has the uniform `(du, u, p, t)` /
`(u, p, t)` signature, so the wrapped flow is always `NonAutonomous`/`NonFixed` — `variable`
must be passed explicitly on every call (there is no `Fixed`-by-default case like `VectorField`'s).

```@example sciml_compat
f_oop = SciMLBase.ODEFunction{false}((u, p, t) -> -p .* u)         # out-of-place
flow_f = Flows.Flow(f_oop; reltol=1e-8)
```

```@example sciml_compat
f_ip = SciMLBase.ODEFunction((du, u, p, t) -> du .= -p .* u)       # in-place
flow_f_ip = Flows.Flow(f_ip; reltol=1e-8)
```

### Compatibility table

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

**✓** works, matches ``x_0\,e^{-1}``. **⚠** works, but emits a performance `@warn` and
falls back to an out-of-place *finalize* RHS — same fallback mechanism as
[`Flow(VectorField)`](vector_field.md#In-place-vector-fields), for the same reason
(an immutable `x0` cannot receive an in-place write).

### Examples

Real, `Complex`, and `Dual` states all work with `variable=1.0` passed explicitly:

```@repl sciml_compat
flow_f(0.0, 1.0, 1.0; variable=1.0)                     # scalar Real
flow_f(0.0, [1.0, 2.0], 1.0; variable=1.0)               # Vector Real
flow_f(0.0, 1.0 + 2.0im, 1.0; variable=1.0)              # scalar Complex
x0 = ForwardDiff.Dual(1.0, 1.0)
flow_f(0.0, x0, 1.0; variable=1.0)                       # Dual scalar
```

Trajectory calls return a `Trajectories.VectorFieldTrajectory`, exactly like `Flow(VectorField)`:

```@repl sciml_compat
sol = flow_f((0.0, 1.0), [1.0, 2.0]; variable=1.0);
Trajectories.state(sol)(0.5)
```

The in-place function integrates mutable containers truly in place:

```@repl sciml_compat
flow_f_ip(0.0, [1.0, 2.0], 1.0; variable=1.0)
flow_f_ip(0.0, MVector{2}(1.0, 2.0), 1.0; variable=1.0)
```

and falls back with a warning for an immutable `SVector`/`SMatrix`, exactly like
`Flow(VectorField)`:

```@repl sciml_compat
flow_f_ip(0.0, SA[1.0, 2.0], 1.0; variable=1.0)   # warns, then returns the correct value
```

---

## `Flow(::ODEProblem)`

`Flow(prob::SciMLBase.AbstractODEProblem)` wraps the fully-assembled problem in a
`SciMLProblemFlow`. This **bypasses the CTFlows system pipeline entirely**: there is no
CTFlows `AbstractSystem`, no `get_ip_rhs`/`get_oop_rhs`. Every call does
`SciMLBase.remake` (to swap in a new `u0`/`tspan`/`p`) followed directly by
`CommonSolve.solve` — the mutability dispatch that protects every other constructor on
this page (and on [`Flow(VectorField)`](vector_field.md)) **does not exist here**.

```@example sciml_compat
prob_oop = SciMLBase.ODEProblem(f_oop, [1.0], (0.0, 1.0), 1.0)   # built out-of-place
pflow_oop = Flows.Flow(prob_oop; reltol=1e-8)
```

```@example sciml_compat
prob_ip = SciMLBase.ODEProblem(f_ip, [1.0], (0.0, 1.0), 1.0)     # built in-place
pflow_ip = Flows.Flow(prob_ip; reltol=1e-8)
```

Three call styles are supported. The **no-arg** call solves the problem exactly as
constructed — no `x0` involved, so it is not part of the table below:

```@repl sciml_compat
result = pflow_oop();
Integrators.final_state(result)   # ≈ [exp(-1)], from the problem's own u0=[1.0], p=1.0
```

### Compatibility table

The columns describe **which problem was remade at call time** — the problem built from
an out-of-place `ODEFunction`, or the one built from an in-place `ODEFunction` — for the
point and trajectory call styles:

| State type | OOP-built point | OOP-built traj | IP-built point | IP-built traj |
|---|:---:|:---:|:---:|:---:|
| Scalar `Real` | ✓ | ✓ | ✗ | ✗ |
| `Vector` `Real` | ✓ | ✓ | ✓ | ✓ |
| `MVector` `Real` | ✓ | ✓ | ✓ | ✓ |
| `SVector` `Real` | ✓ | ✓ | ✗ | ✗ |
| `Matrix` `Real` (batch) | ✓ | ✓ | ✓ | ✓ |
| `MMatrix` `Real` | ✓ | ✓ | ✓ | ✓ |
| `SMatrix` `Real` | ✓ | ✓ | ✗ | ✗ |
| Scalar `Complex` | ✓ | ✓ | ✗ | ✗ |
| `Vector` `Complex` | ✓ | ✓ | ✓ | ✓ |
| `MVector` `Complex` | ✓ | ✓ | ✓ | ✓ |
| `SVector` `Complex` | ✓ | ✓ | ✗ | ✗ |
| `Matrix` `Complex` | ✓ | ✓ | ✓ | ✓ |
| `SMatrix` `Complex` | ✓ | ✓ | ✗ | ✗ |
| `ForwardDiff.Dual` scalar | ✓ | ✓ | ✗ | ✗ |
| `ForwardDiff.Dual` `Vector` | ✓ | ✓ | ✓ | ✓ |
| `ForwardDiff.Dual` `MVector` | ✓ | ✓ | ✓ | ✓ |
| `ForwardDiff.Dual` `SVector` | ✓ | ✓ | ✗ | ✗ |

**✓** works, matches ``x_0\,e^{-1}``. Out-of-place-built problems remake cleanly to
*any* state type. **✗** the in-place-built problem's remake fails for every **immutable**
`x0` (scalar included — a bare `Number` cannot be mutated either).

!!! warning "No CTFlows guard on this path — a hard error, not a warning"
    Every other constructor on this site (`Flow(VectorField)`, `Flow(HamiltonianVectorField)`,
    and `Flow(::ODEFunction)` above) reacts to "in-place function + immutable state" with a
    **`@warn` and a correct, slower fallback** — CTFlows' own
    `build_problem` chooses that path. `SciMLProblemFlow` has no such fallback, because it
    never goes through `build_problem`: `SciMLBase.remake` hands the immutable `x0` straight
    to the in-place function's calling convention, and **SciML itself** raises a hard,
    native error:

    ```@example sciml_compat
    try
        pflow_ip(0.0, 1.0, 1.0; variable=1.0)
    catch e
        showerror(stdout, e)
    end
    ```

    The message is actionable (it names the fix: use an out-of-place function, or force
    `ODEProblem{false}`), but there is **no result** — unlike the warn-and-fallback path
    elsewhere on this page. If you plan to call a `Flow(::ODEProblem)` with an immutable
    state, build the underlying `ODEProblem` from an **out-of-place** function.

### Examples

The out-of-place-built problem accepts any state type, remade at call time:

```@repl sciml_compat
pflow_oop(0.0, SA[1.0, 2.0], 1.0; variable=1.0)             # SVector, out-of-place-built
pflow_oop(0.0, 1.0 + 2.0im, 1.0; variable=1.0)               # scalar Complex
```

The in-place-built problem works for any **mutable** state, remade in place:

```@repl sciml_compat
pflow_ip(0.0, [1.0, 2.0], 1.0; variable=1.0)
pflow_ip(0.0, MVector{2}(1.0, 2.0), 1.0; variable=1.0)
```

Trajectory calls return a **raw** `Integrators.AbstractIntegrationResult`, not a
`Trajectories.VectorFieldTrajectory` — use the low-level accessors
(`Integrators.times`, `Integrators.evaluate_at`, `Integrators.final_state`; see
[Trajectories — Low-level: integration result](../flows/trajectories.md#Low-level:-integration-result)):

```@repl sciml_compat
result = pflow_oop((0.0, 1.0), [1.0]; variable=1.0);
Integrators.evaluate_at(result, 0.5)
Integrators.final_state(result)
```

---

## See also

- [SciML flows](../flows/sciml.md) — the guide page this reference expands on.
- [Building a flow](../flows/building_a_flow.md) — the shortcut constructor and explicit pipeline.
- [Integrating](../flows/integrating.md) — call styles, variable parameters, and integrator options.
- [Trajectories](../flows/trajectories.md) — the low-level `AbstractIntegrationResult` accessors.
- [Compatibility overview](overview.md) — the per-constructor feature matrix and the other flow types.
- [`CTFlows.Flows.Flow`](@ref), [`CTFlowsSciMLFlows.SciMLProblemFlow`](@ref), [`CTFlowsSciMLFlows.SciMLFunctionSystem`](@ref) — the extension types.
