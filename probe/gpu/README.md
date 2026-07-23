# GPU capability probe

A **diagnostic** (not a test suite) that measures, on real NVIDIA/CUDA hardware,
which CTFlows GPU combinations already work against the *current, unmodified*
packages — and, for the ones that fail, with which error. It exists to turn the GPU
design report's hypotheses into measured facts before any code is written.

- Nothing here asserts pass/fail. Every experiment is wrapped in `try/catch`, so a
  single failure never stops the run; each outcome is printed and collected into a
  final **capability matrix** (read the `SUMMARY` at the bottom of the log).
- It is a throwaway measurement harness. Once the works/doesn't-work boundary is
  known, it is replaced by real assertions in the CTFlows test suite (report §7).

## What it probes

- **B0** array primitives on device (incl. the `pv0` init-condition bug vs. its fix);
- **B1** `DifferentiationInterface.gradient` on a `CuArray` for `AutoForwardDiff` vs.
  `AutoZygote` (the core "AD is the GPU gate" question);
- **B2** the actual `Differentiation.hamiltonian_gradient` call on device;
- **B3** flows on device: `VectorField`, `HamiltonianVectorField`, `ODEProblem`
  (AD-free, expected to work) and `Hamiltonian` with default vs. Zygote backend;
- **B4** `variable_costate` flow on device (exercises the `pv0` construction);
- **B5** `Float32` end-to-end (no silent `Float64` promotion).

## Running it

### On CI (the intended path)

The `.github/workflows/GPUProbe.yml` workflow runs it on the self-hosted `kkt`
(NVIDIA) runner. Trigger it either by:

- **manually** — Actions → "GPU probe" → *Run workflow*, or
- **on a PR** — add the `run probe` label to the pull request (same label as the CPU probe).

The capability matrix appears in the job log.

### Locally (on a CUDA machine)

```console
julia --project=probe/gpu probe/gpu/probe_gpu.jl
```

The script activates this folder's own environment and `Pkg.develop`s the
checked-out CTFlows, so it always measures the working-tree source. `Manifest.toml`
is intentionally not committed (resolved fresh each run).

On a machine without a functional GPU the script still runs: all device probes are
reported as `SKIP` and the CPU baselines run, so it never errors.
