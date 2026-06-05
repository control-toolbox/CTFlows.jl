"""
    CTFlowsDifferentiationInterface

Package extension providing DifferentiationInterface.jl backend implementations
for automatic differentiation in CTFlows Hamiltonian systems.

Activated automatically when `DifferentiationInterface` is loaded together with `CTFlows`.

This extension provides:
- `_DifferentiationInterfaceCache` — prepared gradient plans for efficient repeated computation
- `Differentiation.prepare_cache` — cache preparation for `DifferentiationInterface` backend
- `Differentiation.hamiltonian_gradient` — gradient computation with/without cache
- `Differentiation.variable_gradient` — variable gradient with/without cache
"""
module CTFlowsDifferentiationInterface

import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
using CTFlows: CTFlows
using CTFlows.Common: Common
using CTFlows.Data: Data
using CTFlows.Differentiation: Differentiation
using DifferentiationInterface: DifferentiationInterface as DI

# ==============================================================================
# _DifferentiationInterfaceCache — Prepared gradient plans
# ==============================================================================

"""
$(TYPEDEF)

Cache for DifferentiationInterface.jl backend, storing prepared gradient plans
for efficient repeated computation of Hamiltonian gradients.

# Fields
- `prep_x::PX`: Prepared plan for ∂H/∂x (or `Nothing` if not prepared)
- `prep_p::PP`: Prepared plan for ∂H/∂p (or `Nothing` if not prepared)
- `prep_v::PV`: Prepared plan for ∂H/∂v (`Nothing` for Fixed problems)

# See also
- [`CTFlows.Differentiation.prepare_cache`](@ref)
- [`CTFlows.Differentiation.hamiltonian_gradient`](@ref)
"""
mutable struct _DifferentiationInterfaceCache{HX, HP, HV} <: Common.AbstractCache
    p_x   # DI prepared plan for ∂H/∂x (or Nothing)
    p_p   # DI prepared plan for ∂H/∂p (or Nothing)
    p_v   # DI prepared plan for ∂H/∂v (Nothing if Fixed)
    h_x::HX   # Hamiltonian function for ∂H/∂x
    h_p::HP   # Hamiltonian function for ∂H/∂p
    h_v::HV   # Hamiltonian function for ∂H/∂v
end

# ==============================================================================
# Differentiation.prepare_cache — cache preparation for DifferentiationInterface
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Return the appropriate DifferentiationInterface preparation function for scalar types.

# Arguments
- `::Type{<:Number}`: A scalar type.

# Returns
- `DI.prepare_derivative`: The preparation function for scalar derivatives.

# Notes
- Internal helper used by `Differentiation.prepare_cache`.
- Dispatches to `DI.prepare_derivative` for scalar types.

See also: [`CTFlows.Differentiation.prepare_cache`](@ref), [`_derivator`](@ref).
"""
function _preparator(::Type{<:Number})
    return DI.prepare_derivative
end

"""
$(TYPEDSIGNATURES)

Return the appropriate DifferentiationInterface preparation function for array types.

# Arguments
- `::Type{<:AbstractArray}`: An array type.

# Returns
- `DI.prepare_gradient`: The preparation function for array gradients.

# Notes
- Internal helper used by `Differentiation.prepare_cache`.
- Dispatches to `DI.prepare_gradient` for array types.

See also: [`CTFlows.Differentiation.prepare_cache`](@ref), [`_derivator`](@ref).
"""
function _preparator(::Type{<:AbstractArray})
    return DI.prepare_gradient
end


"""
$(TYPEDSIGNATURES)

Prepare a gradient cache for the `DifferentiationInterface` backend.

# Arguments
- `backend::Differentiation.DifferentiationInterface`: The AD backend.
- `h::Data.AbstractHamiltonian`: The Hamiltonian function.
- `typical_x`: Typical initial state value (for type inference).
- `typical_p`: Typical initial costate value (for type inference).
- `typical_v`: Typical variable value (for type inference; `nothing` for Fixed problems).

# Returns
- `_DifferentiationInterfaceCache` if `prepare_cache=true` option is set.
- `nothing` if `prepare_cache=false` option is set (gradient methods fall back to plain `DI.gradient`).

# Behavior
When the `prepare_cache` option is `true` (default), this function:
1. Extracts the DI backend and `do_prepare` flag from the strategy options.
2. Calls `DI.prepare_gradient` for each variable (∂H/∂x, ∂H/∂p, ∂H/∂v).
3. Returns a `_DifferentiationInterfaceCache` storing the prepared plans.

