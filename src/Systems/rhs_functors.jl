# =============================================================================
# RHS Functors for VectorFieldSystem
# =============================================================================

# =============================================================================
# Abstract types
# =============================================================================

"""
    AbstractRHS{T<:Traits.AbstractMutabilityTrait}

Abstract supertype for all RHS functors.

Parameterized by the interface mutability trait:
- `Traits.InPlace`: in-place interface `(du, u, λ, t) -> nothing`
- `Traits.OutOfPlace`: out-of-place interface `(u, λ, t) -> du`
"""
abstract type AbstractRHS{T<:Traits.AbstractMutabilityTrait} end

"""
    AbstractIPRHS <: AbstractRHS{Traits.InPlace}

Abstract supertype for in-place RHS functors.

These functors have the signature `(du, u, λ, t) -> nothing` and
modify `du` in place.
"""
abstract type AbstractIPRHS <: AbstractRHS{Traits.InPlace} end

"""
    AbstractOoPRHS <: AbstractRHS{Traits.OutOfPlace}

Abstract supertype for out-of-place RHS functors.

These functors have the signature `(u, λ, t) -> du` and return
a new array without modifying the input.
"""
abstract type AbstractOoPRHS <: AbstractRHS{Traits.OutOfPlace} end

# =============================================================================
# Concrete functors
# =============================================================================

"""
    IPVFOoPRHS{VF<:Data.AbstractVectorField,CX} <: AbstractIPRHS

In-place RHS functor for an out-of-place vector field.

Wraps an out-of-place [`CTBase.Data.AbstractVectorField`](@extref) and provides an
in-place interface by allocating the result into the pre-allocated `du` buffer.

# Fields
- `vf::VF`: the wrapped out-of-place vector field (any `Data.AbstractVectorField`).
- `cx::CX`: coercion applied to the state before calling `vf` (`_safe_only` for a
  1-D state, `identity` otherwise) — see [`CTFlows.Systems._coerce_state`](@ref).

# Call signature
`(f::IPVFOoPRHS)(du, u, λ, t) -> nothing`

# Notes
- `du` is always the pre-allocated buffer supplied by the integrator, matching `u`'s
  actual (uncoerced) shape — broadcasting a coerced-scalar result into it is safe
  regardless of `cx` (the Handbook's documented "in-place buffer stays a vector"
  exception).
"""
struct IPVFOoPRHS{
    VF<:Data.AbstractVectorField,CX<:Union{typeof(_safe_only),typeof(identity)}
} <: AbstractIPRHS
    vf::VF
    cx::CX
end

function (f::IPVFOoPRHS)(du, u, λ, t)
    du .= f.vf(t, f.cx(u), variable(λ))
    return nothing
end

"""
    IPVFIpRHS{F,TD,VD,CX} <: AbstractIPRHS

In-place RHS functor for an in-place VectorField.

Wraps an in-place VectorField and provides an in-place interface
by directly calling the VectorField.

# Fields
- `vf::Data.VectorField{F,TD,VD,Traits.InPlace}`: The wrapped VectorField
- `cx::CX`: coercion applied to the state before calling `vf`.

# Call signature
`(f::IPVFIpRHS)(du, u, λ, t) -> nothing`
"""
struct IPVFIpRHS{
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    CX<:Union{typeof(_safe_only),typeof(identity)},
} <: AbstractIPRHS
    vf::Data.VectorField{F,TD,VD,Traits.InPlace}
    cx::CX
end

function (f::IPVFIpRHS)(du, u, λ, t)
    f.vf(du, t, f.cx(u), variable(λ))
    return nothing
end

"""
    OoPVFOoPRHS{VF<:Data.AbstractVectorField,CX} <: AbstractOoPRHS

Out-of-place RHS functor for an out-of-place vector field.

Wraps an out-of-place [`CTBase.Data.AbstractVectorField`](@extref) and provides an
out-of-place interface by directly calling the vector field.

# Fields
- `vf::VF`: the wrapped out-of-place vector field (any `Data.AbstractVectorField`).
- `cx::CX`: coercion applied to the state before calling `vf`.

# Call signature
`(f::OoPVFOoPRHS)(u, λ, t) -> du`

# Notes
- Unlike the Hamiltonian-family out-of-place functors (which always reassemble their
  return value via `vcat` of a state and a costate block, safe for either shape),
  this functor has a single block and nothing to reassemble: when `cx` collapses `u`
  to a scalar for the call, `vf` may return a bare scalar too, which does not match
  `u`'s own (uncoerced) container shape. That case is reshaped back explicitly so the
  returned derivative always matches `u`'s actual type, as SciML's out-of-place
  interface requires.
"""
struct OoPVFOoPRHS{
    VF<:Data.AbstractVectorField,CX<:Union{typeof(_safe_only),typeof(identity)}
} <: AbstractOoPRHS
    vf::VF
    cx::CX
