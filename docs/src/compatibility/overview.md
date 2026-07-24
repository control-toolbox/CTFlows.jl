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

Scope: the 8 per-constructor pages below cover **CPU**, with every example executed on
build. [GPU](gpu.md) is covered by a separate page, sourced from a dated probe run rather
than build-executed — see that page's note on why.

This work tracks issue
[#343](https://github.com/control-toolbox/CTFlows.jl/issues/343).

## Pages

| Constructor | Builds | Page | Status |
|---|---|---|---|
| `Flow(::VectorField)` | [`StateFlow`](@ref CTFlows.Flows.StateFlow) | [`Flow(VectorField)`](vector_field.md) | ✅ live |
| `Flow(::HamiltonianVectorField)` | [`HamiltonianFlow`](@ref CTFlows.Flows.HamiltonianFlow) | [`Flow(HamiltonianVectorField)`](hamiltonian_vector_field.md) | ✅ live |
| `Flow(::Hamiltonian)` | [`HamiltonianFlow`](@ref CTFlows.Flows.HamiltonianFlow) | [`Flow(Hamiltonian)`](hamiltonian.md) | ✅ live |
| `Flow(::ODEFunction)` / `Flow(::ODEProblem)` | [`StateFlow`](@ref CTFlows.Flows.StateFlow) / `SciMLProblemFlow` | [`Flow(SciML)`](sciml.md) | ✅ live |
| `Flow(ocp)` (control-free) | [`OptimalControlFlow`](@ref CTFlows.Flows.OptimalControlFlow) | [`Flow(ocp)`](ocp_free.md) | ✅ live |
| `Flow(ocp, law)` | [`OptimalControlFlow`](@ref CTFlows.Flows.OptimalControlFlow) / [`ControlledFlow`](@ref CTFlows.Flows.ControlledFlow) | [`Flow(ocp, law)`](ocp_control_laws.md) | ✅ live |
| `Flow(h̃, law)` | [`HamiltonianFlow`](@ref CTFlows.Flows.HamiltonianFlow) | [`Flow(h̃, law)`](pseudo_hamiltonian.md) | ✅ live |
| `Flow(fc, law)` | [`ControlledFlow`](@ref CTFlows.Flows.ControlledFlow) | [`Flow(fc, law)`](controlled_vector_field.md) | ✅ live |
| *(all of the above, on GPU)* | — | [GPU](gpu.md) | ✅ live (probe-sourced, not build-executed) |

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
- [`Flow(ocp)`](ocp_free.md) and [`Flow(ocp, law)`](ocp_control_laws.md) — unlike every flow
  above, **the state dimension is fixed at OCP construction** (`state!(pre, n)`), so no
  single flow accepts every container size; two problems (`n=1`, `n=2`) stand in for that
  pattern on both pages. Until 2026-07-24, an OCP-derived fixed-size internal buffer broke
  batched `Matrix` states everywhere and `SVector` states specifically on the non-AD
  (state-only / `OpenLoop`/`ClosedLoop`) paths ([#358](https://github.com/control-toolbox/CTFlows.jl/issues/358)) — **fixed**: the buffer is now
  sized from the runtime shape of the value passed in, so the full `Matrix`/`MMatrix`/
  `SMatrix`/`SVector`/`MVector` family works on every path, matching every other constructor
  on this site. The remaining ✗ cells are the AD-backed paths (`Flow(ocp)`,
  `Flow(ocp, DynClosedLoop)`) rejecting `Complex` and hand-built `Dual`, for the same reason
  as `Flow(Hamiltonian)`. Two things are **not** broken, worth calling out explicitly: adding
  `constraint=`/`multiplier=` to a `DynClosedLoop` flow never changes which state types work
  (measured, not assumed), and `:total`/`:partial` agree exactly for a stationary feedback
  law. One asymmetry is new to these pages: `Flow(ocp, OpenLoop/ClosedLoop)` accepts a
  `ForwardDiff.Dual` state at a *point* call but not in a *trajectory* call (the objective
  computation is not `Dual`-transparent).
- [`Flow(h̃, law)`](pseudo_hamiltonian.md) is the pseudo-Hamiltonian counterpart of
  `Flow(ocp, DynClosedLoop)`, but **without an OCP** — only `DynClosedLoop` is accepted
  (`OpenLoop`/`ClosedLoop` are rejected with `PreconditionError`, since a pseudo-Hamiltonian
  needs the costate). `PseudoHamiltonianSystem`/`Data.ComposedHamiltonian` wrap the user's
  `H̃` directly, with no OCP-derived buffer to size, so — like `Flow(ocp, DynClosedLoop)`
  since the #358 fix — the full `Matrix`/`MMatrix`/`SMatrix` family works, on both `:total`
  and `:partial`. Its compatibility profile otherwise matches `Flow(Hamiltonian)` exactly:
  every `Real` container works, `Complex` fails (AD-backed), and a hand-built `Dual`
  collides with the flow's own internal AD.
- [`Flow(fc, law)`](controlled_vector_field.md) is the controlled-vector-field counterpart
  of `Flow(h̃, law)` — only `OpenLoop`/`ClosedLoop` accepted (`DynClosedLoop` rejected,
  needs the costate). `Data.ControlledVectorField` has no in-place variant and, without an
  OCP, no fixed-size buffer either, so it builds the same plain out-of-place
  `VectorFieldSystem` as `Flow(VectorField)`. Measured: **fully green**, no unsupported
  combination at all — the most permissive of the four no-OCP/OCP "control law" pages.
  `Flow(ocp, law)`'s `OpenLoop`/`ClosedLoop` path now matches it on every state-shape axis;
  the one remaining difference is the trajectory-`Dual` restriction, which comes from the
  OCP's own objective computation (not `Dual`-transparent) and has no counterpart here since
  `Flow(fc, law)` computes no objective at all.
- [GPU](gpu.md) covers all constructors on NVIDIA/CUDA, sourced from a dated
  [`probe/gpu`](https://github.com/control-toolbox/CTFlows.jl/tree/main/probe/gpu) run
  rather than build-executed (no device in the Documenter build). Headline finding:
  **`AutoMooncake` is the only AD backend that survives every measured device call
  shape** — `AutoZygote` breaks once a call reduces over a device array or mutates one,
  `AutoEnzyme` breaks on GPU array reductions (`sum`/`mapreduce`) specifically, which real
  Hamiltonians always contain. AD-free flows (`VectorField`, `HamiltonianVectorField`,
  `ODEProblem`) need no keyword at all — just pass `CuArray`s.

This completes the compatibility table for every `Flow` constructor, on both CPU and GPU.

## See also

- [Flows overview](../flows/overview.md) — the data → systems → flows → trajectories pipeline.
- [Building a flow](../flows/building_a_flow.md) — the shortcut constructor and explicit pipeline.
- [Integrating](../flows/integrating.md) — call styles, variable parameters, and integrator options.