When `prepare_cache` is `false`, returns `nothing` and gradient methods compute
gradients on-the-fly using plain `DI.gradient`.

# See also
- `_DifferentiationInterfaceCache`
- [`CTFlows.Differentiation.hamiltonian_gradient`](@ref)
"""
function Differentiation.prepare_cache(
    backend::Differentiation.DifferentiationInterface,
    h::Data.AbstractHamiltonian,
    typical_t, typical_x, typical_p, typical_v
)
    di_backend = Differentiation.ad_backend(backend)
    do_prepare = Differentiation.prepare_cache(backend)

    if do_prepare
        h_x(x, t, p, v) = h(t, x, p, v)
        h_p(p, t, x, v) = h(t, x, p, v)
        h_v(v, t, x, p) = h(t, x, p, v)
        p_x = _preparator(typeof(typical_x))(h_x, di_backend, typical_x, DI.Constant(typical_t), DI.Constant(typical_p), DI.Constant(typical_v))
        p_p = _preparator(typeof(typical_p))(h_p, di_backend, typical_p, DI.Constant(typical_t), DI.Constant(typical_x), DI.Constant(typical_v))
        p_v = if typical_v === nothing
            nothing
        else
            _preparator(typeof(typical_v))(h_v, di_backend, typical_v, DI.Constant(typical_t), DI.Constant(typical_x), DI.Constant(typical_p))
        end
        return _DifferentiationInterfaceCache(p_x, p_p, p_v, h_x, h_p, h_v)
    else
        return nothing   # caller gets Nothing; gradient methods fall back to plain DI.gradient
    end
end

function Differentiation.update!(cache::_DifferentiationInterfaceCache, backend::Differentiation.DifferentiationInterface, t, x, p, v)
    on_update = Differentiation.on_update(backend)
    isnothing(on_update) || on_update(cache, t, x, p, v)
    di_backend = Differentiation.ad_backend(backend)
    do_prepare = Differentiation.prepare_cache(backend)
    if !do_prepare
        return nothing
    end
    p_x = _preparator(typeof(x))(cache.h_x, di_backend, x, DI.Constant(t), DI.Constant(p), DI.Constant(v))
    p_p = _preparator(typeof(p))(cache.h_p, di_backend, p, DI.Constant(t), DI.Constant(x), DI.Constant(v))
    p_v = if v === nothing
        nothing
    else
        _preparator(typeof(v))(cache.h_v, di_backend, v, DI.Constant(t), DI.Constant(x), DI.Constant(p))
    end
    cache.p_x = p_x
    cache.p_p = p_p
    cache.p_v = p_v
    return nothing
end

# ==============================================================================
# Differentiation.hamiltonian_gradient — with/without cache
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Return the appropriate DifferentiationInterface computation function for scalar types.

# Arguments
- `::Type{<:Number}`: A scalar type.

# Returns
- `DI.derivative`: The derivative computation function for scalars.

# Notes
- Internal helper used by gradient computation methods.
- Dispatches to `DI.derivative` for scalar types.

See also: [`CTFlows.Differentiation.hamiltonian_gradient`](@ref), [`CTFlows.Differentiation.variable_gradient`](@ref), [`_preparator`](@ref).
"""
function _derivator(::Type{<:Number})
    return DI.derivative
end

"""
$(TYPEDSIGNATURES)

Return the appropriate DifferentiationInterface computation function for array types.

# Arguments
- `::Type{<:AbstractArray}`: An array type.

# Returns
- `DI.gradient`: The gradient computation function for arrays.

# Notes
- Internal helper used by gradient computation methods.
- Dispatches to `DI.gradient` for array types.

See also: [`CTFlows.Differentiation.hamiltonian_gradient`](@ref), [`CTFlows.Differentiation.variable_gradient`](@ref), [`_preparator`](@ref).
"""
function _derivator(::Type{<:AbstractArray})
    return DI.gradient
end

