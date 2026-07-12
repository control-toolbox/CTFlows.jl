# =============================================================================
# RHS Functors for HamiltonianVectorFieldSystem
# =============================================================================

# =============================================================================
# Abstract hierarchy
# =============================================================================

"""
    AbstractHVFRHS{T<:Traits.AbstractMutabilityTrait} <: AbstractRHS{T}

Abstract base type for HamiltonianVectorField RHS functors.

Provides a common supertype for all Hamiltonian vector field functors,
enabling generic display methods that access the `.hvf` field.

# Type Parameters
- `T <: Traits.AbstractMutabilityTrait`: The mutability trait (`InPlace` or `OutOfPlace`).
"""
abstract type AbstractHVFRHS{T<:Traits.AbstractMutabilityTrait} <: AbstractRHS{T} end

"""
    AbstractIPHVFRHS <: AbstractHVFRHS{Traits.InPlace}

Abstract base type for in-place HamiltonianVectorField RHS functors.
"""
abstract type AbstractIPHVFRHS <: AbstractHVFRHS{Traits.InPlace} end

"""
    AbstractOoPHVFRHS <: AbstractHVFRHS{Traits.OutOfPlace}

Abstract base type for out-of-place HamiltonianVectorField RHS functors.
"""
abstract type AbstractOoPHVFRHS <: AbstractHVFRHS{Traits.OutOfPlace} end

# =============================================================================
# Lazy functors (constructed at build_rhs/build_oop_rhs time)
# =============================================================================

"""
    IPHVFOoPRHS{F,TD,VD,CX,CP} <: AbstractIPHVFRHS

In-place RHS functor for an out-of-place HamiltonianVectorField.

Wraps an out-of-place HamiltonianVectorField and provides an in-place interface
by allocating the result into the pre-allocated `du` buffer.

# Fields
- `hvf::HamiltonianVectorField{F,TD,VD,Traits.OutOfPlace}`: The wrapped vector field.
- `N::Int`: State dimension.
- `cx::CX`: Coercion function for state (e.g., `identity` or `only`).
- `cp::CP`: Coercion function for costate (e.g., `identity` or `only`).

# Call signature
`(f::IPHVFOoPRHS)(du, u, λ, t) -> nothing`
"""
struct IPHVFOoPRHS{
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    CX<:Union{typeof(only),typeof(identity)},
    CP<:Union{typeof(only),typeof(identity)},
} <: AbstractIPHVFRHS
    hvf::Data.HamiltonianVectorField{F,TD,VD,Traits.OutOfPlace}
    N::Int
    cx::CX
    cp::CP
end

function (f::IPHVFOoPRHS{F,TD,VD,CX,CP})(
    du, u, λ, t
) where {
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    CX<:Union{typeof(only),typeof(identity)},
    CP<:Union{typeof(only),typeof(identity)},
}
    x, p = _ham_split(u, f.N)
    dx, dp = f.hvf(t, f.cx(x), f.cp(p), variable(λ); variable_costate=false)
    _ham_assign!(du, dx, dp, f.N)
    return nothing
end

"""
    IPHVFIpRHS{F,TD,VD,CX,CP} <: AbstractIPHVFRHS

In-place RHS functor for an in-place HamiltonianVectorField.

Wraps an in-place HamiltonianVectorField and provides an in-place interface
by directly calling the function with pre-allocated buffers.

# Fields
- `hvf::HamiltonianVectorField{F,TD,VD,Traits.InPlace}`: The wrapped vector field.
- `N::Int`: State dimension.
- `cx::CX`: Coercion function for state (e.g., `identity` or `only`).
- `cp::CP`: Coercion function for costate (e.g., `identity` or `only`).

# Call signature
`(f::IPHVFIpRHS)(du, u, λ, t) -> nothing`
"""
struct IPHVFIpRHS{
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    CX<:Union{typeof(only),typeof(identity)},
    CP<:Union{typeof(only),typeof(identity)},
} <: AbstractIPHVFRHS
    hvf::Data.HamiltonianVectorField{F,TD,VD,Traits.InPlace}
    N::Int
    cx::CX
    cp::CP
end

function (f::IPHVFIpRHS{F,TD,VD,CX,CP})(
    du, u, λ, t
) where {
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    CX<:Union{typeof(only),typeof(identity)},
    CP<:Union{typeof(only),typeof(identity)},
}
    x, p = _ham_split(u, f.N)
    dx, dp = _ham_split(du, f.N)
    f.hvf(dx, dp, t, f.cx(x), f.cp(p), variable(λ); variable_costate=false)
    return nothing
end

