# GPU flows

```@meta
CurrentModule = CTFlows
```

CTFlows can integrate a flow whose state lives on a GPU device: you pass `CuArray`s instead of
`Array`s, and — for the flows that need automatic differentiation — you opt in with
`method=:gpu`.

This page covers what works, what it costs, and the one thing that is *not* optional: the
rules your own functions must follow to run on a device.

!!! note "Backends"
    Everything below was validated on NVIDIA hardware (CUDA.jl). The device-handling code in
    CTFlows dispatches on `GPUArraysCore.AbstractGPUArray`, so it is written to be
    backend-agnostic, but AMDGPU and Metal are untested.

---

## When a GPU helps — and when it does not

There are two very different ways to put an ODE on a GPU, and they have opposite performance
profiles.

| | **Array-level** | **Ensembles** |
|---|---|---|
| What is parallel | the operations *inside* one solve | many independent trajectories |
| State size it suits | large (≳ 10⁴ components) | small |
| A typical optimal-control flow (4–20 states) | **slower than CPU** | the case it is designed for |
| Status in CTFlows | supported, see below | tooling validated, no `Flow` API yet — see [GPU ensembles](#GPU-ensembles) |

For a state of a handful of components, an array-level GPU solve is *slower* than the CPU one:
kernel-launch latency dominates the arithmetic. That is expected and not a defect.

So why use it? **Composability.** An array-level GPU flow is what lets a flow sit *inside* a
computation that is already device-resident — a shooting function whose other pieces live on the
GPU, or a GPU solve driven by another package — without a round-trip to host memory at every
step. Use it for correctness and composition, not to accelerate a small isolated flow.

If what you want is raw throughput over many trajectories (multiple shooting, batched initial
guesses, sweeps over a variable), that is the ensemble model — see [GPU ensembles](#GPU-ensembles).

---

## Quickstart

Move the state to the device and call the flow as usual.

```julia
using CTFlows
using CTFlows.Flows
using CTBase.Data
import OrdinaryDiffEqTsit5
import CUDA

x0 = CUDA.CuArray([1.0, 2.0])

flow = Flows.Flow(Data.VectorField(x -> -x))   # ẋ = -x
xf = flow(0.0, x0, 1.0)                        # a CuArray: [1, 2] · e⁻¹
```

No keyword was needed there. For a flow that **differentiates** your function — anything built
from a `Hamiltonian`, or from an optimal control problem with a costate — add `method=:gpu`:

```julia
h = Data.Hamiltonian((x, p) -> (sum(abs2, x) + sum(abs2, p)) / 2)

flow = Flows.Flow(h; method=:gpu)
xf, pf = flow(0.0, CUDA.CuArray([1.0, 0.0]), CUDA.CuArray([0.0, 1.0]), 1.0)
```

!!! note "What `method=:gpu` actually does"
    It is not a hardware switch. It tells CTFlows to resolve its **strategies** in their GPU
    variants — the integrator (`SciML{GPU}`) and the AD backend
    (`DifferentiationInterface{GPU}`, which selects a GPU-capable backend, see
    [AD backends on device](#AD-backends-on-device)).

    Whether your arrays are on the device is decided by *you*, by what you pass in. That is why
    an AD-free flow needs no keyword at all: handing it a `CuArray` is enough.

    The rule of thumb: **AD-free flow → just pass device arrays. AD-dependent flow → also pass
    `method=:gpu`.**

The keyword is accepted by every `Flow` constructor and can be combined freely with the usual
[integrator options](integrating.md#integrator-options):

```julia
flow = Flows.Flow(h; method=:gpu, reltol=1e-10, abstol=1e-10)
```

---

## The GPU contract for your code

This is the part that breaks in practice. CTFlows itself is device-clean; **the GPU-safety
burden sits almost entirely in the functions you supply** — dynamics, Hamiltonians, control
laws, and cost terms.

### Rule: no scalar indexing

Reading one element of a device array (`x[1]`, `v[i]`) is a host↔device round-trip. CUDA.jl
forbids it under `CUDA.allowscalar(false)`, which is the setting CTFlows' own GPU tests run
under — and the setting you should develop against.

Write with reductions and broadcasts instead:

| ✗ Fails on device | ✓ Device-safe |
|---|---|
| `x[1]^2 + x[2]^2` | `sum(abs2, x)` |
| `p[1]*x[1] + p[2]*x[2]` | `dot(p, x)` (`using LinearAlgebra`) |
| `r[1] = -x[1]; r[2] = -x[2]` | `r .= .-x` |
| `xf[1]` in a Mayer term | `sum(xf)`, or any reduction over `xf` |
| `x[1] * x[2]` | `prod(x)`, or restructure the formula |

Reductions are the escape hatch: anything you can phrase as `sum`, `prod`, `dot`, `norm`,
`mapreduce` runs as a device kernel and returns a host scalar you can go on computing with.
Genuinely component-wise formulas — a dynamics that couples specific components — have no
device-safe rewrite at the flow level; that is a real limitation, not a style preference.

!!! note "The variable `v` is a host object"
    `v[1]` is fine: the variable stays on the host by design (see
    [Limits and boundaries](#Limits-and-boundaries)). The rule above concerns the state, the
    costate, and the dynamics buffer.

The reassuring part: **GPU-safe style is also perfectly good CPU code.** The same Hamiltonian
runs on both:

```@setup flows_gpu
using CTFlows
using CTFlows.Flows
using CTBase.Data
using CTBase.Strategies
import OrdinaryDiffEqTsit5
```

```@example flows_gpu
# reductions only — no x[1], no p[2]
h = Data.Hamiltonian((x, p) -> (sum(abs2, x) + sum(abs2, p)) / 2)

flow = Flows.Flow(h)                        # CPU here; identical code with method=:gpu
flow(0.0, [1.0, 0.0], [0.0, 1.0], 1.0)      # harmonic oscillator at t = 1
```

### The contract covers *every* closure of an OCP

Not just the dynamics. A trajectory call evaluates the **Mayer and Lagrange** terms on the
flow's own endpoints and states — which, on a GPU flow, are device arrays. A Mayer term written
the canonical way scalar-indexes them and fails:

```julia
# ✗ xf is a CuArray here — xf[1] is a scalar read
CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> xf[1])

# ✓ a reduction stays on device
CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> sum(xf))
```

The same applies to in-place dynamics: the buffer you are handed follows the state's array type,
so write it with a broadcast.

```julia
# ✗ component-wise writes into a device buffer
CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1] = -x[1]; r[2] = -x[2]; nothing))

# ✓ broadcast
CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r .= .-x; nothing))
```

!!! warning "The canonical `r[1] = …` idiom is CPU-only"
    Most optimal-control examples in the ecosystem write dynamics component by component. That
    style is fine on CPU and cannot run on a device. Porting a problem to GPU means rewriting
    those closures in broadcast form.

!!! note "Why the burden is yours"
    CTModels never scalar-indexes the dynamics buffer — it only ever hands your closure a
    contiguous `@view` of it, which is a valid lazy view on a `CuArray`. The model layer is
    structurally device-clean, so if a device run fails, look at your own closures first.

---

## What runs on device

Every constructor below has been executed on an NVIDIA device under `allowscalar(false)`:

| Flow source | AD needed | Device call |
|---|---|---|
| `Flow(::VectorField)` | no | pass `CuArray`s |
| `Flow(::HamiltonianVectorField)` | no | pass `CuArray`s |
| `Flow(::ODEFunction)`, `Flow(::ODEProblem)` | no | pass `CuArray`s |
| `Flow(ocp)` — state flow (no costate) | no | pass `CuArray`s |
| `Flow(ocp, ::OpenLoop/::ClosedLoop)` | no | pass `CuArray`s |
| `Flow(::Hamiltonian)` | yes | `method=:gpu` |
| `Flow(ocp)` — Hamiltonian (with costate) | yes | `method=:gpu` |
| `Flow(ocp, ::DynClosedLoop)` | yes | `method=:gpu` |
| multi-phase concatenation (`*`), with jumps | inherits | works on device |
| `variable_costate=true` | yes | works with a host or device `variable` |

!!! note "One caveat on the last row"
    The augmented `variable_costate` cases were validated on device with an explicit
    `ad_backend=AutoZygote()`, not with the `method=:gpu` default. Both are expected to work;
    only the former has actually been run on hardware.

### Limits and boundaries

**The variable `v` stays on the host.** It parameterises the right-hand side and broadcasts
cleanly against device arrays, so there is nothing to gain from moving it. A device `variable`
is accepted too, but host is the intended usage.

**Materialisation pulls back to host.** A point call `flow(t0, x0, tf)` returns device arrays —
the hot path stays on the device. Building a full `CTModels.Solution`, plotting, and grid
interpolation gather to the host at the boundary, because everything downstream of them (plot
backends, printing, interpolation) is host code by nature.

**The 1-D = scalar convention costs a synchronisation.** CTFlows represents a one-dimensional
state as a scalar, not a 1-vector. Collapsing a length-1 device array to a scalar is by
definition a scalar read; it is done safely, but it is a host synchronisation. GPU flows are
meant for vector states — a 1-D problem on a device is correct, not fast.

**`Float32` is preserved end-to-end.** GPUs prefer single precision and nothing in the chain
silently promotes to `Float64`:

```julia
flow = Flows.Flow(Data.VectorField(x -> -x))
xf = flow(0.0f0, CUDA.CuArray(Float32[1, 2]), 1.0f0)   # eltype(xf) == Float32
```

---

## AD backends on device

The default AD backend on CPU is `AutoForwardDiff()`. It **cannot** run on a device: forward
mode reads the array element by element, which is exactly the scalar indexing a device array
rejects. This is why AD-dependent flows need `method=:gpu` — it swaps in a GPU-capable default.

That default is `AutoMooncake()`, and the reason it wins is specific: an OCP Hamiltonian fills
its buffer through CTModels' **in-place** `dynamics!`, and most reverse-mode backends refuse to
differentiate array mutation. Mooncake differentiates it, on device, end to end.

The registry carries this as live help text:

```@example flows_gpu
Strategies.describe(:di, Flows.flow_registry())
```

You can always override the backend explicitly:

```julia
import ADTypes
import Zygote   # the package must be loaded: AutoZygote() is only a marker type
flow = Flows.Flow(h; ad_backend=ADTypes.AutoZygote())
```

!!! warning "`AutoZygote` on device is not reliably predictable"
    Zygote works on device in many cases — but its behaviour was found to depend on the *call
    context*, not just on the function: the same Hamiltonian formula that drives a full device
    integration successfully raised a `KernelException` when its gradient was taken directly, on
    a call that performs no mutation at all. It remains selectable, and is a reasonable thing to
    try; it is not something to rely on without testing your own case.

!!! warning "`AutoMooncake` on CPU is not a supported combination"
    Passing `ad_backend=AutoMooncake()` explicitly on **CPU** produces a cryptic `MethodError`:
    Mooncake returns a structural tangent for the `SubArray` views the Hamiltonian splitter
    produces, and that tangent cannot be negated. On device the CUDA-specific rules avoid this.
    The CPU default is `AutoForwardDiff()` — keep it.

---

## GPU ensembles

!!! warning "No CTFlows API yet"
    Solving many trajectories in parallel is where GPUs actually pay off for optimal control,
    but CTFlows does not wrap it yet — there is no batched `Flow` call. What follows is the raw
    SciML pattern, validated on device, that you can use directly today. A user-facing batch
    API is future work.

Two algorithms from DiffEqGPU.jl, with **different requirements on the right-hand side**:

```julia
import CUDA, DiffEqGPU, SciMLBase
import OrdinaryDiffEqTsit5, StaticArrays

N = 8
init(i) = [Float64(i), 2.0 * i]   # trajectory i starts at [i, 2i]

# --- EnsembleGPUArray: in-place RHS, host arrays moved by the algorithm ---
prob = SciMLBase.ODEProblem((du, u, p, t) -> (du .= .-u), init(1), (0.0, 1.0))
eprob = SciMLBase.EnsembleProblem(
    prob; prob_func=(p, ctx) -> SciMLBase.remake(p; u0=init(ctx.sim_id))
)
sol = SciMLBase.solve(
    eprob, OrdinaryDiffEqTsit5.Tsit5(), DiffEqGPU.EnsembleGPUArray(CUDA.CUDABackend());
    trajectories=N,
)

# --- EnsembleGPUKernel: out-of-place SVector RHS, no host closures ---
sprob = SciMLBase.ODEProblem(
    (u, p, t) -> -u, StaticArrays.SVector{2}(init(1)), (0.0, 1.0)
)
seprob = SciMLBase.EnsembleProblem(
    sprob;
    prob_func=(p, ctx) -> SciMLBase.remake(p; u0=StaticArrays.SVector{2}(init(ctx.sim_id))),
)
ssol = SciMLBase.solve(
    seprob, DiffEqGPU.GPUTsit5(), DiffEqGPU.EnsembleGPUKernel(CUDA.CUDABackend());
    trajectories=N,
)
```

### ⚠️ The scalar-indexing rule inverts here

This is the single most confusing thing about the two models, and getting it backwards costs
hours:

| | Flow code (everything above) | `EnsembleGPUArray` right-hand side |
|---|---|---|
| Where it runs | on the **host**, operating on device arrays | **inside a compiled kernel** |
| Governed by | `CUDA.allowscalar(false)` | what the GPU compiler accepts |
| `du[1] = u[2]` | ✗ forbidden | ✓ **correct idiom** |
| `du .= A * u` | ✓ fine | ✗ `InvalidIRError` — BLAS and heap allocation do not exist in a kernel |

Inside an ensemble kernel, `du` and `u` are device-array slices and component-wise access is
ordinary device code. What you must avoid there is *array-level linear algebra*: a matrix–vector
product routes through BLAS and allocates, neither of which a kernel can do. Write the coupled
system out component by component.

### Two more measured facts

**Results are not device-resident.** Both algorithms gather to the host before returning —
`EnsembleGPUArray` yields a view into a host `Matrix`, `EnsembleGPUKernel` a host `SVector`. Do
not assume you can chain another device computation onto the result without moving it back.

**Read final states through `.u`.** Use `sol.u[i].u[end]`, never `sol[i][end]`: the latter is
Cartesian indexing into the (component × time) shape and silently returns a scalar rather than
the final state vector — a bug that looks like a numerical error.

---

## Testing your own GPU code

The pattern CTFlows uses for its own device tests transfers directly:

```julia
import CUDA
CUDA.functional() || return          # skip cleanly on machines without a device
CUDA.allowscalar(false)              # make every pass genuinely scalar-index-free
```

Setting `allowscalar(false)` is what turns "it ran" into "it ran without secretly synchronising
element by element". Develop against it from the start.

---

## See also

- [GPU internals](../dev/gpu-internals.md) — design decisions, the routing path, the coercion helpers, and how the device tests are run in CI.
- [Integrating](integrating.md#integrator-options) — the solver options `method=:gpu` composes with.
- [SciML flows](sciml.md) — `Flow(::ODEFunction)` / `Flow(::ODEProblem)`, both usable on device.
- [Optimal control](optimal_control.md), [Control laws](control_laws.md) — the OCP constructors whose closures the GPU contract applies to.
- [`CTBase.Strategies`](@extref CTBase.Strategies) — the `CPU`/`GPU` strategy parameters behind `method=:gpu`.
