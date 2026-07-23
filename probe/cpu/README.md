# CPU capability probe

A **diagnostic** (not a test suite) that measures, on CPU, which `Flow` state-type /
call-style combinations actually work against the *current, unmodified* CTFlows — and,
for the ones that warn or fail, how. It is the ground-truth source for the
[compatibility pages](../../docs/src/compatibility/): every ✓ / ⚠ in a page's table is
backed by a green cell here.

- Nothing here asserts pass/fail. Every experiment is wrapped in `try/catch`, so a single
  failure never stops the run; each outcome is collected into a final **capability
  matrix** printed at the bottom of the log.
- It complements [`probe/gpu`](../gpu/README.md): same spirit, CPU target. GPU
  compatibility is measured there; CPU here.

## What it probes

- **`Flow(VectorField)`** — the dynamics `ẋ = -x` (analytic `x(1) = x0·e⁻¹`) integrated
  from every state container (`scalar`, `Vector`, `MVector`, `SVector`, `Matrix`,
  `MMatrix`, `SMatrix`), every element type (`Real`, `Complex`, `ForwardDiff.Dual`), both
  call styles (point `f(t0, x0, tf)` and trajectory `f((t0, tf), x0)`), for both an
  out-of-place and an in-place vector field.

Other constructors (`HamiltonianVectorField`, `Hamiltonian`, `ODEFunction`/`ODEProblem`,
`ocp`) will be added as additional blocks as their compatibility pages land.

## Running it

### Locally

```console
julia --project=probe/cpu probe/cpu/probe_cpu.jl
```

The script activates this folder's own environment and `Pkg.develop`s the checked-out
CTFlows, so it always measures the working-tree source. `Manifest.toml` is intentionally
not committed (resolved fresh each run).

### On CI

The [`.github/workflows/CPUProbe.yml`](../../.github/workflows/CPUProbe.yml) workflow runs
it on an Ubuntu runner. Trigger it either by:

- **manually** — Actions → "CPU probe" → *Run workflow*, or
- **on a PR** — add the `run probe` label to the pull request.

The capability matrix appears in the job log.

## Reading the matrix

- `✓` works, result matches the analytic solution to `err ≤ 1e-4`.
- `⚠` works but emits a performance `@warn`: an in-place vector field with an *immutable*
  initial condition (`SVector`/`SMatrix`) falls back to an out-of-place "finalize" RHS —
  correct, just slower.
- `✗` raised the named error type; `?` ran but the result did not match the analytic
  solution.

At the time of writing, `Flow(VectorField)` is **fully green on CPU**: no unsupported
state type. The only nuances are the `⚠` fallback above, and that a scalar state's point
call returns a scalar while its trajectory's `state(sol)(t)` returns a length-1 vector.
