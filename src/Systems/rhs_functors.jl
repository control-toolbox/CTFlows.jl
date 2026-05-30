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

function (f::IPVFOoPRHS{F,Traits.Autonomous,Traits.Fixed})(du, u, λ, t) where {F}
    du .= f.vf(u); nothing
end
function (f::IPVFOoPRHS{F,Traits.Autonomous,Traits.NonFixed})(du, u, λ, t) where {F}
    du .= f.vf(u, Common.variable(λ)); nothing
end
function (f::IPVFOoPRHS{F,Traits.NonAutonomous,Traits.Fixed})(du, u, λ, t) where {F}
    du .= f.vf(t, u); nothing
end
function (f::IPVFOoPRHS{F,Traits.NonAutonomous,Traits.NonFixed})(du, u, λ, t) where {F}
    du .= f.vf(t, u, Common.variable(λ)); nothing
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

function (f::IPVFIpRHS{F,Traits.Autonomous,Traits.Fixed})(du, u, λ, t) where {F}
    f.vf(du, u); nothing
end
function (f::IPVFIpRHS{F,Traits.Autonomous,Traits.NonFixed})(du, u, λ, t) where {F}
    f.vf(du, u, Common.variable(λ)); nothing
end
function (f::IPVFIpRHS{F,Traits.NonAutonomous,Traits.Fixed})(du, u, λ, t) where {F}
    f.vf(du, t, u); nothing
end
function (f::IPVFIpRHS{F,Traits.NonAutonomous,Traits.NonFixed})(du, u, λ, t) where {F}
    f.vf(du, t, u, Common.variable(λ)); nothing
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

function (f::OoPVFOoPRHS{F,Traits.Autonomous,Traits.Fixed})(u, λ, t) where {F}
    f.vf(u)
end
function (f::OoPVFOoPRHS{F,Traits.Autonomous,Traits.NonFixed})(u, λ, t) where {F}
    f.vf(u, Common.variable(λ))
end
function (f::OoPVFOoPRHS{F,Traits.NonAutonomous,Traits.Fixed})(u, λ, t) where {F}
    f.vf(t, u)
end
function (f::OoPVFOoPRHS{F,Traits.NonAutonomous,Traits.NonFixed})(u, λ, t) where {F}
    f.vf(t, u, Common.variable(λ))
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

function (f::OoPVFIpRHS{F,Traits.Autonomous,Traits.Fixed})(u, λ, t) where {F}
    dx = similar(u)
    f.vf(dx, u)
    dx
end
function (f::OoPVFIpRHS{F,Traits.Autonomous,Traits.NonFixed})(u, λ, t) where {F}
    dx = similar(u)
    f.vf(dx, u, Common.variable(λ))
    dx
end
function (f::OoPVFIpRHS{F,Traits.NonAutonomous,Traits.Fixed})(u, λ, t) where {F}
    dx = similar(u)
    f.vf(dx, t, u)
    dx
end
function (f::OoPVFIpRHS{F,Traits.NonAutonomous,Traits.NonFixed})(u, λ, t) where {F}
    dx = similar(u)
    f.vf(dx, t, u, Common.variable(λ))
    dx
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

function (f::OoPVFIpFinalizeRHS{F,Traits.Autonomous,Traits.Fixed})(u, λ, t) where {F}
    dx = similar(u)
    f.vf(dx, u)
    typeof(u)(dx)
end
function (f::OoPVFIpFinalizeRHS{F,Traits.Autonomous,Traits.NonFixed})(u, λ, t) where {F}
    dx = similar(u)
    f.vf(dx, u, Common.variable(λ))
    typeof(u)(dx)
end
function (f::OoPVFIpFinalizeRHS{F,Traits.NonAutonomous,Traits.Fixed})(u, λ, t) where {F}
    dx = similar(u)
    f.vf(dx, t, u)
    typeof(u)(dx)
end
function (f::OoPVFIpFinalizeRHS{F,Traits.NonAutonomous,Traits.NonFixed})(u, λ, t) where {F}
    dx = similar(u)
    f.vf(dx, t, u, Common.variable(λ))
    typeof(u)(dx)
end

# =============================================================================
# Display helpers
# =============================================================================

_rhs_conversion_label(f::IPVFOoPRHS) = "out-of-place VF → in-place interface"
_rhs_conversion_label(f::IPVFIpRHS) = "in-place VF → in-place interface"
_rhs_conversion_label(f::OoPVFOoPRHS) = "out-of-place VF → out-of-place interface"
_rhs_conversion_label(f::OoPVFIpRHS) = "in-place VF → out-of-place interface"
_rhs_conversion_label(f::OoPVFIpFinalizeRHS) = "in-place VF → out-of-place interface + finalize"

function Base.show(io::IO, f::AbstractRHS)
    println(io, nameof(typeof(f)))
    td = Traits.time_dependence(f.vf)
    vd = Traits.variable_dependence(f.vf)
    md = Traits.mutability(f.vf)
    wraps = "VectorField: $(Data._td_label(td)), $(Data._vd_label(vd)), $(Data._md_label(md))"
    println(io, "  wraps: ", wraps)
    print(io, "  converts: ", _rhs_conversion_label(f))
end

function Base.show(io::IO, ::MIME"text/plain", f::AbstractRHS)
    show(io, f)
end
