"""
    CTFlowsDifferentiationInterface

Package extension providing DifferentiationInterface.jl backend implementations
for automatic differentiation in CTFlows Hamiltonian systems.

Activated automatically when `DifferentiationInterface` is loaded together with `CTFlows`.

This extension provides:
- `DifferentiationInterfaceCache` — prepared gradient plans for efficient repeated computation
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
import CTSolvers

# ==============================================================================
# DifferentiationInterfaceCache — Prepared gradient plans
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
mutable struct DifferentiationInterfaceCache{HX, HP, HV} <: Common.AbstractCache
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

Prepare a gradient cache for the `DifferentiationInterface` backend.

# Arguments
- `backend::Differentiation.DifferentiationInterface`: The AD backend.
- `h::Data.AbstractHamiltonian`: The Hamiltonian function.
- `typical_x`: Typical initial state value (for type inference).
- `typical_p`: Typical initial costate value (for type inference).
- `typical_v`: Typical variable value (for type inference; `nothing` for Fixed problems).

# Returns
- `DifferentiationInterfaceCache` if `prepare_cache=true` option is set.
- `nothing` if `prepare_cache=false` option is set (gradient methods fall back to plain `DI.gradient`).

# Behavior
When the `prepare_cache` option is `true` (default), this function:
1. Extracts the DI backend and `do_prepare` flag from the strategy options.
2. Calls `DI.prepare_gradient` for each variable (∂H/∂x, ∂H/∂p, ∂H/∂v).
3. Returns a `DifferentiationInterfaceCache` storing the prepared plans.

When `prepare_cache` is `false`, returns `nothing` and gradient methods compute
gradients on-the-fly using plain `DI.gradient`.

# See also
- [`CTFlowsDifferentiationInterface.DifferentiationInterfaceCache`](@ref)
- [`CTFlows.Differentiation.hamiltonian_gradient`](@ref)
"""
function Differentiation.prepare_cache(
    backend::Differentiation.DifferentiationInterface,
    h::Data.AbstractHamiltonian,
    typical_t, typical_x, typical_p, typical_v
)
    opts       = CTSolvers.Strategies.options(backend)
    di_backend = opts[:ad_backend]
    do_prepare = opts[:prepare_cache]

    if do_prepare
        h_x(x, t, p, v) = h(t, x, p, v)
        h_p(p, t, x, v) = h(t, x, p, v)
        h_v(v, t, x, p) = h(t, x, p, v)
        p_x = DI.prepare_gradient(h_x, di_backend, typical_x, DI.Constant(typical_t), DI.Constant(typical_p), DI.Constant(typical_v))
        p_p = DI.prepare_gradient(h_p, di_backend, typical_p, DI.Constant(typical_t), DI.Constant(typical_x), DI.Constant(typical_v))
        p_v = if typical_v === nothing
            nothing
        else
            DI.prepare_gradient(h_v, di_backend, typical_v, DI.Constant(typical_t), DI.Constant(typical_x), DI.Constant(typical_p))
        end
        return DifferentiationInterfaceCache(p_x, p_p, p_v, h_x, h_p, h_v)
    else
        return nothing   # caller gets Nothing; gradient methods fall back to plain DI.gradient
    end
end

function update!(cache::DifferentiationInterfaceCache, backend::Differentiation.DifferentiationInterface, t, x, p, v)
    opts = CTSolvers.Strategies.options(backend)
    di_backend = opts[:ad_backend]
    do_prepare = opts[:prepare_cache]
    if !do_prepare
        return nothing
    end
    p_x = DI.prepare_gradient(cache.h_x, di_backend, x, DI.Constant(t), DI.Constant(p), DI.Constant(v))
    p_p = DI.prepare_gradient(cache.h_p, di_backend, p, DI.Constant(t), DI.Constant(x), DI.Constant(v))
    p_v = if v === nothing
        nothing
    else
        DI.prepare_gradient(cache.h_v, di_backend, v, DI.Constant(t), DI.Constant(x), DI.Constant(p))
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
- [`CTFlowsDifferentiationInterface.DifferentiationInterfaceCache`](@ref)
- [`CTFlows.Differentiation.prepare_cache`](@ref)
"""
function Differentiation.hamiltonian_gradient(
    backend::Differentiation.DifferentiationInterface, h, t, x, p, v,
    ::Nothing
)
    di_backend = CTSolvers.Strategies.options(backend)[:ad_backend]
    h_x(x, t, p, v) = h(t, x, p, v)
    h_p(p, t, x, v) = h(t, x, p, v)
    grad_x = DI.gradient(h_x, di_backend, x, DI.Constant(t), DI.Constant(p), DI.Constant(v))
    grad_p = DI.gradient(h_p, di_backend, p, DI.Constant(t), DI.Constant(x), DI.Constant(v))
    return (grad_x, grad_p)
end

"""
$(TYPEDSIGNATURES)