end

function (f::OoPVFOoPRHS)(u, λ, t)
    du = f.vf(t, f.cx(u), variable(λ))
    if du isa Number && !(u isa Number)
        buf = similar(u)
        buf .= du
        return typeof(u)(buf)
    end
    return du
end

"""
    OoPVFIpRHS{F,TD,VD,CX} <: AbstractOoPRHS

Out-of-place RHS functor for an in-place VectorField.

Wraps an in-place VectorField and provides an out-of-place interface
by allocating a temporary buffer on each call.

# Fields
- `vf::Data.VectorField{F,TD,VD,Traits.InPlace}`: The wrapped VectorField
- `cx::CX`: coercion applied to the state before calling `vf`.

# Call signature
`(f::OoPVFIpRHS)(u, λ, t) -> du`

# Notes
- `dx = similar(u)` already matches `u`'s actual (uncoerced) shape, so no reshaping is
  needed here even when `cx` collapses the CALL argument to a scalar — the in-place
  `vf` call still writes into the properly-shaped buffer.
"""
struct OoPVFIpRHS{
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    CX<:Union{typeof(_safe_only),typeof(identity)},
} <: AbstractOoPRHS
    vf::Data.VectorField{F,TD,VD,Traits.InPlace}
    cx::CX
end

function (f::OoPVFIpRHS)(u, λ, t)
    dx = similar(u)
    f.vf(dx, t, f.cx(u), variable(λ))
    return dx
end

"""
    OoPVFIpFinalizeRHS{F,TD,VD,CX} <: AbstractOoPRHS

Out-of-place RHS functor for an in-place VectorField with type conversion.

Wraps an in-place VectorField and provides an out-of-place interface
that converts the result to match the input type (e.g., Vector → SVector).

# Fields
- `vf::Data.VectorField{F,TD,VD,Traits.InPlace}`: The wrapped VectorField
- `cx::CX`: coercion applied to the state before calling `vf`.

# Call signature
`(f::OoPVFIpFinalizeRHS)(u, λ, t) -> du`
"""
struct OoPVFIpFinalizeRHS{
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    CX<:Union{typeof(_safe_only),typeof(identity)},
} <: AbstractOoPRHS
    vf::Data.VectorField{F,TD,VD,Traits.InPlace}
    cx::CX
end

function (f::OoPVFIpFinalizeRHS)(u, λ, t)
    dx = similar(u)
    f.vf(dx, t, f.cx(u), variable(λ))
    return typeof(u)(dx)
end

# =============================================================================
# Display helpers
# =============================================================================

_rhs_conversion_label(f::IPVFOoPRHS) = "out-of-place VF → in-place interface"
_rhs_conversion_label(f::IPVFIpRHS) = "in-place VF → in-place interface"
_rhs_conversion_label(f::OoPVFOoPRHS) = "out-of-place VF → out-of-place interface"
_rhs_conversion_label(f::OoPVFIpRHS) = "in-place VF → out-of-place interface"
function _rhs_conversion_label(f::OoPVFIpFinalizeRHS)
    return "in-place VF → out-of-place interface + finalize"
end

function Base.show(io::IO, f::AbstractRHS)
    fmt = Display.format_codes(io)
    td = Traits.time_dependence(f.vf)
    vd = Traits.variable_dependence(f.vf)
    md = Traits.mutability(f.vf)
    wraps = "VectorField: $(Data._td_label(td)), $(Data._vd_label(vd)), $(Data._md_label(md))"
    Display.print_header(io, nameof(typeof(f)); fmt=fmt)
    Display.print_field(io, "wraps", wraps; fmt=fmt, value_style="")
    return Display.print_field(
        io, "converts", _rhs_conversion_label(f); last=true, fmt=fmt, value_style=""
    )
end

function Base.show(io::IO, ::MIME"text/plain", f::AbstractRHS)
    return show(io, f)
end
