# =============================================================================
# GPU-safe scalar collapse — defined early because RHS-functor structs use
# `typeof(_safe_only)` in their type bounds (evaluated at struct-definition time),
# so `_safe_only` must exist before those files are included.
# =============================================================================

"""
$(TYPEDSIGNATURES)

Collapse a length-1 array to its single scalar element, GPU-safely.

# Arguments
- `x::GPUArraysCore.AbstractGPUArray`: device-resident array whose single element is extracted.
- `x`: any other length-1 collection (host arrays, etc.).

# Returns
- The single scalar element of `x` (a host scalar on both CPU and GPU).

# Notes
- On host arrays this is exactly `only(x)`.
- On device arrays, `only` would resolve via `iterate → getindex`, which `GPUArraysCore`
  blocks by default (scalar indexing of device memory). Since this is a single, deliberate,
  O(1) terminal extraction — not a scalar loop — it is wrapped in `@allowscalar`.
- Dispatch is on the **array actually received at the call site**, so the "1-D = scalar"
  convention returns an identical host scalar on CPU and GPU (never a device 1-vector).
- Backend-agnostic (`AbstractGPUArray` covers CUDA/AMDGPU/Metal).
- On the RHS hot path, only ever runs for the degenerate length-1-on-GPU case (real GPU
  workloads have `length ≥ 2`, where [`CTFlows.Systems._coerce_state`](@ref) returns
  `identity` at zero cost).

See also: [`CTFlows.Systems._coerce_state`](@ref).
"""
_safe_only(x::GPUArraysCore.AbstractGPUArray) = GPUArraysCore.@allowscalar only(x)

"""
$(TYPEDSIGNATURES)

Host-array fallback: exactly `only(x)`.

See also: [`CTFlows.Systems._safe_only`](@ref).
"""
_safe_only(x) = only(x)

"""
$(TYPEDSIGNATURES)

Infer the state dimension from the initial condition shape.

# Methods
- `_state_dim(x0::Number) = 1`
- `_state_dim(x0::AbstractVector) = length(x0)`
- `_state_dim(x0::AbstractMatrix) = size(x0, 1)`
"""
_state_dim(::Number) = 1

"""
$(TYPEDSIGNATURES)

State dimension of a vector initial condition: `length(x)`.

See also: [`CTFlows.Systems._state_dim`](@ref).
"""
_state_dim(x::AbstractVector) = length(x)

"""
$(TYPEDSIGNATURES)

State dimension of a batched `Matrix` initial condition: `size(x, 1)` (per-column batch).

See also: [`CTFlows.Systems._state_dim`](@ref).
"""
_state_dim(x::AbstractMatrix) = size(x, 1)

"""
$(TYPEDSIGNATURES)

Return the coercion applied to a 1-D quantity (state, costate, variable costate,
control) so that it is represented as a **scalar** when it has length 1, and left
untouched otherwise.

# Methods
- `_coerce_state(::Number) = _safe_only`
- `_coerce_state(::AbstractMatrix) = identity`
- `_coerce_state(x::AbstractVector) = length(x) == 1 ? _safe_only : identity`

This enforces the ecosystem convention *"a 1-dimensional quantity is a scalar"*: both
`2.0` and `[2.0]` collapse to the scalar `2.0` via `_safe_only`, regardless of how the
user supplied the initial condition. Vectors of length ≥ 2 and matrices (batch mode)
are left untouched via `identity`.

# Notes
- Scope (issue [control-toolbox/CTFlows.jl#357](https://github.com/control-toolbox/CTFlows.jl/issues/357)):
  applied on every **control-toolbox-sourced** flow — `HamiltonianSystem`,
  `HamiltonianVectorFieldSystem`, `PseudoHamiltonianSystem`,
  `ConstrainedPseudoHamiltonianSystem`, `PseudoHamiltonianVectorFieldSystem`,
  `VectorFieldSystem`, and `CTFlowsSciMLFlows.SciMLFunctionSystem` (which shares
  `VectorFieldSystem`'s `Systems`/`Trajectories` dispatch). **`CTFlowsSciMLFlows.SciMLProblemFlow`**
  (built directly from an `SciMLBase.AbstractODEProblem`) genuinely bypasses this dispatch
  (`remake`+`solve` only) and stays shape-preserving instead — it never calls
  `_coerce_state`.
- Differs from `CTBase.Core.make_coerce` in that a length-1 **vector** also collapses
  to a scalar (`_safe_only`, the GPU-safe `only`), not only a bare `Number`.

See also: [`CTFlows.Systems._safe_only`](@ref).
"""
_coerce_state(::Number) = _safe_only

"""
$(TYPEDSIGNATURES)

Batched `Matrix` states are always left untouched (`identity`): batch mode never collapses to a scalar.

See also: [`CTFlows.Systems._coerce_state`](@ref).
"""
_coerce_state(::AbstractMatrix) = identity

"""
$(TYPEDSIGNATURES)

Vector states: `_safe_only` for length 1 (1-D = scalar convention), `identity` otherwise.

See also: [`CTFlows.Systems._coerce_state`](@ref), [`CTFlows.Systems._safe_only`](@ref).
"""
_coerce_state(x::AbstractVector) = length(x) == 1 ? _safe_only : identity