Compute Hamiltonian gradients (∂H/∂x, ∂H/∂p) using prepared gradient plans.

This overload is used when `cache::DifferentiationInterfaceCache`, i.e., when
the `prepare_cache` option is `true` and the cache was prepared at flow call time.

# Arguments
- `backend::Differentiation.DifferentiationInterface`: The AD backend.
- `h`: The Hamiltonian function.
- `t`: Time.
- `x`: State.
- `p`: Costate.
- `v`: Variable (or `nothing` for Fixed problems).
- `cache::DifferentiationInterfaceCache`: Prepared gradient plans from `prepare_cache`.

# Returns
- Tuple `(grad_x, grad_p)` where:
  - `grad_x` = ∂H/∂x
  - `grad_p` = ∂H/∂p

# Performance
Uses the prepared plans stored in `cache.prep_x` and `cache.prep_p` for efficient
repeated gradient computation during ODE integration.

# See also
- [`CTFlowsDifferentiationInterface.DifferentiationInterfaceCache`](@ref)
- [`CTFlows.Differentiation.prepare_cache`](@ref)
"""
function Differentiation.hamiltonian_gradient(
    backend::Differentiation.DifferentiationInterface, h, t, x, p, v,
    cache::DifferentiationInterfaceCache
)
    di_backend = CTSolvers.Strategies.options(backend)[:ad_backend]
    try
        grad_x = DI.gradient(cache.h_x, cache.p_x, di_backend, x, DI.Constant(t), DI.Constant(p), DI.Constant(v))
        grad_p = DI.gradient(cache.h_p, cache.p_p, di_backend, p, DI.Constant(t), DI.Constant(x), DI.Constant(v))
        return (grad_x, grad_p)
    catch e
        if e isa DI.PreparationMismatchError
            update!(cache, backend, t, x, p, v) # recompute cache
            grad_x = DI.gradient(cache.h_x, cache.p_x, di_backend, x, DI.Constant(t), DI.Constant(p), DI.Constant(v))
            grad_p = DI.gradient(cache.h_p, cache.p_p, di_backend, p, DI.Constant(t), DI.Constant(x), DI.Constant(v))
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
- [`CTFlowsDifferentiationInterface.DifferentiationInterfaceCache`](@ref)
- [`CTFlows.Differentiation.prepare_cache`](@ref)
"""
function Differentiation.variable_gradient(
    backend::Differentiation.DifferentiationInterface, h, t, x, p, v,
    ::Nothing
)
    # For Fixed problems (v === nothing), return nothing without calling DI.gradient
    di_backend = CTSolvers.Strategies.options(backend)[:ad_backend]
    h_v(v, t, x, p) = h(t, x, p, v)
    grad_v = DI.gradient(h_v, di_backend, v, DI.Constant(t), DI.Constant(x), DI.Constant(p))
    return grad_v
end

"""
$(TYPEDSIGNATURES)

Compute variable gradient (∂H/∂v) using prepared gradient plans.

This overload is used when `cache::DifferentiationInterfaceCache`, i.e., when
the `prepare_cache` option is `true` and the cache was prepared at flow call time.

# Arguments
- `backend::Differentiation.DifferentiationInterface`: The AD backend.
- `h`: The Hamiltonian function.
- `t`: Time.
- `x`: State.
- `p`: Costate.
- `v`: Variable (or `nothing` for Fixed problems).
- `cache::DifferentiationInterfaceCache`: Prepared gradient plans from `prepare_cache`.

# Returns
- `nothing` for Fixed problems (`v === nothing`).
- `grad_v` = ∂H/∂v for NonFixed problems.

# Performance
Uses the prepared plan stored in `cache.prep_v` for efficient repeated gradient
computation during ODE integration.

# See also
- [`CTFlowsDifferentiationInterface.DifferentiationInterfaceCache`](@ref)
- [`CTFlows.Differentiation.prepare_cache`](@ref)
"""
function Differentiation.variable_gradient(
    backend::Differentiation.DifferentiationInterface, h, t, x, p, v,
    cache::DifferentiationInterfaceCache
)
    di_backend = CTSolvers.Strategies.options(backend)[:ad_backend]
    try 
        grad_v = DI.gradient(cache.h_v, cache.p_v, di_backend, v, DI.Constant(t), DI.Constant(x), DI.Constant(p))
        return grad_v
    catch e
        if e isa DI.PreparationMismatchError
            update!(cache, backend, t, x, p, v) # recompute cache
            grad_v = DI.gradient(cache.h_v, cache.p_v, di_backend, v, DI.Constant(t), DI.Constant(x), DI.Constant(p))
            return grad_v
        else
            rethrow(e)
        end
    end
end

end # module
