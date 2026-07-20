# =============================================================================
# GPU-safe scalar collapse — defined early because RHS-functor structs use
# `typeof(_safe_only)` in their type bounds (evaluated at struct-definition time),
# so `_safe_only` must exist before those files are included.
# =============================================================================

"""
    _safe_only(x::GPUArraysCore.AbstractGPUArray) = GPUArraysCore.@allowscalar only(x)
    _safe_only(x) = only(x)

Collapse a length-1 array to its single scalar element, GPU-safely.

On host arrays this is exactly `only(x)`. On device arrays (`CuArray` and any other
`GPUArraysCore.AbstractGPUArray`), `only` would resolve via `iterate → getindex`, which
`GPUArraysCore` blocks by default (scalar indexing of device memory). Since this is a
single, deliberate, O(1) terminal extraction — not a scalar loop — it is wrapped in
`@allowscalar`, which permits exactly this one read. Dispatch is on the **array actually
received at the call site**, so the "1-D = scalar" convention returns an identical host
scalar on CPU and GPU (never a device 1-vector), preserving CPU/GPU uniformity.

This is backend-agnostic (`AbstractGPUArray` covers CUDA/AMDGPU/Metal) and, on the RHS hot
path, only ever runs for the degenerate length-1-on-GPU case (real GPU workloads have
`length ≥ 2`, where [`CTFlows.Systems._coerce_state`](@ref) returns `identity` at zero cost).

See also: [`CTFlows.Systems._coerce_state`](@ref).
"""
_safe_only(x::GPUArraysCore.AbstractGPUArray) = GPUArraysCore.@allowscalar only(x)
_safe_only(x) = only(x)

"""
    _device_like(dst, src)

Return `src` in a form that can be broadcast into `dst` without a device/host mismatch.

Augmented Hamiltonian flows split into `[∂p; -∂x; -∂pv]`; on GPU the state blocks
`∂x`/`∂p` are device-resident (built from a device state) but `∂pv = -∂H/∂v` is **host**
(the variable `v` transits host-side, per the D4 rule), so broadcasting it into a device
`du` slice wraps a non-`isbits` host `Vector` in a `Broadcasted` and fails to compile
(`GPUCompiler.KernelError`). `_device_like` copies **only** that host block onto the device
matching `dst`; on host, and for already-device blocks, it is the identity (no copy).

Dispatch is on the array actually received at the call site, so CPU behaviour is byte-for-byte
unchanged and only the degenerate device-`dst`/host-`src` case pays a tiny `O(n_v)` H2D copy.
Backend-agnostic (`GPUArraysCore.AbstractGPUArray` covers CUDA/AMDGPU/Metal).

See also: [`CTFlows.Systems._aug_assign!`](@ref), [`CTFlows.Systems._safe_only`](@ref).
"""
_device_like(::AbstractArray, src) = src
_device_like(::GPUArraysCore.AbstractGPUArray, src::Number) = src
_device_like(::GPUArraysCore.AbstractGPUArray, src::GPUArraysCore.AbstractGPUArray) = src
function _device_like(dst::GPUArraysCore.AbstractGPUArray, src::AbstractArray)
    return copyto!(similar(dst, eltype(src), size(src)), src)
end
