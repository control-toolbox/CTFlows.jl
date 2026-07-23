# Compatibility

```@meta
CurrentModule = CTFlows
```

This section is a **living compatibility reference** for the `Flow` constructors. For each
way of building a flow — from a vector field, a Hamiltonian vector field, a Hamiltonian, a
SciML function/problem, or an optimal control problem — a dedicated page lists the
supported state types, scalar types, and call styles in a table, **with a minimal,
executable example for every supported cell**.

Two properties keep these pages trustworthy:

- **Probe-backed.** Each page's table is generated from a capability probe under
  [`probe/`](https://github.com/control-toolbox/CTFlows.jl/tree/main/probe) that runs every
  combination against the current source and records what works, what warns, and what
  fails. The CPU probe is [`probe/cpu/probe_cpu.jl`](https://github.com/control-toolbox/CTFlows.jl/blob/main/probe/cpu/probe_cpu.jl).
- **Executed on build.** Every ✓ / ⚠ example is a Documenter `@example` block re-run on each
  documentation build, so a page cannot silently drift from the code.

Scope: these pages cover **CPU**. GPU compatibility is a separate effort, measured by
[`probe/gpu`](https://github.com/control-toolbox/CTFlows.jl/tree/main/probe/gpu).

This work tracks issue
[#343](https://github.com/control-toolbox/CTFlows.jl/issues/343).

## Pages

| Constructor | Builds | Page | Status |
|---|---|---|---|
| `Flow(::VectorField)` | [`StateFlow`](@ref CTFlows.Flows.StateFlow) | [`Flow(VectorField)`](vector_field.md) | ✅ live |
| `Flow(::HamiltonianVectorField)` | [`HamiltonianFlow`](@ref CTFlows.Flows.HamiltonianFlow) | [`Flow(HamiltonianVectorField)`](hamiltonian_vector_field.md) | ✅ live |
| `Flow(::Hamiltonian)` | [`HamiltonianFlow`](@ref CTFlows.Flows.HamiltonianFlow) | [`Flow(Hamiltonian)`](hamiltonian.md) | ✅ live |
| `Flow(::ODEFunction)` / `Flow(::ODEProblem)` | [`StateFlow`](@ref CTFlows.Flows.StateFlow) / `SciMLProblemFlow` | [`Flow(SciML)`](sciml.md) | ✅ live |
| `Flow(ocp)` | [`OptimalControlFlow`](@ref CTFlows.Flows.OptimalControlFlow) | — | 🚧 planned |

## At a glance

- [`Flow(VectorField)`](vector_field.md) and
  [`Flow(HamiltonianVectorField)`](hamiltonian_vector_field.md) report the same result on
  CPU: **every** state/costate type tested works — scalar, `Vector`, `Matrix` (batched
  columns), `MVector` / `SVector`, `MMatrix` / `SMatrix`, with `Real`, `Complex`, or
  `ForwardDiff.Dual` elements — in both the point and trajectory call styles. The only
  caveat in both cases is that an **in-place** vector field with an **immutable** initial
  condition (`SVector` / `SMatrix`) works but emits a performance warning.
  `Flow(HamiltonianVectorField)` is also already
  ["1-D = scalar"](https://github.com/control-toolbox/Handbook/blob/main/philosophy/dimension-and-shape.md)
  end to end (point *and* trajectory), unlike `Flow(VectorField)` — see
  [#357](https://github.com/control-toolbox/CTFlows.jl/issues/357).
- [`Flow(Hamiltonian)`](hamiltonian.md) (AD-backed, no in-place variant) supports every
  **real** container the same way, but its default backend (`AutoForwardDiff`) does **not**
  support `Complex` states. To differentiate the flow itself with respect to `(x0, p0)`
  (e.g. for shooting), wrap the *call* in an outer `ForwardDiff.jacobian`/`gradient` —
  never construct a `Dual` by hand and pass it as `x0`/`p0`. It is also already
  1-D = scalar end to end, via the same coercion machinery as
  `Flow(HamiltonianVectorField)` (see #357).
- [`Flow(SciML)`](sciml.md) covers two constructors with very different mechanics.
  `Flow(::ODEFunction)` goes through the same CTFlows pipeline as `Flow(VectorField)` and
  reports the identical result (every container works; in-place + immutable state warns
  and falls back). `Flow(::ODEProblem)` bypasses that pipeline entirely — `SciMLBase.remake`
  feeds the new state straight to the original function, with **no CTFlows-level guard**.
  For a problem built from an **out-of-place** function, every state type remakes cleanly;
  for one built **in-place**, remaking with an **immutable** state (including a bare
  scalar) is a **hard, native SciML error** — not a warning with a fallback like everywhere
  else on this site. Build the `ODEProblem` from an out-of-place function if you need to
  call it with immutable states.

## See also

- [Flows overview](../flows/overview.md) — the data → systems → flows → trajectories pipeline.
- [Building a flow](../flows/building_a_flow.md) — the shortcut constructor and explicit pipeline.
- [Integrating](../flows/integrating.md) — call styles, variable parameters, and integrator options.
