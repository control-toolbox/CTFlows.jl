# GPU compatibility

```@meta
CurrentModule = CTFlows
```

Which `Flow` constructors and AD backends work with a device state (`CuArray`), on
NVIDIA/CUDA through CUDA.jl. AMDGPU and Metal are untested. The [GPU flows](../flows/gpu.md)
guide explains the contract behind these results: no scalar indexing, `method=:gpu`, the
choice of AD backend.

!!! warning "Measured on a device, not executed by the documentation build"
    The documentation build has no GPU, so the code blocks of this page are plain `julia`
    blocks. The results come from a run of
    [`probe/gpu/probe_gpu.jl`](https://github.com/control-toolbox/CTFlows.jl/blob/main/probe/gpu/probe_gpu.jl)
    on the self-hosted NVIDIA runner
    ([run 30037105763](https://github.com/control-toolbox/CTFlows.jl/actions/runs/30037105763/job/89317162708),
    2026-07-23). To check them against the current code, add the `run probe` label to a pull
    request.

---

## Per-constructor table

"Probe" says whether `probe/gpu` measures the row; the other rows rest on the hardware
tests of the test suite (see [GPU flows](../flows/gpu.md#What-runs-on-device)).

| Flow source | AD needed | Device call | Probe |
|---|---|---|---|
| `Flow(::VectorField)` | no | pass `CuArray`s | ✓ point and trajectory |
| `Flow(::HamiltonianVectorField)` | no | pass `CuArray`s | ✓ point |
| `Flow(::ODEFunction)` | no | pass `CuArray`s | not measured; same mechanism as `Flow(VectorField)` |
| `Flow(::ODEProblem)` | no | pass `CuArray`s | ✓ point (`remake`) |
| `Flow(ocp)`, state call (no costate) | no | pass `CuArray`s | not measured |
| `Flow(ocp, OpenLoop/ClosedLoop)` | no | pass `CuArray`s | not measured |
| `Flow(::Hamiltonian)` | yes | `method=:gpu` | ✓ `AutoZygote` and `AutoMooncake`; the CPU default fails (scalar indexing) |
| `Flow(ocp)`, Hamiltonian call / `Flow(ocp, DynClosedLoop)` | yes | `method=:gpu` | ✓ `AutoMooncake` only (in-place OCP dynamics) |
| Multi-phase concatenation (`*`), with jumps | inherits | works on device | not measured |
| `variable_costate=true` | yes | `ad_backend=AutoZygote()`, host or device `variable` | ✓ host variable, device variable of length 1 and 2 |

---

## AD backends on device

Four AD backends, on four call shapes: a plain gradient, the gradient of a `Hamiltonian`, a
**mutating** in-place right-hand side, and the Hamiltonian of a `Flow(ocp)` (in-place under
the hood, through the `dynamics!` of CTModels):

| Backend | Plain gradient | `hamiltonian_gradient` | Mutating in-place RHS | `Flow(ocp)` Hamiltonian |
|---|:---:|:---:|:---:|:---:|
| `AutoForwardDiff` (CPU default) | ✗ scalar indexing | ✗ scalar indexing | — | — |
| `AutoZygote` | ✓ | ✗ `KernelException` | ✗ can't differentiate `gc_preserve_end` | ✗ can't differentiate `gc_preserve_end` |
| `AutoMooncake` (GPU default) | ✓ | ✓ | ✓ | ✓ |
| `AutoEnzyme` | ✗ `EnzymeRuntimeActivityError` | ✗ `EnzymeMutabilityException` | ✓ | ✗ `EnzymeMutabilityException` |

`AutoMooncake` handles every call shape, which is why `method=:gpu` selects it.

!!! note "`AutoZygote` fails once the call reduces over a device array"
    The plain gradient works. Through `hamiltonian_gradient` (one more `sum(abs2, …)`
    layer) it raises a `KernelException`, and with mutation it cannot differentiate
    `gc_preserve_end` (a mutation-tracking marker).

!!! note "`AutoEnzyme` fails on GPU array reductions, not on mutation"
    A mutating right-hand side with no reduction (`du .= 2 .* u`) differentiates, on host
    and on device. Every failure in the table comes from a `sum`/`mapreduce` over a
    `CuArray` inside the traced function. Real Hamiltonians contain such reductions
    (`sum(abs2, x)`, `dot(p, x)`), so `AutoEnzyme` is not usable for `Flow(::Hamiltonian)` or
    `Flow(ocp, …)` on device.

---

## Ensembles: a coupled system needs the kernel path

[GPU ensembles](../flows/gpu.md#GPU-ensembles) uses both DiffEqGPU.jl algorithms on a
decoupled right-hand side. With a coupled one (`du .= A * u`, a matrix–vector product):

| Algorithm | Decoupled (`du .= .-u`) | Coupled (`du .= A * u`) |
|---|:---:|:---:|
| `EnsembleGPUArray` (in-place, host closures) | ✓ | ✗ `InvalidIRError` |
| `EnsembleGPUKernel` (out-of-place `SVector`) | ✓ | ✓ |

The in-place kernel of `EnsembleGPUArray` cannot compile a BLAS matrix–vector product
(kernels can neither allocate nor call BLAS). The out-of-place `SVector` right-hand side of
`EnsembleGPUKernel` lowers a small static product to plain kernel code.

---

## See also

- [GPU flows](../flows/gpu.md): the GPU contract for your own code, `method=:gpu`, AD
  backends, ensembles, testing on a device.
- [GPU internals](../dev/gpu-internals.md): design decisions, the routing path, the coercion
  helpers.
- [`probe/gpu`](https://github.com/control-toolbox/CTFlows.jl/tree/main/probe/gpu): the probe
  behind this page.
- [Compatibility](overview.md): the CPU pages.