"""
$(TYPEDSIGNATURES)

Compute Hamiltonian gradients (∂H/∂x, ∂H/∂p) using plain `DI.gradient` (no cache).

This overload is used when `cache::Nothing`, i.e., when the `prepare_cache` option
is `false` or when the system does not require cache preparation.

# Arguments
- `backend::Differentiation.DifferentiationInterface`: The AD backend.
- `h`: The Hamiltonian function.
- `t`: Time.
- `x`: State.
- `p`: Costate.
- `v`: Variable (or `nothing` for Fixed problems).
- `::Nothing`: No prepared plan available.

# Returns
- Tuple `(grad_x, grad_p)` where:
  - `grad_x` = ∂H/∂x
  - `grad_p` = ∂H/∂p

# See also
- `_DifferentiationInterfaceCache`
- [`CTFlows.Differentiation.prepare_cache`](@ref)
"""
function Differentiation.hamiltonian_gradient(
    backend::Differentiation.DifferentiationInterface, 
    h::Data.AbstractHamiltonian, 
    t, x, p, v,
    ::Nothing
)
    di_backend = Differentiation.ad_backend(backend)
    h_x(x, t, p, v) = h(t, x, p, v)
    h_p(p, t, x, v) = h(t, x, p, v)
    # Use derivative for scalars, gradient for arrays
    grad_x = _derivator(typeof(x))(h_x, di_backend, x, DI.Constant(t), DI.Constant(p), DI.Constant(v))
    grad_p = _derivator(typeof(p))(h_p, di_backend, p, DI.Constant(t), DI.Constant(x), DI.Constant(v))
    return (grad_x, grad_p)
end

"""
$(TYPEDSIGNATURES)

Compute Hamiltonian gradients (∂H/∂x, ∂H/∂p) using prepared gradient plans.

This overload is used when `cache::_DifferentiationInterfaceCache`, i.e., when
the `prepare_cache` option is `true` and the cache was prepared at flow call time.

# Arguments
- `backend::Differentiation.DifferentiationInterface`: The AD backend.
- `h`: The Hamiltonian function.
- `t`: Time.
- `x`: State.
- `p`: Costate.
- `v`: Variable (or `nothing` for Fixed problems).
- `cache::_DifferentiationInterfaceCache`: Prepared gradient plans from `prepare_cache`.

# Returns
- Tuple `(grad_x, grad_p)` where:
  - `grad_x` = ∂H/∂x
  - `grad_p` = ∂H/∂p

# Performance
Uses the prepared plans stored in `cache.prep_x` and `cache.prep_p` for efficient
repeated gradient computation during ODE integration.

# See also
- `_DifferentiationInterfaceCache`
- [`CTFlows.Differentiation.prepare_cache`](@ref)
"""
function Differentiation.hamiltonian_gradient(
    backend::Differentiation.DifferentiationInterface, 
    h::Data.AbstractHamiltonian, 
    t, x, p, v,
    cache::_DifferentiationInterfaceCache
)
    di_backend = Differentiation.ad_backend(backend)
    try
        # Use derivative for scalars, gradient for arrays
        grad_x = _derivator(typeof(x))(cache.h_x, cache.p_x, di_backend, x, DI.Constant(t), DI.Constant(p), DI.Constant(v))
        grad_p = _derivator(typeof(p))(cache.h_p, cache.p_p, di_backend, p, DI.Constant(t), DI.Constant(x), DI.Constant(v))
        return (grad_x, grad_p)
    catch e
        if e isa DI.PreparationMismatchError
            Differentiation.update!(cache, backend, t, x, p, v) # recompute cache
            grad_x = _derivator(typeof(x))(cache.h_x, cache.p_x, di_backend, x, DI.Constant(t), DI.Constant(p), DI.Constant(v))
            grad_p = _derivator(typeof(p))(cache.h_p, cache.p_p, di_backend, p, DI.Constant(t), DI.Constant(x), DI.Constant(v))
            return (grad_x, grad_p)
        else
            rethrow(e)
        end
    end
end

# ==============================================================================
# Differentiation.variable_gradient — with/without cache
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Compute variable gradient (∂H/∂v) using plain `DI.gradient` (no cache).

This overload is used when `cache::Nothing`, i.e., when the `prepare_cache` option
is `false` or when the system does not require cache preparation.

# Arguments
- `backend::Differentiation.DifferentiationInterface`: The AD backend.
- `h`: The Hamiltonian function.
- `t`: Time.
- `x`: State.
- `p`: Costate.
- `v`: Variable (or `nothing` for Fixed problems).
- `cache::Nothing`: No prepared plan available.

# Returns
- `nothing` for Fixed problems (`v === nothing`).
- `grad_v` = ∂H/∂v for NonFixed problems.

