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
| `Flow(::HamiltonianVectorField)` | [`HamiltonianFlow`](@ref CTFlows.Flows.HamiltonianFlow) | — | 🚧 planned |
| `Flow(::Hamiltonian)` | [`HamiltonianFlow`](@ref CTFlows.Flows.HamiltonianFlow) | — | 🚧 planned |
| `Flow(::ODEFunction)` / `Flow(::ODEProblem)` | `SciMLProblemFlow` | — | 🚧 planned |
| `Flow(ocp)` | [`OptimalControlFlow`](@ref CTFlows.Flows.OptimalControlFlow) | — | 🚧 planned |

## At a glance — `Flow(VectorField)`

On CPU, the state flow built from a [`Data.VectorField`](@extref CTBase.Data.VectorField)
supports **every** state type tested — scalar, `Vector`, `Matrix` (batched columns),
`MVector` / `SVector`, `MMatrix` / `SMatrix`, with `Real`, `Complex`, or
`ForwardDiff.Dual` elements — in both the point and trajectory call styles. The only
caveat is that an **in-place** vector field with an **immutable** initial condition
(`SVector` / `SMatrix`) works but emits a performance warning. See
[`Flow(VectorField)`](vector_field.md) for the full table and runnable examples.

## See also

- [Flows overview](../flows/overview.md) — the data → systems → flows → trajectories pipeline.
- [Building a flow](../flows/building_a_flow.md) — the shortcut constructor and explicit pipeline.
- [Integrating](../flows/integrating.md) — call styles, variable parameters, and integrator options.
