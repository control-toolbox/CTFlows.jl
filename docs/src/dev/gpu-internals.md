# GPU internals

```@meta
CurrentModule = CTFlows
```

How GPU support is built, why it is built that way, and what to know before changing it. The
user-facing side lives in [GPU flows](../flows/gpu.md); this page is the design record.

---

## Architecture: the device parameter lives in the strategies

GPU support is spread across three packages, and the load-bearing idea is a single one:

> **The device is a parameter of the *strategies*, not a property of the flow.**

A flow never knows it is "a GPU flow". It was handed strategies that happen to be
parameterised on `GPU`, and it is called with device arrays.

| Package | What it contributes |
|---|---|
| CTBase | the `CPU`/`GPU` strategy parameters, and `Differentiation.DifferentiationInterface{P}` with a **per-device default AD backend** |
| CTSolvers | `Integrators.SciML{P}` and the per-device metadata seam |
| CTFlows | a registry declaring both families as `[CPU, GPU]`, plus the routing that turns `method=:gpu` into resolved strategies |

The alternative — a distinct `GPUStateFlow` type, or a device field on the flow — was rejected:
it would have duplicated the whole flow type hierarchy for something that only changes *how two
strategies are built*. Parameterising the strategies kept the flow layer untouched.

Both parameterisations are backward-compatible by construction: `SciML()` builds `SciML{CPU}`
and `DifferentiationInterface()` builds `DifferentiationInterface{CPU}`, so every pre-existing
call site behaves exactly as before.

