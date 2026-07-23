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
  out-of-place and an in-place vector field. Also checks that differentiating the flow
  *call* (outer `ForwardDiff.jacobian`) matches the analytic Jacobian.
- **`Flow(HamiltonianVectorField)`** — the harmonic oscillator `x' = p, p' = -x` (analytic
  `xf = p0, pf = -x0` at `t = π/2`), same state/costate containers, element types, call
  styles, OOP/IP split, and outer-Jacobian sensitivity check as the VF block.
- **`Flow(Hamiltonian)`** — same harmonic-oscillator dynamics via `H = ½(|x|²+|p|²)`,
  differentiated internally by the default `AutoForwardDiff` backend. No in-place variant
  (point/traj columns only); `Real` containers all work, `Complex` fails
  (`ArgumentError: Cannot create a dual over scalar type`). A dedicated "Nested AD" section
  measures how to differentiate *this* flow (which already uses ForwardDiff internally)
  w.r.t. `(x0, p0)` — the answer is an outer `ForwardDiff.jacobian`/`gradient` around the
  flow call, never a hand-built `Dual` passed in as `x0`/`p0`.
- **`Flow(::SciMLBase.ODEFunction)`** — `ẋ = -p·x` with `p = 1.0` (same analytic solution
  as the VF block), same state containers/element types/call styles/OOP-IP split. Always
  `variable=1.0` explicit (SciML's uniform signature forces `NonAutonomous`/`NonFixed`).
- **`Flow(::SciMLBase.ODEProblem)`** — same dynamics, remade at call time via
  `SciMLBase.remake`. `SciMLProblemFlow` bypasses the CTFlows system pipeline entirely, so
  unlike every block above there is **no CTFlows-level in-place/immutable guard** on this
  path; the block measures — rather than assumes — what happens when an ODEProblem built
  with an **in-place** function is remade with an **immutable** state (`SVector`) at call
  time, alongside the no-arg call `f()` and the out-of-place-built case.

- **`Flow(ocp)`** (control-free) — two OCPs built once (scalar `n=1`, vector `n=2`, since
  an OCP's state dimension is fixed at construction, unlike every block above). Covers the
  Hamiltonian call (state+costate), the basic state-only call
  ([#230](https://github.com/control-toolbox/CTFlows.jl/issues/230)), and a
  `variable=`/`variable_costate=` axis. Two structural causes explain almost every
  failure: a fixed-size internal derivative buffer (breaks `Matrix`-batch everywhere, and
  `SVector` specifically on the non-AD state-only path), and the same AD-backed
  `Complex`/`Dual` limitation as `Flow(Hamiltonian)`.
- **`Flow(ocp, law)`** — the three feedback kinds (`DynClosedLoop` → `OptimalControlFlow`,
  `OpenLoop`/`ClosedLoop` → `ControlledFlow`, no internal AD). Measures `:total` vs
  `:partial` `hamiltonian_type` on the full matrix (they coincide for a stationary law), and
  whether adding `constraint=`/`multiplier=` changes what state types work (measured: it
  does not — identical footprint). Also surfaces a new asymmetry: `ForwardDiff.Dual` works
  at a point call but not in a trajectory call for `OpenLoop`/`ClosedLoop` (the objective
  computation is not `Dual`-transparent).
- **`Flow(h̃, law)`** — the pseudo-Hamiltonian + `DynClosedLoop` constructor, no OCP
  (`OpenLoop`/`ClosedLoop` are rejected with `PreconditionError`, demonstrated once).
  `PseudoHamiltonianSystem`/`ComposedHamiltonian` wrap the user's `H̃` function directly —
  no OCP-derived fixed-size buffer — so, unlike `Flow(ocp, law)`, the full `Matrix`-family
  works here too. Measured: same profile as `Flow(Hamiltonian)` (all `Real` containers work
  on both `:total`/`:partial` × point/traj; `Complex` and a hand-built `Dual` both fail from
  the same internal-AD causes).
- **`Flow(fc, law)`** — the controlled-vector-field counterpart of `Flow(h̃, law)`: only
  `OpenLoop`/`ClosedLoop` accepted (`DynClosedLoop` rejected with `PreconditionError`,
  demonstrated once). `Data.ControlledVectorField` has no in-place variant and, without an
  OCP, no fixed-size buffer either — `Systems.build_system` builds a plain out-of-place
  `VectorFieldSystem`, identical to `Flow(VectorField)`'s OOP path. Measured: **fully green**
  — every container × `Real`/`Complex`/`ForwardDiff.Dual` × point/traj works, for both
  `OpenLoop` and `ClosedLoop` (34/34 on the full `ClosedLoop` matrix, spot-checked on
  `OpenLoop`). The most permissive of the "intermediate" (no-OCP) constructors probed here.

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

At the time of writing, `Flow(VectorField)`, `Flow(HamiltonianVectorField)`,
`Flow(::ODEFunction)`, and `Flow(fc, law)` are **fully green on CPU**: no unsupported state
type, only the `⚠` in-place-plus-immutable fallback above (which does not even apply to
`Flow(fc, law)`, since `Data.ControlledVectorField` has no in-place variant at all).
`Flow(Hamiltonian)` is green for every `Real`
container but has no `Complex` support (its internal AD backend cannot differentiate
through a complex scalar). `Flow(h̃, law)` shares that same `Complex`/`Dual` limitation but,
unlike `Flow(ocp)`/`Flow(ocp, law)`, has **no fixed-size buffer** — the full `Matrix` family
works. `Flow(ocp)` and `Flow(ocp, law)` are the most restricted
constructors probed here — a fixed-size internal buffer and the AD-backed `Complex`/`Dual`
limitation together explain almost every failure. See each block's in-script notes, and the
corresponding [compatibility page](../../docs/src/compatibility/), for the full nuances —
including the measured (not assumed) `Flow(::ODEProblem)` result for an in-place-built
problem remade with an immutable state.
