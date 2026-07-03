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
    IPVFOoPRHS{F,TD,VD} <: AbstractIPRHS

In-place RHS functor for an out-of-place VectorField.

Wraps an out-of-place VectorField and provides an in-place interface
by allocating the result into the pre-allocated `du` buffer.

# Fields
- `vf::Data.VectorField{F,TD,VD,Traits.OutOfPlace}`: The wrapped VectorField

# Call signature
`(f::IPVFOoPRHS)(du, u, λ, t) -> nothing`
"""
struct IPVFOoPRHS{F,TD,VD} <: AbstractIPRHS
    vf::Data.VectorField{F,TD,VD,Traits.OutOfPlace}
end

function (f::IPVFOoPRHS)(du, u, λ, t)
    du .= f.vf(t, u, variable(λ))
    return nothing
end

"""
    IPVFIpRHS{F,TD,VD} <: AbstractIPRHS

In-place RHS functor for an in-place VectorField.

Wraps an in-place VectorField and provides an in-place interface
by directly calling the VectorField.

# Fields
- `vf::Data.VectorField{F,TD,VD,Traits.InPlace}`: The wrapped VectorField

# Call signature
`(f::IPVFIpRHS)(du, u, λ, t) -> nothing`
"""
struct IPVFIpRHS{F,TD,VD} <: AbstractIPRHS
    vf::Data.VectorField{F,TD,VD,Traits.InPlace}
end

function (f::IPVFIpRHS)(du, u, λ, t)
    f.vf(du, t, u, variable(λ))
    return nothing
end

"""
    OoPVFOoPRHS{F,TD,VD} <: AbstractOoPRHS

Out-of-place RHS functor for an out-of-place VectorField.

Wraps an out-of-place VectorField and provides an out-of-place interface
by directly calling the VectorField.

# Fields
- `vf::Data.VectorField{F,TD,VD,Traits.OutOfPlace}`: The wrapped VectorField

# Call signature
`(f::OoPVFOoPRHS)(u, λ, t) -> du`
"""
struct OoPVFOoPRHS{F,TD,VD} <: AbstractOoPRHS
    vf::Data.VectorField{F,TD,VD,Traits.OutOfPlace}
end

function (f::OoPVFOoPRHS)(u, λ, t)
    return f.vf(t, u, variable(λ))
end

"""
    OoPVFIpRHS{F,TD,VD} <: AbstractOoPRHS

Out-of-place RHS functor for an in-place VectorField.

Wraps an in-place VectorField and provides an out-of-place interface
by allocating a temporary buffer on each call.

# Fields
- `vf::Data.VectorField{F,TD,VD,Traits.InPlace}`: The wrapped VectorField

# Call signature
`(f::OoPVFIpRHS)(u, λ, t) -> du`
"""
struct OoPVFIpRHS{F,TD,VD} <: AbstractOoPRHS
    vf::Data.VectorField{F,TD,VD,Traits.InPlace}
end

function (f::OoPVFIpRHS)(u, λ, t)
    dx = similar(u)
    f.vf(dx, t, u, variable(λ))
    return dx
end

"""
    OoPVFIpFinalizeRHS{F,TD,VD} <: AbstractOoPRHS

Out-of-place RHS functor for an in-place VectorField with type conversion.

Wraps an in-place VectorField and provides an out-of-place interface
that converts the result to match the input type (e.g., Vector → SVector).

# Fields
- `vf::Data.VectorField{F,TD,VD,Traits.InPlace}`: The wrapped VectorField

# Call signature
`(f::OoPVFIpFinalizeRHS)(u, λ, t) -> du`
"""
struct OoPVFIpFinalizeRHS{F,TD,VD} <: AbstractOoPRHS
    vf::Data.VectorField{F,TD,VD,Traits.InPlace}
end

function (f::OoPVFIpFinalizeRHS)(u, λ, t)
    dx = similar(u)
    f.vf(dx, t, u, variable(λ))
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
    println(io, nameof(typeof(f)))
    td = Traits.time_dependence(f.vf)
    vd = Traits.variable_dependence(f.vf)
    md = Traits.mutability(f.vf)
    wraps = "VectorField: $(Data._td_label(td)), $(Data._vd_label(vd)), $(Data._md_label(md))"
    println(io, "  wraps: ", wraps)
    return print(io, "  converts: ", _rhs_conversion_label(f))
end

function Base.show(io::IO, ::MIME"text/plain", f::AbstractRHS)
    return show(io, f)
end