# See also
- `_DifferentiationInterfaceCache`
- [`CTFlows.Differentiation.prepare_cache`](@ref)
"""
function Differentiation.variable_gradient(
    backend::Differentiation.DifferentiationInterface, 
    h::Data.AbstractHamiltonian, 
    t, x, p, v,
    ::Nothing
)
    # For Fixed problems (v === nothing), return nothing without calling DI.gradient
    di_backend = Differentiation.ad_backend(backend)
    h_v(v, t, x, p) = h(t, x, p, v)
    # Use derivative for scalars, gradient for arrays
    grad_v = _derivator(typeof(v))(h_v, di_backend, v, DI.Constant(t), DI.Constant(x), DI.Constant(p))
    return grad_v
end

"""
$(TYPEDSIGNATURES)

Compute variable gradient (∂H/∂v) using prepared gradient plans.

This overload is used when `cache::_DifferentiationInterfaceCache`, i.e., when
the `prepare_cache` option is `true` and the cache was prepared at flow call time.

# Arguments
- `backend::Differentiation.DifferentiationInterface`: The AD backend.
- `h`: The Hamiltonian function.
- `t`: Time.
- `x`: State.
- `p`: Costate.
- `v`: Variable (or `nothing` for Fixed problems).
- `cache::_DifferentiationInterfaceCache`: Prepared gradient plans from `prepare_cache`.

# Returns
- `nothing` for Fixed problems (`v === nothing`).
- `grad_v` = ∂H/∂v for NonFixed problems.

# Performance
Uses the prepared plan stored in `cache.prep_v` for efficient repeated gradient
computation during ODE integration.

# See also
- `_DifferentiationInterfaceCache`
- [`CTFlows.Differentiation.prepare_cache`](@ref)
"""
function Differentiation.variable_gradient(
    backend::Differentiation.DifferentiationInterface, 
    h::Data.AbstractHamiltonian, 
    t, x, p, v,
    cache::_DifferentiationInterfaceCache
)
    di_backend = Differentiation.ad_backend(backend)
    try 
        # Use derivative for scalars, gradient for arrays
        grad_v = _derivator(typeof(v))(cache.h_v, cache.p_v, di_backend, v, DI.Constant(t), DI.Constant(x), DI.Constant(p))
        return grad_v
    catch e
        if e isa DI.PreparationMismatchError
            Differentiation.update!(cache, backend, t, x, p, v) # recompute cache
            grad_v = _derivator(typeof(v))(cache.h_v, cache.p_v, di_backend, v, DI.Constant(t), DI.Constant(x), DI.Constant(p))
            return grad_v
        else
            rethrow(e)
        end
    end
end

# =============================================================================
# Differentiation.gradient — extension contract methods
# =============================================================================

"""
$(TYPEDSIGNATURES)

Compute the gradient of a scalar function using DifferentiationInterface.jl.

# Arguments
- `backend::Differentiation.DifferentiationInterface`: The AD backend.
- `f::Function`: The scalar function to differentiate.
- `x::AbstractArray`: The input vector.

# Returns
- `∇f`: The gradient of `f` at `x`.

# See also
- [`CTFlows.Differentiation.derivative`](@ref)
"""
function Differentiation.gradient(
    backend::Differentiation.DifferentiationInterface,
    f::Function,
    x::AbstractArray,
)
    ad = Differentiation.ad_backend(backend)
    return DI.gradient(f, ad, x)
end

"""
$(TYPEDSIGNATURES)

Compute the gradient of a scalar function using DifferentiationInterface.jl (scalar case).

# Arguments
- `backend::Differentiation.DifferentiationInterface`: The AD backend.
- `f::Function`: The scalar function to differentiate.
- `x::Real`: The input scalar.

# Returns
- `df/dx`: The derivative of `f` at `x`.

# See also
- [`CTFlows.Differentiation.derivative`](@ref)
"""
function Differentiation.gradient(
    backend::Differentiation.DifferentiationInterface,
    f::Function,
    x::Real,
)
    ad = Differentiation.ad_backend(backend)
    return DI.derivative(f, ad, x)
end

"""
$(TYPEDSIGNATURES)

Compute the derivative of a scalar function using DifferentiationInterface.jl.

# Arguments
- `backend::Differentiation.DifferentiationInterface`: The AD backend.
- `g::Function`: The scalar function to differentiate.
- `t::Real`: The input scalar.

