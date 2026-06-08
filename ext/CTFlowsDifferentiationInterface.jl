"""
    CTFlowsDifferentiationInterface

Package extension providing DifferentiationInterface.jl backend implementations
for automatic differentiation in CTFlows Hamiltonian systems.

Activated automatically when `DifferentiationInterface` is loaded together with `CTFlows`.

This extension provides:
- `Differentiation.hamiltonian_gradient` — Hamiltonian gradient (∂H/∂x, ∂H/∂p) via DI
- `Differentiation.variable_gradient` — variable gradient ∂H/∂v via DI
- `Differentiation.gradient` / `Differentiation.derivative` — general AD primitives
- `Differentiation.differentiate` / `Differentiation.pushforward` — partial derivative / JVP primitives
"""
module CTFlowsDifferentiationInterface

import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
using CTFlows: CTFlows
using CTFlows.Data: Data
using CTFlows.Differentiation: Differentiation
using DifferentiationInterface: DifferentiationInterface as DI

# ==============================================================================
# Differentiation.hamiltonian_gradient / variable_gradient
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Return the scalar DI differentiation primitive for a `Number` active argument.

Dispatches to `DI.derivative`, which computes `df/dx` for scalar `x`.

See also: [`_derivator(::Type{<:AbstractArray})`](@ref)
"""
function _derivator(::Type{<:Number})
    return DI.derivative
end

"""
$(TYPEDSIGNATURES)

Return the array DI differentiation primitive for an `AbstractArray` active argument.

Dispatches to `DI.gradient`, which computes `∇f` for array `x`.

See also: [`_derivator(::Type{<:Number})`](@ref)
"""
function _derivator(::Type{<:AbstractArray})
    return DI.gradient
end

"""
$(TYPEDSIGNATURES)

Compute Hamiltonian gradients (∂H/∂x, ∂H/∂p) via DifferentiationInterface.jl.

# Returns
- Tuple `(grad_x, grad_p)` where `grad_x` = ∂H/∂x, `grad_p` = ∂H/∂p.
"""
function Differentiation.hamiltonian_gradient(
    backend::Differentiation.DifferentiationInterface,
    h::Data.AbstractHamiltonian,
    t, x, p, v,
)
    di_backend = Differentiation.ad_backend(backend)
    h_x = Differentiation.WithActiveArg(h, Val(2))
    h_p = Differentiation.WithActiveArg(h, Val(3))
    grad_x = _derivator(typeof(x))(h_x, di_backend, x, DI.Constant(t), DI.Constant(p), DI.Constant(v))
    grad_p = _derivator(typeof(p))(h_p, di_backend, p, DI.Constant(t), DI.Constant(x), DI.Constant(v))
    return (grad_x, grad_p)
end

"""
$(TYPEDSIGNATURES)

Compute variable gradient ∂H/∂v via DifferentiationInterface.jl.

# Returns
- `grad_v` = ∂H/∂v.
"""
function Differentiation.variable_gradient(
    backend::Differentiation.DifferentiationInterface,
    h::Data.AbstractHamiltonian,
    t, x, p, v,
)
    di_backend = Differentiation.ad_backend(backend)
    h_v = Differentiation.WithActiveArg(h, Val(4))
    return _derivator(typeof(v))(h_v, di_backend, v, DI.Constant(t), DI.Constant(x), DI.Constant(p))
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

Compute the partial gradient of `f` with respect to the array argument at slot `Slot`,
using DifferentiationInterface.jl.

`active` must be an `AbstractArray` and `f` must be scalar-valued. Internally constructs
a `WithActiveArg(f, Val(Slot))` functor and calls `DI.gradient` directly with the remaining
arguments wrapped as `DI.Constant`. Dispatching directly to `DI.gradient` (rather than
through the `_derivator` value-dispatch helper) allows Julia to infer the return type when
the AD backend is concrete (ensured by the `Val`-keyed `ad_backend` accessor).

See also: [`CTFlows.Differentiation.pushforward`](@ref).
"""
function Differentiation.differentiate(
    backend::Differentiation.DifferentiationInterface,
    f,
    ::Val{Slot},
    active::AbstractArray,
    consts...,
) where {Slot}
    di = Differentiation.ad_backend(backend)
    w  = Differentiation.WithActiveArg(f, Val(Slot))
    return DI.gradient(w, di, active, map(DI.Constant, consts)...)
end

"""
$(TYPEDSIGNATURES)

Compute the partial derivative of `f` with respect to the scalar argument at slot `Slot`,
using DifferentiationInterface.jl.

`active` is a scalar (e.g., time `t` in `∂ₜ`). `f` may be vector-valued, so the return
type is the output type of `f`, which differs from `typeof(active)` — no type assertion
is applied. Internally constructs a `WithActiveArg(f, Val(Slot))` functor and calls
`DI.derivative` with the remaining arguments wrapped as `DI.Constant`.

See also: [`CTFlows.Differentiation.pushforward`](@ref).
"""
function Differentiation.differentiate(
    backend::Differentiation.DifferentiationInterface,
    f,
    ::Val{Slot},
    active::Number,
    consts...,
) where {Slot}
    di = Differentiation.ad_backend(backend)
    w  = Differentiation.WithActiveArg(f, Val(Slot))
    return DI.derivative(w, di, active, map(DI.Constant, consts)...)
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

end # module
