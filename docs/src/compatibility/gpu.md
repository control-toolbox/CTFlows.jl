# GPU compatibility

```@meta
CurrentModule = CTFlows
```

This page is a **compatibility reference** for running a `Flow` on a GPU device
(`CuArray` state). It complements the [GPU flows](../flows/gpu.md) guide, which covers the
*why* and the *contract* (no scalar indexing, `method=:gpu`, AD backend selection) — this
page is the compact, per-constructor and per-AD-backend **table**, plus a few refinements
found while re-measuring for this page.

!!! warning "Last probed: 2026-07-23 — not build-executed"
    Unlike the 8 CPU pages, this page is not self-verifying: the code blocks below are
    **illustrative** `julia` blocks, not `@example`/`@repl` — there is no GPU device in the
    Documenter build (nor on the machine this page was written on). Every ✓/✗ is instead
    sourced from a **measured run** of [`probe/gpu/probe_gpu.jl`](https://github.com/control-toolbox/CTFlows.jl/blob/main/probe/gpu/probe_gpu.jl)
    on the self-hosted NVIDIA GPU runner —
    [run 30037105763](https://github.com/control-toolbox/CTFlows.jl/actions/runs/30037105763/job/89317162708),
    2026-07-23 — triggered specifically for this page, not carried over from an older
    document. Re-run the probe (`run probe` label on a PR) to re-verify; this page can drift
    from the code between probe runs in a way the CPU pages structurally cannot.

Scope: **NVIDIA/CUDA**, validated via CUDA.jl. AMDGPU/Metal are untested (see
[GPU flows](../flows/gpu.md)).

---

## Per-constructor table

| Flow source | AD needed | Device call | This run |
|---|---|---|---|
| `Flow(::VectorField)` | no | pass `CuArray`s | ✓ re-verified (point + trajectory) |
| `Flow(::HamiltonianVectorField)` | no | pass `CuArray`s | ✓ re-verified (point) |
| `Flow(::ODEFunction)` | no | pass `CuArray`s | not in this probe — same no-AD mechanism as `Flow(VectorField)`, see [`Flow(SciML)`](sciml.md) |
| `Flow(::ODEProblem)` | no | pass `CuArray`s | ✓ re-verified (point remake) |
| `Flow(ocp)` — state flow (no costate) | no | pass `CuArray`s | not re-tested this run — carried from prior validation, see [GPU flows](../flows/gpu.md#What-runs-on-device) |
| `Flow(ocp, OpenLoop/ClosedLoop)` | no | pass `CuArray`s | not re-tested this run — carried from prior validation |
| `Flow(::Hamiltonian)` | yes | `method=:gpu` (swaps the default AD backend — see below) | ✓ re-verified: default backend fails (scalar indexing, expected), `AutoZygote`/`AutoMooncake` both work |
| `Flow(ocp)` — Hamiltonian (with costate) / `Flow(ocp, DynClosedLoop)` | yes | `method=:gpu` | ✓ re-verified — **only `AutoMooncake` survives** the in-place OCP dynamics on device (see backend table) |
| Multi-phase concatenation (`*`), with jumps | inherits | works on device | not re-tested this run — carried from prior validation |
| `variable_costate=true` | yes | explicit `ad_backend=AutoZygote()`, host or device `variable`, any length | ✓ re-verified (host variable, device variable length 1 and length 2) |

Rows marked "not re-tested this run" are not disproven — `probe/gpu/probe_gpu.jl` simply
doesn't cover them yet; they carry forward [GPU flows](../flows/gpu.md#What-runs-on-device)'
prior hardware validation without a fresh timestamp.

---

## AD backend comparison (fresh finding)

The probe exercises four AD backends across four call shapes: a plain gradient, the actual
`Hamiltonian` gradient, a **mutating** in-place RHS, and the real `Flow(ocp)` Hamiltonian
(which is in-place under the hood, via `CTModels`' `dynamics!`):

| Backend | Plain gradient | `hamiltonian_gradient` | Mutating in-place RHS | `Flow(ocp)` Hamiltonian |
|---|:---:|:---:|:---:|:---:|
| `AutoForwardDiff` (CPU default) | ✗ scalar indexing | ✗ scalar indexing | — | — |
| `AutoZygote` | ✓ | ✗ `KernelException` | ✗ can't differentiate `gc_preserve_end` | ✗ can't differentiate `gc_preserve_end` |
| `AutoMooncake` (GPU default) | ✓ | ✓ | ✓ | ✓ |
| `AutoEnzyme` | ✗ `EnzymeRuntimeActivityError` | ✗ `EnzymeMutabilityException` | ✓ | ✗ `EnzymeMutabilityException` |

**`AutoMooncake` is the only backend that survives every call shape measured on device** —
confirming it as the right `method=:gpu` default (already documented in
[GPU flows](../flows/gpu.md#AD-backends-on-device)).

Two refinements this run adds:

!!! note "`AutoZygote` breaks specifically once a call reduces over a device array"
    The plain gradient (no reduction inside the traced function beyond a final `sum`) works
    with `AutoZygote`. The moment the call chain goes through
    `CTBaseDifferentiationInterface.hamiltonian_gradient` (an extra `sum(abs2, …)` layer) or
    touches mutation, it fails — a `KernelException` in the first case, an inability to
    differentiate `gc_preserve_end` (a mutation-tracking marker) in the second. This is
    consistent with, and sharpens, the existing warning that `AutoZygote` "is not reliably
    predictable" on device.

!!! note "`AutoEnzyme` fails specifically on GPU array reductions, not on mutation itself"
    A synthetic mutating RHS with no reduction (`du .= 2 .* u`) differentiates fine with
    `AutoEnzyme`, on both host and device. But every failure above —
    `EnzymeRuntimeActivityError` on the plain gradient, `EnzymeMutabilityException` on
    `hamiltonian_gradient` and on `Flow(ocp)`'s Hamiltonian — traces back to a `sum`/
    `mapreduce` over a `CuArray` inside the traced function. Real Hamiltonians almost always
    contain such a reduction (`sum(abs2, x)`, `dot(p, x)`), so in practice `AutoEnzyme` is
    not currently usable for `Flow(::Hamiltonian)`/`Flow(ocp, ...)` on device — not a general
    "Enzyme doesn't support GPU" limitation, but this specific pattern.

---

## Ensembles: a coupled system needs the kernel path, not the array path

[GPU ensembles](../flows/gpu.md#GPU-ensembles) already documents both DiffEqGPU.jl
algorithms for a decoupled decay RHS (`du .= .-u`), where both work. This run adds a
**coupled** oscillator (`du .= A * u`, a genuine matrix–vector product) to check whether
that still holds:

| Algorithm | Decoupled (`du .= .-u`) | Coupled (`du .= A * u`) |
|---|:---:|:---:|
| `EnsembleGPUArray` (in-place, host closures) | ✓ | ✗ `InvalidIRError` (expected) |
| `EnsembleGPUKernel` (out-of-place `SVector`) | ✓ | ✓ |

This matches [GPU ensembles](../flows/gpu.md#⚠️-The-scalar-indexing-rule-inverts-here)'
own warning, now with a concrete failure: `EnsembleGPUArray`'s in-place kernel cannot
compile a BLAS matrix–vector product (`InvalidIRError`, as documented — kernels can't
allocate or call BLAS), while `EnsembleGPUKernel`'s out-of-place `SVector` RHS handles the
coupled system correctly, since a small static matrix–vector product lowers to ordinary
kernel code rather than a BLAS call.

---

## See also

- [GPU flows](../flows/gpu.md) — the full narrative guide: the GPU contract for your own
  code, `method=:gpu`, AD backend selection, ensembles, testing your own GPU code.
- [GPU internals](../dev/gpu-internals.md) — design decisions, the routing path, the
  coercion helpers.
- [`probe/gpu`](https://github.com/control-toolbox/CTFlows.jl/tree/main/probe/gpu) — the
  probe this page is sourced from; re-run it (`run probe` label) to refresh this page.
- [Compatibility overview](overview.md) — the per-constructor feature matrix and the CPU
  compatibility pages.