"""
$(TYPEDSIGNATURES)

No-op fallback for when the initial state is unknown (`Core.NotProvided`), e.g. a
trajectory container built directly from a raw integration result without going
through a `Configs.AbstractConfig` (tests, low-level plumbing). Safe default:
apply no coercion rather than guess.
"""
_coerce_state(::Core.NotProvidedType) = identity

"""
$(TYPEDSIGNATURES)

Return `src` in a form that can be broadcast into `dst` without a device/host mismatch.

# Arguments
- `dst`: the destination array whose device determines the required location.
- `src`: the source block to broadcast into `dst`.

# Returns
- `src` itself when it is already compatible with `dst` (host/host, device/device, or scalar).
- A device-resident copy of `src` when `dst` is a device array and `src` is a host array.

# Notes
- Augmented Hamiltonian flows split into `[∂p; -∂x; -∂pv]`; on GPU the state blocks
  `∂x`/`∂p` are device-resident but `∂pv = -∂H/∂v` is **host** (the variable `v` transits
  host-side), so broadcasting it into a device `du` slice wraps a non-`isbits` host `Vector`
  in a `Broadcasted` and fails to compile (`GPUCompiler.KernelError`).
- `_device_like` copies **only** that host block onto the device matching `dst`; on host,
  and for already-device blocks, it is the identity (no copy).
- Dispatch is on the array actually received at the call site, so CPU behaviour is
  byte-for-byte unchanged and only the degenerate device-`dst`/host-`src` case pays a tiny
  `O(n_v)` H2D copy.
- Backend-agnostic (`GPUArraysCore.AbstractGPUArray` covers CUDA/AMDGPU/Metal).

See also: [`CTFlows.Systems._aug_assign!`](@ref), [`CTFlows.Systems._safe_only`](@ref).
"""
_device_like(::AbstractArray, src) = src

"""
$(TYPEDSIGNATURES)

Scalar source is always compatible with any destination: return `src` as-is.

See also: [`CTFlows.Systems._device_like`](@ref).
"""
_device_like(::GPUArraysCore.AbstractGPUArray, src::Number) = src

"""
$(TYPEDSIGNATURES)

Device-resident source on a matching device destination: return `src` as-is (no copy).

See also: [`CTFlows.Systems._device_like`](@ref).
"""
_device_like(::GPUArraysCore.AbstractGPUArray, src::GPUArraysCore.AbstractGPUArray) = src
function _device_like(dst::GPUArraysCore.AbstractGPUArray, src::AbstractArray)
    return copyto!(similar(dst, eltype(src), size(src)), src)
end

"""
$(TYPEDSIGNATURES)

Allocate an uninitialised length-`n` buffer of eltype `T` in `template`'s array type.

# Arguments
- `template`: an array or scalar whose type determines the buffer's array backend.
- `T`: the element type of the buffer.
- `n::Int`: the length of the buffer.

# Returns
- For `template::AbstractArray`: `similar(template, T, n)` — same array backend as `template`.
- For any other `template` (e.g. `Number`): `Vector{T}(undef, n)` — a host vector.

# Notes
- The OCP right-hand sides fill a length-`n_x` buffer through the **in-place** dynamics
  `dynamics!(r, t, x, u, v)`, plus empty `u`/`v` buffers for control-free / `Fixed` problems.
  Allocating those as a host `Vector` pins the whole OCP hot path to the CPU; deriving them
  from the state instead keeps the buffer on whichever device the state already lives on.
- The `Number` fallback is required, not defensive: under the "1-D = scalar" convention the
  coerced state is a scalar (via [`CTFlows.Systems._safe_only`](@ref) for a declared dimension
  of 1), and `similar` is undefined for `Number`. A scalar state is a **host** scalar even on
  GPU, so a host `Vector` is the correct buffer there.
- This generalises the same `isa AbstractArray` branch already used for `pv0` in
  `CTFlows.Flows` augmented initial conditions.
- Dispatch is on the value actually received at the call site, so CPU behaviour is
  byte-for-byte unchanged and no run-time type test enters the hot path.

See also: [`CTFlows.Systems._device_like`](@ref), [`CTFlows.Systems._safe_only`](@ref).
"""
_buffer_like(template::AbstractArray, ::Type{T}, n::Int) where {T} = similar(template, T, n)

"""
$(TYPEDSIGNATURES)

Scalar fallback: allocate a host `Vector{T}(undef, n)` — `similar` is undefined for `Number`.

See also: [`CTFlows.Systems._buffer_like`](@ref).
"""
_buffer_like(::Any, ::Type{T}, n::Int) where {T} = Vector{T}(undef, n)

"""
$(TYPEDSIGNATURES)

Allocate an uninitialised `n × batch` buffer of eltype `T` when `template` is itself a
batched `Matrix` state (each column an independent trajectory) — `batch = size(template, 2)`.

More specific than the `AbstractArray` method above, so it is selected automatically for
a `Matrix`/`MMatrix`/`SMatrix` template; no call site needs to change.

See also: [`CTFlows.Systems._buffer_like`](@ref).
"""
function _buffer_like(template::AbstractMatrix, ::Type{T}, n::Int) where {T}
    return similar(template, T, n, size(template, 2))
end