"""
    OoPHVFOoPRHS{F,TD,VD,CX,CP} <: AbstractOoPHVFRHS

Out-of-place RHS functor for an out-of-place HamiltonianVectorField.

Wraps an out-of-place HamiltonianVectorField and provides an out-of-place interface
by directly calling the function and concatenating the results.

# Fields
- `hvf::HamiltonianVectorField{F,TD,VD,Traits.OutOfPlace}`: The wrapped vector field.
- `N::Int`: State dimension.
- `cx::CX`: Coercion function for state (e.g., `identity` or `only`).
- `cp::CP`: Coercion function for costate (e.g., `identity` or `only`).

# Call signature
`(f::OoPHVFOoPRHS)(u, λ, t) -> du`
"""
struct OoPHVFOoPRHS{
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    CX<:Union{typeof(only),typeof(identity)},
    CP<:Union{typeof(only),typeof(identity)},
} <: AbstractOoPHVFRHS
    hvf::Data.HamiltonianVectorField{F,TD,VD,Traits.OutOfPlace}
    N::Int
    cx::CX
    cp::CP
end

function (f::OoPHVFOoPRHS{F,TD,VD,CX,CP})(
    u, λ, t
) where {
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    CX<:Union{typeof(only),typeof(identity)},
    CP<:Union{typeof(only),typeof(identity)},
}
    x, p = _ham_split(u, f.N)
    dx, dp = f.hvf(t, f.cx(x), f.cp(p), variable(λ); variable_costate=false)
    return vcat(dx, dp)
end

"""
    OoPHVFIpRHS{F,TD,VD,CX,CP} <: AbstractOoPHVFRHS

Out-of-place RHS functor for an in-place HamiltonianVectorField.

Wraps an in-place HamiltonianVectorField and provides an out-of-place interface
by allocating temporary buffers on each call.

# Fields
- `hvf::HamiltonianVectorField{F,TD,VD,Traits.InPlace}`: The wrapped vector field.
- `N::Int`: State dimension.
- `cx::CX`: Coercion function for state (e.g., `identity` or `only`).
- `cp::CP`: Coercion function for costate (e.g., `identity` or `only`).

# Call signature
`(f::OoPHVFIpRHS)(u, λ, t) -> du`
"""
struct OoPHVFIpRHS{
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    CX<:Union{typeof(only),typeof(identity)},
    CP<:Union{typeof(only),typeof(identity)},
} <: AbstractOoPHVFRHS
    hvf::Data.HamiltonianVectorField{F,TD,VD,Traits.InPlace}
    N::Int
    cx::CX
    cp::CP
end

function (f::OoPHVFIpRHS{F,TD,VD,CX,CP})(
    u, λ, t
) where {
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    CX<:Union{typeof(only),typeof(identity)},
    CP<:Union{typeof(only),typeof(identity)},
}
    x, p = _ham_split(u, f.N)
    dx, dp = similar(x), similar(p)
    f.hvf(dx, dp, t, f.cx(x), f.cp(p), variable(λ); variable_costate=false)
    return vcat(dx, dp)
end

"""
    OoPHVFIpFinalizeRHS{F,TD,VD,CX,CP} <: AbstractOoPHVFRHS

Out-of-place RHS functor for an in-place HamiltonianVectorField with type conversion.

Wraps an in-place HamiltonianVectorField and provides an out-of-place interface
that converts the result to match the input type (e.g., Vector → SVector).

# Fields
- `hvf::HamiltonianVectorField{F,TD,VD,Traits.InPlace}`: The wrapped vector field.
- `N::Int`: State dimension.
- `cx::CX`: Coercion function for state (e.g., `identity` or `only`).
- `cp::CP`: Coercion function for costate (e.g., `identity` or `only`).

# Call signature
`(f::OoPHVFIpFinalizeRHS)(u, λ, t) -> du`
"""
struct OoPHVFIpFinalizeRHS{
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    CX<:Union{typeof(only),typeof(identity)},
    CP<:Union{typeof(only),typeof(identity)},
} <: AbstractOoPHVFRHS
    hvf::Data.HamiltonianVectorField{F,TD,VD,Traits.InPlace}
    N::Int
    cx::CX
    cp::CP
end

function (f::OoPHVFIpFinalizeRHS{F,TD,VD,CX,CP})(
    u, λ, t
) where {
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    CX<:Union{typeof(only),typeof(identity)},
    CP<:Union{typeof(only),typeof(identity)},
}
    x, p = _ham_split(u, f.N)
    dx, dp = similar(x), similar(p)
    f.hvf(dx, dp, t, f.cx(x), f.cp(p), variable(λ); variable_costate=false)
    return typeof(u)(vcat(dx, dp))
end

# =============================================================================
# Augmented functors (for variable costate integration)
# =============================================================================