# Returns
- `dg/dt`: The derivative of `g` at `t`.

# See also
- [`CTFlows.Differentiation.gradient`](@ref)
"""
function Differentiation.derivative(
    backend::Differentiation.DifferentiationInterface,
    g::Function,
    t::Real,
)
    ad = Differentiation.ad_backend(backend)
    return DI.derivative(g, ad, t)
end

# =============================================================================
# Differentiation.differentiate / pushforward — new primitives
# =============================================================================

"""
$(TYPEDSIGNATURES)

Compute the partial derivative or gradient of `f` with respect to the argument at
slot `Slot`, using DifferentiationInterface.jl.

Internally constructs a `WithActiveArg(f, Val(Slot))` functor, then calls
`DI.gradient` (array) or `DI.derivative` (scalar) with the remaining arguments
wrapped as `DI.Constant`.

See also: [`CTFlows.Differentiation.pushforward`](@ref).
"""
function Differentiation.differentiate(
    backend::Differentiation.DifferentiationInterface,
    f,
    ::Val{Slot},
    active,
    consts...,
) where {Slot}
    di = Differentiation.ad_backend(backend)
    w  = Differentiation.WithActiveArg(f, Val(Slot))
    return _derivator(typeof(active))(w, di, active, map(DI.Constant, consts)...)
end

"""
$(TYPEDSIGNATURES)

Compute the pushforward (Jacobian-vector product) of `f` at `x` in direction `dx`,
using DifferentiationInterface.jl.

Internally constructs a `WithActiveArg(f, Val(Slot))` functor, then calls
`DI.pushforward` with the direction as a one-element tuple and remaining arguments
wrapped as `DI.Constant`. The single tangent is extracted with `only`.

See also: [`CTFlows.Differentiation.differentiate`](@ref).
"""
function Differentiation.pushforward(
    backend::Differentiation.DifferentiationInterface,
    f,
    ::Val{Slot},
    x,
    dx,
    consts...,
) where {Slot}
    di = Differentiation.ad_backend(backend)
    w  = Differentiation.WithActiveArg(f, Val(Slot))
    ty = DI.pushforward(w, di, x, (dx,), map(DI.Constant, consts)...)
    return only(ty)
end

# =============================================================================
# Base.show
# =============================================================================

"""
    Base.show(io::IO, cache::_DifferentiationInterfaceCache)

Display a compact representation of a _DifferentiationInterfaceCache.

Shows the preparation status for each gradient plan and the update count.

# Arguments
- `io::IO`: The IO stream.
- `cache::_DifferentiationInterfaceCache`: The cache to display.

# Output
Displays three lines:
- Header with type name
- Preparation status for ∂H/∂x
- Preparation status for ∂H/∂p
- Preparation status for ∂H/∂v (or "not prepared" for Fixed problems)

# Example
```julia-repl
julia> cache
_DifferentiationInterfaceCache
  ∂H/∂x: prepared
  ∂H/∂p: prepared
  ∂H/∂v: prepared
```
"""
function Base.show(io::IO, cache::_DifferentiationInterfaceCache)
    println(io, "_DifferentiationInterfaceCache")
    println(io, "  ∂H/∂x: ", _prep_status(cache.p_x))
    println(io, "  ∂H/∂p: ", _prep_status(cache.p_p))
    print(io, "  ∂H/∂v: ", _prep_status(cache.p_v))
end

"""
    Base.show(io::IO, ::MIME"text/plain", cache::_DifferentiationInterfaceCache)

Display a _DifferentiationInterfaceCache in the REPL with the same format as `Base.show(io, cache)`.

# Arguments
- `io::IO`: The IO stream.
- `::MIME"text/plain"`: The MIME type.
- `cache::_DifferentiationInterfaceCache`: The cache to display.

See also: `Base.show`.
"""
function Base.show(io::IO, ::MIME"text/plain", cache::_DifferentiationInterfaceCache)
    show(io, cache)
end

"""
    _prep_status(prep)

Return a string describing the preparation status of a gradient plan.

# Arguments
- `prep`: The prepared plan (or `Nothing`).

# Returns
- `"prepared"` if the plan is not `Nothing`.
- `"not prepared"` if the plan is `Nothing`.
"""
_prep_status(prep) = prep === nothing ? "not prepared" : "prepared"

end # module
