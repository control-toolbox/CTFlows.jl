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