"""
    IPHVFOoPAugRHS{F,TD,VD} <: AbstractIPHVFRHS

In-place augmented RHS functor for an out-of-place HamiltonianVectorField.

Wraps an out-of-place HamiltonianVectorField and provides an in-place interface
for the augmented system (state + costate + variable costate).

# Fields
- `hvf::HamiltonianVectorField{F,TD,VD,Traits.OutOfPlace}`: The wrapped vector field.
- `n_x::Int`: State dimension.
- `n_v::Int`: Variable costate dimension.

# Call signature
`(f::IPHVFOoPAugRHS)(du, u, λ, t) -> nothing`
"""
struct IPHVFOoPAugRHS{
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    CX<:Union{typeof(only),typeof(identity)},
    CP<:Union{typeof(only),typeof(identity)},
} <: AbstractIPHVFRHS
    hvf::Data.HamiltonianVectorField{F,TD,VD,Traits.OutOfPlace}
    n_x::Int
    n_v::Int
    cx::CX
    cp::CP
end

function (f::IPHVFOoPAugRHS{F,TD,VD,CX,CP})(
    du, u, λ, t
) where {
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    CX<:Union{typeof(only),typeof(identity)},
    CP<:Union{typeof(only),typeof(identity)},
}
    v = variable(λ)
    x, p, _ = _aug_split(u, f.n_x, f.n_v)
    dx, dp, dpv = f.hvf(t, f.cx(x), f.cp(p), v; variable_costate=true)
    _aug_assign!(du, dx, dp, dpv, f.n_x, f.n_v)
    return nothing
end

"""
    IPHVFIpAugRHS{F,TD,VD} <: AbstractIPHVFRHS

In-place augmented RHS functor for an in-place HamiltonianVectorField.

Wraps an in-place HamiltonianVectorField and provides an in-place interface
for the augmented system (state + costate + variable costate).

# Fields
- `hvf::HamiltonianVectorField{F,TD,VD,Traits.InPlace}`: The wrapped vector field.
- `n_x::Int`: State dimension.
- `n_v::Int`: Variable costate dimension.

# Call signature
`(f::IPHVFIpAugRHS)(du, u, λ, t) -> nothing`
"""
struct IPHVFIpAugRHS{
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    CX<:Union{typeof(only),typeof(identity)},
    CP<:Union{typeof(only),typeof(identity)},
} <: AbstractIPHVFRHS
    hvf::Data.HamiltonianVectorField{F,TD,VD,Traits.InPlace}
    n_x::Int
    n_v::Int
    cx::CX
    cp::CP
end

function (f::IPHVFIpAugRHS{F,TD,VD,CX,CP})(
    du, u, λ, t
) where {
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    CX<:Union{typeof(only),typeof(identity)},
    CP<:Union{typeof(only),typeof(identity)},
}
    v = variable(λ)
    x, p, _ = _aug_split(u, f.n_x, f.n_v)
    dx, dp, _ = _aug_split(du, f.n_x, f.n_v)
    dpv = similar(u[(end - f.n_v + 1):end])
    f.hvf(dx, dp, t, f.cx(x), f.cp(p), v; dpv=dpv, variable_costate=true)
    du[(end - f.n_v + 1):end] .= dpv
    return nothing
end

# =============================================================================
# Display helpers
# =============================================================================

_rhs_conversion_label(::IPHVFOoPRHS) = "out-of-place HVF → in-place interface"
_rhs_conversion_label(::IPHVFIpRHS) = "in-place HVF → in-place interface"
_rhs_conversion_label(::OoPHVFOoPRHS) = "out-of-place HVF → out-of-place interface"
_rhs_conversion_label(::OoPHVFIpRHS) = "in-place HVF → out-of-place interface"
function _rhs_conversion_label(::OoPHVFIpFinalizeRHS)
    return "in-place HVF → out-of-place interface + finalize"
end
_rhs_conversion_label(::IPHVFOoPAugRHS) = "out-of-place HVF → in-place augmented interface"
_rhs_conversion_label(::IPHVFIpAugRHS) = "in-place HVF → in-place augmented interface"

function Base.show(io::IO, f::AbstractHVFRHS)
    fmt = Display.format_codes(io)
    td = Traits.time_dependence(f.hvf)
    vd = Traits.variable_dependence(f.hvf)
    md = Traits.mutability(f.hvf)
    wraps = "HamiltonianVectorField: $(Data._td_label(td)), $(Data._vd_label(vd)), $(Data._md_label(md))"
    Display.print_header(io, nameof(typeof(f)); fmt=fmt)
    Display.print_field(io, "wraps", wraps; fmt=fmt, value_style="")
    return Display.print_field(
        io, "converts", _rhs_conversion_label(f); last=true, fmt=fmt, value_style=""
    )
end

function Base.show(io::IO, ::MIME"text/plain", f::AbstractHVFRHS)
    return show(io, f)
end