!!! warning "Parameterising a strategy a consumer registers bare"
    When `SciML` was parameterised, the bare method `parameter(::Type{<:SciML}) = nothing` was
    dropped in favour of the parameterised one. `AbstractIntegrator` has **no family-level
    fallback** (unlike CTBase's `AbstractADBackend`), and CTFlows registers `SciML` *bare* — so
    `parameter(SciML)` started throwing and broke every existing flow path. The fix is to keep
    the bare method alongside the parameterised one; they are unambiguous by specificity.

    The regression was invisible to CTSolvers' own suite, which never calls `parameter(SciML)`
    bare. It was caught only by a backward-compatibility check run from the *consumer*. Worth
    repeating whenever a strategy gains a parameter.

---

## The path of `method=:gpu` through the code

`method` is a plain keyword that rides along in every constructor's `kwargs...` and is removed
at one place — the routing boundary. That choice is deliberate: threading a device argument
through the constructor signatures would have touched roughly twenty of them.

1. [`CTFlows.Flows._pop_method`](@ref) splits `(method, rest)` out of the keyword arguments, so
   `method` is never mistaken for a strategy option ([`src/Flows/flow_routing.jl`](https://github.com/control-toolbox/CTFlows.jl/blob/main/src/Flows/flow_routing.jl)).
2. [`CTFlows.Flows._flow_description`](@ref) completes the user tokens against
   [`CTFlows.Flows._available_flow_methods`](@ref), dispatched on `Traits.ad_trait`:
   - `WithAD` → `(:di, :sciml, :cpu)` / `(:di, :sciml, :gpu)`
   - `WithoutAD` → `(:sciml, :cpu)` / `(:sciml, :gpu)`

   One `:gpu` token therefore resolves the device for **both** families at once.
3. `Orchestration.resolve_method` matches the description against
   [`CTFlows.Flows.flow_registry`](@ref) and builds the concrete strategies.

!!! note "Base descriptions must carry `:cpu` explicitly"
    Because the registry is parameterised, `extract_global_parameter_from_method` requires a
    device token and throws without one. The base (default) descriptions therefore spell out
    `:cpu` rather than omitting it. `(:di, :sciml)` alone does not work.

This routing also unified two previously separate construction paths (with and without AD)
behind a single `_build_integrator` helper: every flow constructor now reaches the integrator
through the registry, so a device token is honoured no matter which constructor was called.

### What `SciML{GPU}` does today

Honestly: not much on its own. The runtime device behaviour in CTFlows is driven by **array
type dispatch** (`GPUArraysCore.AbstractGPUArray`), not by the integrator parameter. The
practical effect of `method=:gpu` today is selecting the GPU AD default.

`SciML{P}` carries a metadata seam and CTSolvers defines
`Integrators.__consistent_initial_condition(P, u0)` — a validator that flags a `CuArray` `u0`
under `SciML{CPU}` or a host `Array` under `SciML{GPU}`. **CTFlows does not call it yet.** It
was deliberately left in CTSolvers, next to the integrator, because `SciML` does not receive
`u0` at build time; wiring it in at problem construction is an open, self-contained improvement
that would turn a class of confusing device errors into a clear message.

---

## The coercion helpers

Three small functions in [`src/Systems/coercion.jl`](https://github.com/control-toolbox/CTFlows.jl/blob/main/src/Systems/coercion.jl)
carry essentially all the device-awareness of the package. Each solves a distinct problem, and
each is dispatched on `GPUArraysCore.AbstractGPUArray` so it stays backend-agnostic.

### [`CTFlows.Systems._safe_only`](@ref) — the 1-D = scalar convention

CTFlows represents a one-dimensional state as a scalar, and the collapse is `only(x)`. On a
device array `only` resolves through `iterate → getindex`: a scalar read, rejected under
`allowscalar(false)`. `_safe_only` wraps it in `@allowscalar` for `AbstractGPUArray` and is
plain `only` otherwise.

It is a genuine host synchronisation, but it only ever fires for the degenerate length-1 case —
real GPU workloads have `length ≥ 2`. The alternative (rejecting 1-D on device) was considered
and dropped: correct-but-slow beats an error at a boundary users cross by accident.

### [`CTFlows.Systems._device_like`](@ref) — augmented Hamiltonian blocks

Augmented flows (`variable_costate=true`) assemble `[∂p; -∂x; -∂pv]`. The `∂pv` block is
computed host-side, because the variable `v` stays on the host by design. Assigning a host array
into a slice of a device `du` puts a host array inside a `Broadcasted`, which fails to compile
with a `GPUCompiler.KernelError`.

`_device_like(dst, src)` adapts the host block to `dst`'s array type. The alternative — carrying
`v` on the device — was rejected: it would have pushed device-residency into the variable
handling everywhere, whereas one adaptation at the assignment point fixes all four augmented
functors at once.

### [`CTFlows.Systems._buffer_like`](@ref) — the in-place dynamics buffer

The OCP right-hand sides allocated their `dynamics!` buffer as `Vector{T}(undef, n)`, pinning it
to the host regardless of the state. Eleven sites. The obvious fix, `similar(xs, T, n)`, is
**not** a safe drop-in: under the 1-D = scalar convention `xs` may be a `Number`, which has no
useful `similar`. Hence:

```julia
_buffer_like(template::AbstractArray, ::Type{T}, n::Int) where {T} = similar(template, T, n)
_buffer_like(::Any, ::Type{T}, n::Int) where {T} = Vector{T}(undef, n)
```

!!! note "Measured cost on the CPU path: zero"
    A Goddard benchmark exercising the OCP pseudo-Hamiltonian under ForwardDiff reported
    **identical** memory and allocation counts before and after the migration, with values
    identical to the last digit. The reason is that the OCP right-hand side receives the state
    as a `SubArray`, and `similar(::SubArray, T, n)` allocates the same plain `Vector{T}`.

---

## Decisions, and what was rejected

**Why the variable `v` stays on the host.** It parameterises the right-hand side and transits
through `ODEParameters`. Julia broadcasts a host scalar against device arrays without help, and
a small host vector used in device code is a compatibility question the user owns. Moving it to
the device would buy nothing and complicate every path.

**Why materialisation gathers to the host.** Point calls return device arrays and the hot path
stays on the device; building a `CTModels.Solution`, plotting, and interpolation gather. Not a
compromise — everything downstream of those boundaries is host code by nature.

**Why `AutoMooncake` is the GPU AD default.** The gate is not GPU-ness, it is *mutation*: an OCP
Hamiltonian fills its buffer through CTModels' in-place `dynamics!`.

- `AutoForwardDiff` (the CPU default) scalar-indexes device arrays — unusable on device.
- `AutoZygote` (the original GPU default) cannot differentiate mutation, and the failure
  **reproduces on CPU**, which proves no buffer rewrite could have lifted it. A probe campaign
  additionally showed its device behaviour is **call-context dependent**: the same Hamiltonian
  formula raised a `KernelException` on a direct non-mutating gradient call while succeeding as
  the right-hand side of a full integration. That instability, independent of mutation, is why
  it was demoted rather than merely supplemented.
- `AutoEnzyme` fails reverse-mode activity analysis through `GPUArrays._mapreduce`/`sum` on a
  `CuArray`, and in the real OCP call the gradient closure captures a `CuArray` without the
  annotation Enzyme needs. The error names its own candidate fix,
  `AutoEnzyme(; function_annotation=Enzyme.Duplicated)` — **untried**. Enzyme is not ruled out,
  it simply was not needed once Mooncake cleared the whole matrix.
- `AutoMooncake` differentiates the mutating right-hand side on device, end to end, with correct
  values. Mooncake also ships CUDA rules (a `MooncakeCUDAExt` that is not advertised on the
  DifferentiationInterface backend page).

Rejected alternatives for the same blocker: rewriting the OCP Hamiltonians with `Zygote.Buffer`
(ties the code to one backend), and adding an out-of-place dynamics contract to CTModels
(cleanest in principle, but CTModels has no out-of-place API and it would have been a
cross-package change).

!!! note "The blocker was lifted by changing a default, not by writing code"
    Not one line of CTFlows `src/` is attributable to the OCP-Hamiltonian-on-device blocker. It
    was cleared by swapping the GPU AD default upstream in CTBase. The reason this was even
    visible as an option is that the capability was **probed on hardware before the
    implementation was designed** — the measurement changed the plan.

!!! warning "Changing an upstream default can break a downstream test environment"
    Swapping the GPU default to `AutoMooncake` left CTFlows' test environment resolving a
    backend it had never listed as a dependency. The next GPU CI run would have failed with no
    change on the CTFlows side at all — a latent breakage introduced entirely from upstream.
    When you change a computed default in a strategy, check the test environments of its
    consumers.

!!! warning "Residual: `AutoMooncake` on CPU"
    Verified on CPU: with a `@view`, Mooncake returns a structural
    `Mooncake.Tangent{@NamedTuple{parent, indices, offset1, stride1}}` — right values, inside
    `.parent`, but not an array — so negating it throws a `MethodError` in the Hamiltonian RHS
    functors. The views come from the Hamiltonian splitter. On device `MooncakeCUDAExt` yields a
    negatable tangent, so **no CTBase extension fix is required**; but a user explicitly asking
    for `AutoMooncake` on CPU gets a cryptic error. Not a supported combination.

---

## Testing on a device

### The gating pattern

Device tests self-gate, so a machine without a GPU skips them cleanly. The suite's single
CUDA-device predicate is `Main.TestCapabilities.CUDA_FUNCTIONAL` (computed once in
`test/runtests.jl` — never redefine a local `is_cuda_on()`), and `Main.TestCapabilities.ON_GPU_RUNNER`
turns a skip into a loud failure on the self-hosted GPU runners:

```julia
if Main.TestCapabilities.ON_GPU_RUNNER
    Test.@test Main.TestCapabilities.CUDA_FUNCTIONAL   # fails loudly if the GPU runner lost its device
elseif !Main.TestCapabilities.CUDA_FUNCTIONAL
    @info "CUDA not functional — GPU tests skipped"
    Test.@test_skip false   # shows as Broken, not Pass 0
    return nothing
end
CUDA.allowscalar(false)   # every ✓ below is genuinely scalar-index-free
```

`allowscalar(false)` is not decoration: without it a test can pass while silently synchronising
element by element, which is exactly the defect the tests exist to catch.

Two suites, deliberately separate — [`test/suite/extensions/test_gpu_flows.jl`](https://github.com/control-toolbox/CTFlows.jl/blob/main/test/suite/extensions/test_gpu_flows.jl)
(single flows, array-level) and `test_gpu_ensemble.jl` (the DiffEqGPU tooling proof of concept,
not wired to `Flow`). Every device example in the user guide is traceable to a row in one of
them.

### There is no local validation

**A developer without a device cannot validate GPU work locally.** The only real pass/fail is
the `test-gpu-occidata` job on the `occidata` self-hosted NVIDIA runner, triggered by the
`run ci occidata-runner` label on a pull request. Practical consequences:

- The label costs real GPU time. Do not set it on documentation-only or CPU-only changes.
- The workflows listen on `[labeled, synchronize, reopened]` — **not `opened`** — because
  creating a PR with a label already attached fires both events and bills two runs. `reopened`
  is kept: reopening does not re-emit `labeled`.
- Prefer letting a run finish over cancelling it. Cancelling a job on the self-hosted runner was
  observed to leave an orphan `julia` process and a pathologically slow next run.
- A cold job spends many minutes precompiling AD backends with no log output. Silence is not a
  hang.

### The probe harness

`probe/gpu/probe_gpu.jl` (on `main`, run by the `GPU probe` workflow — `workflow_dispatch`, or a
PR carrying the `run probe` label) is a standalone capability matrix: it exercises AD backends,
RHS shapes and ensemble algorithms on real hardware and reports pass/expected-fail/fail per row.
It exists because **guessing what a device supports is unreliable** — the step that mattered
most in this project was measuring first and designing after. Two speculative blockers turned
out not to exist, and the one real blocker was not anticipated at all.

Extend the probe before extending the implementation.

### ⚠️ The fake `AbstractGPUArray` trap

Device *dispatch* can be tested without a device by defining a CPU stand-in:

```julia
struct FakeGPUArray{T,N} <: GPUArraysCore.AbstractGPUArray{T,N}
    data::Array{T,N}
end
```

with `size`/`getindex`/`setindex!`/`similar` — enough to exercise `_safe_only`, `_device_like`,
`_buffer_like` and the split helpers on CPU.

**It stops being self-contained the moment GPUArrays.jl is loaded.** The test session does
`using CUDA` for every file, and GPUArrays overrides `copyto!`, `view` and `getindex` for
`AbstractGPUArray` with device-kernel implementations the CPU stand-in cannot satisfy — a
`StackOverflowError` in `copyto!`, "not implemented" in `view`/`getindex`. The fake must
therefore also delegate those methods to its backing `Array`, **and** define
`copyto!(::FakeGPUArray{T,N}, ::Array{T,N})` to resolve the ambiguity with GPUArrays'
`copyto!(::AnyGPUArray, ::Array)`.

Both fake-array test files already carry the fix; copy the pattern rather than rediscovering it.

---

## Out of scope

Recorded, not planned:

- a user-facing batched/ensemble `Flow` API (this is where the real speedup is);
- AMDGPU and Metal — the coercion layer is written backend-agnostically against
  `AbstractGPUArray`, but nothing has been tested;
- a GPU-specific default `alg` for the integrator;
- an out-of-place augmented problem construction;
- wiring `__consistent_initial_condition` into CTFlows for better device-mismatch errors.

---

## See also

- [GPU flows](../flows/gpu.md) — the user guide.
- [`CTFlows.Systems._safe_only`](@ref), [`CTFlows.Systems._device_like`](@ref), [`CTFlows.Systems._buffer_like`](@ref) — the coercion helpers.
- [`CTFlows.Flows.flow_registry`](@ref), [`CTFlows.Flows._flow_description`](@ref), [`CTFlows.Flows._pop_method`](@ref) — the routing surface.
- [`CTBase.Strategies`](@extref CTBase.Strategies), [`CTSolvers.Integrators`](@extref CTSolvers.Integrators) — the parameterised strategy families.
