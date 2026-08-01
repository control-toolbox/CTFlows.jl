# =============================================================================
# RHS Functors for PseudoHamiltonianVectorFieldSystem
#
# Mirror the HVF functors, but the control is *not* differentiated: the feedback
# value u_ = law(t, x, p, v) is evaluated first and then passed to the user's
# already-differentiated pseudo-Hamiltonian vector field h̃vf(t, x, p, u_, v).
# No AD anywhere — the vector-field analogue of PseudoHamIpRHS/PseudoHamOoPRHS.
# =============================================================================

# =============================================================================
# Abstract hierarchy — subtypes AbstractRHS{T} (mutability), not AbstractHVFRHS
# (whose Base.show assumes a single `.hvf` field; here we carry `h̃vf` and `law`).
# =============================================================================

"""
$(TYPEDEF)

Abstract supertype for `PseudoHamiltonianVectorFieldSystem` right-hand side (RHS)
functors. The type parameter encodes the mutability trait (in-place vs out-of-place).

See also: [`CTFlows.Systems.AbstractRHS`](@extref), [`CTFlows.Systems.IPPseudoHVFOoPRHS`](@extref).
"""
abstract type AbstractPseudoHVFRHS{T<:Traits.AbstractMutabilityTrait} <: AbstractRHS{T} end

"""
$(TYPEDEF)

Abstract supertype for in-place `PseudoHamiltonianVectorFieldSystem` RHS functors.

See also: [`CTFlows.Systems.AbstractPseudoHVFRHS`](@extref).
"""
abstract type AbstractIPPseudoHVFRHS <: AbstractPseudoHVFRHS{Traits.InPlace} end

"""
$(TYPEDEF)

Abstract supertype for out-of-place `PseudoHamiltonianVectorFieldSystem` RHS functors.

See also: [`CTFlows.Systems.AbstractPseudoHVFRHS`](@extref).
"""
abstract type AbstractOoPPseudoHVFRHS <: AbstractPseudoHVFRHS{Traits.OutOfPlace} end

# =============================================================================
# Standard functors
# =============================================================================

"""
$(TYPEDEF)

In-place RHS functor for an out-of-place `PseudoHamiltonianVectorField`. Evaluates
the feedback control `u_ = law(t, x, p, v)` and then computes `(dx, dp) =
h̃vf(t, x, p, u_, v)` directly (no AD), writing the result into the pre-allocated `du`
buffer.

# Fields
- `h̃vf::PseudoHamiltonianVectorField{F,TD,VD,Traits.OutOfPlace}`: the wrapped
  pseudo-Hamiltonian vector field.
- `law::L`: the dynamic closed-loop control law `u(t, x, p, v)`.
- `N::Int`: state dimension.
- `cx::CX`: coercion function for state (e.g., `identity` or `_safe_only`).
- `cp::CP`: coercion function for costate (e.g., `identity` or `_safe_only`).

# Call signature
`(f::IPPseudoHVFOoPRHS)(du, u, λ, t) -> nothing`

See also: [`CTFlows.Systems.OoPPseudoHVFOoPRHS`](@extref), [`CTFlows.Systems.IPPseudoHVFIpRHS`](@extref).
"""
struct IPPseudoHVFOoPRHS{
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    L<:Data.ControlLaw,
    CX<:Union{typeof(_safe_only),typeof(identity)},
    CP<:Union{typeof(_safe_only),typeof(identity)},
} <: AbstractIPPseudoHVFRHS
    h̃vf::Data.PseudoHamiltonianVectorField{F,TD,VD,Traits.OutOfPlace}
    law::L
    N::Int
    cx::CX
    cp::CP
end

function (f::IPPseudoHVFOoPRHS)(du, u, λ, t)
    x, p = _ham_split(u, f.N)
    v = variable(λ)
    cx, cp = f.cx(x), f.cp(p)
    u_ = f.law(t, cx, cp, v)   # DynClosedLoop uniform call (t, x, p, v)
    dx, dp = f.h̃vf(t, cx, cp, u_, v; variable_costate=false)
    _ham_assign!(du, dx, dp, f.N)
    return nothing
end

"""
$(TYPEDEF)

In-place RHS functor for an in-place `PseudoHamiltonianVectorField`. Evaluates the
feedback control `u_ = law(t, x, p, v)` and then calls the wrapped in-place vector
field directly with the pre-allocated `dx`/`dp` buffers.

# Fields
- `h̃vf::PseudoHamiltonianVectorField{F,TD,VD,Traits.InPlace}`: the wrapped
  pseudo-Hamiltonian vector field.
- `law::L`: the dynamic closed-loop control law `u(t, x, p, v)`.
- `N::Int`: state dimension.
- `cx::CX`: coercion function for state.
- `cp::CP`: coercion function for costate.

# Call signature
`(f::IPPseudoHVFIpRHS)(du, u, λ, t) -> nothing`

See also: [`CTFlows.Systems.IPPseudoHVFOoPRHS`](@extref).
"""
struct IPPseudoHVFIpRHS{
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    L<:Data.ControlLaw,
    CX<:Union{typeof(_safe_only),typeof(identity)},
    CP<:Union{typeof(_safe_only),typeof(identity)},
} <: AbstractIPPseudoHVFRHS
    h̃vf::Data.PseudoHamiltonianVectorField{F,TD,VD,Traits.InPlace}
    law::L
    N::Int
    cx::CX
    cp::CP
end

function (f::IPPseudoHVFIpRHS)(du, u, λ, t)
    x, p = _ham_split(u, f.N)
    dx, dp = _ham_split(du, f.N)
    v = variable(λ)
    cx, cp = f.cx(x), f.cp(p)
    u_ = f.law(t, cx, cp, v)
    f.h̃vf(dx, dp, t, cx, cp, u_, v; variable_costate=false)
    return nothing
end

"""
$(TYPEDEF)

Out-of-place RHS functor for an out-of-place `PseudoHamiltonianVectorField`; see
[`CTFlows.Systems.IPPseudoHVFOoPRHS`](@extref) for the computation. Returns
`vcat(dx, dp)`.

# Fields
- `h̃vf::PseudoHamiltonianVectorField{F,TD,VD,Traits.OutOfPlace}`: the wrapped
  pseudo-Hamiltonian vector field.
- `law::L`: the dynamic closed-loop control law `u(t, x, p, v)`.
- `N::Int`: state dimension.
- `cx::CX`: coercion function for state.
- `cp::CP`: coercion function for costate.

# Call signature
`(f::OoPPseudoHVFOoPRHS)(u, λ, t) -> du`

See also: [`CTFlows.Systems.IPPseudoHVFOoPRHS`](@extref).
"""
struct OoPPseudoHVFOoPRHS{
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    L<:Data.ControlLaw,
    CX<:Union{typeof(_safe_only),typeof(identity)},
    CP<:Union{typeof(_safe_only),typeof(identity)},
} <: AbstractOoPPseudoHVFRHS
    h̃vf::Data.PseudoHamiltonianVectorField{F,TD,VD,Traits.OutOfPlace}
    law::L
    N::Int
    cx::CX
    cp::CP
end

function (f::OoPPseudoHVFOoPRHS)(u, λ, t)
    x, p = _ham_split(u, f.N)
    v = variable(λ)
    cx, cp = f.cx(x), f.cp(p)
    u_ = f.law(t, cx, cp, v)
    dx, dp = f.h̃vf(t, cx, cp, u_, v; variable_costate=false)
    return vcat(dx, dp)
end

"""
$(TYPEDEF)

Out-of-place RHS functor for an in-place `PseudoHamiltonianVectorField`; allocates
temporary `dx`/`dp` buffers on each call via `similar`.

# Fields
- `h̃vf::PseudoHamiltonianVectorField{F,TD,VD,Traits.InPlace}`: the wrapped
  pseudo-Hamiltonian vector field.
- `law::L`: the dynamic closed-loop control law `u(t, x, p, v)`.
- `N::Int`: state dimension.
- `cx::CX`: coercion function for state.
- `cp::CP`: coercion function for costate.

# Call signature
`(f::OoPPseudoHVFIpRHS)(u, λ, t) -> du`

See also: [`CTFlows.Systems.OoPPseudoHVFIpFinalizeRHS`](@extref).
"""
struct OoPPseudoHVFIpRHS{
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    L<:Data.ControlLaw,
    CX<:Union{typeof(_safe_only),typeof(identity)},
    CP<:Union{typeof(_safe_only),typeof(identity)},
} <: AbstractOoPPseudoHVFRHS
    h̃vf::Data.PseudoHamiltonianVectorField{F,TD,VD,Traits.InPlace}
    law::L
    N::Int
    cx::CX
    cp::CP
end

function (f::OoPPseudoHVFIpRHS)(u, λ, t)
    x, p = _ham_split(u, f.N)
    v = variable(λ)
    cx, cp = f.cx(x), f.cp(p)
    u_ = f.law(t, cx, cp, v)
    dx, dp = similar(x), similar(p)
    f.h̃vf(dx, dp, t, cx, cp, u_, v; variable_costate=false)
    return vcat(dx, dp)
end

"""
$(TYPEDEF)

Out-of-place RHS functor for an in-place `PseudoHamiltonianVectorField`, converting
the result back to the input array type (e.g. `Vector` → `SVector`) for immutable
initial conditions.

# Fields
- `h̃vf::PseudoHamiltonianVectorField{F,TD,VD,Traits.InPlace}`: the wrapped
  pseudo-Hamiltonian vector field.
- `law::L`: the dynamic closed-loop control law `u(t, x, p, v)`.
- `N::Int`: state dimension.
- `cx::CX`: coercion function for state.
- `cp::CP`: coercion function for costate.

# Call signature
`(f::OoPPseudoHVFIpFinalizeRHS)(u, λ, t) -> du`

See also: [`CTFlows.Systems.OoPPseudoHVFIpRHS`](@extref).
"""
struct OoPPseudoHVFIpFinalizeRHS{
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    L<:Data.ControlLaw,
    CX<:Union{typeof(_safe_only),typeof(identity)},
    CP<:Union{typeof(_safe_only),typeof(identity)},
} <: AbstractOoPPseudoHVFRHS
    h̃vf::Data.PseudoHamiltonianVectorField{F,TD,VD,Traits.InPlace}
    law::L
    N::Int
    cx::CX
    cp::CP
end

function (f::OoPPseudoHVFIpFinalizeRHS)(u, λ, t)
    x, p = _ham_split(u, f.N)
    v = variable(λ)
    cx, cp = f.cx(x), f.cp(p)
    u_ = f.law(t, cx, cp, v)
    dx, dp = similar(x), similar(p)
    f.h̃vf(dx, dp, t, cx, cp, u_, v; variable_costate=false)
    return typeof(u)(vcat(dx, dp))
end

# =============================================================================
# Augmented functors (for variable costate integration)
#
# ẋ = ∂p H̃ ; ṗ = -∂x H̃ ; ṗv = -∂v H̃  (all supplied directly by the user's h̃vf
# at u_ = law(t,x,p,v), no AD)
# =============================================================================

"""
$(TYPEDEF)

In-place augmented RHS functor for an out-of-place `PseudoHamiltonianVectorField`
with variable costate. Evaluates `u_ = law(t, x, p, v)`, then calls `h̃vf(t, x, p,
u_, v; variable_costate=true)` to get `(dx, dp, dpv)`. The augmented state is
`[x; p; pv]`.

# Fields
- `h̃vf::PseudoHamiltonianVectorField{F,TD,VD,Traits.OutOfPlace}`: the wrapped
  pseudo-Hamiltonian vector field.
- `law::L`: the dynamic closed-loop control law `u(t, x, p, v)`.
- `n_x::Int`: state dimension.
- `n_v::Int`: variable dimension.
- `cx::CX`: coercion function for state.
- `cp::CP`: coercion function for costate.

# Call signature
`(f::IPPseudoHVFOoPAugRHS)(du, u, λ, t) -> nothing`

See also: [`CTFlows.Systems.IPPseudoHVFIpAugRHS`](@extref).
"""
struct IPPseudoHVFOoPAugRHS{
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    L<:Data.ControlLaw,
    CX<:Union{typeof(_safe_only),typeof(identity)},
    CP<:Union{typeof(_safe_only),typeof(identity)},
} <: AbstractIPPseudoHVFRHS
    h̃vf::Data.PseudoHamiltonianVectorField{F,TD,VD,Traits.OutOfPlace}
    law::L
    n_x::Int
    n_v::Int
    cx::CX
    cp::CP
end

function (f::IPPseudoHVFOoPAugRHS)(du, u, λ, t)
    v = variable(λ)
    x, p, _ = _aug_split(u, f.n_x, f.n_v)
    cx, cp = f.cx(x), f.cp(p)
    u_ = f.law(t, cx, cp, v)
    dx, dp, dpv = f.h̃vf(t, cx, cp, u_, v; variable_costate=true)
    _aug_assign!(du, dx, dp, dpv, f.n_x, f.n_v)
    return nothing
end

"""
$(TYPEDEF)

In-place augmented RHS functor for an in-place `PseudoHamiltonianVectorField` with
variable costate. Extends [`CTFlows.Systems.IPPseudoHVFIpRHS`](@extref) with `ṗv =
-∂H̃/∂v` (supplied directly by `h̃vf` at `u_ = law(t,x,p,v)`, no AD). The augmented
state is `[x; p; pv]`.

# Fields
- `h̃vf::PseudoHamiltonianVectorField{F,TD,VD,Traits.InPlace}`: the wrapped
  pseudo-Hamiltonian vector field.
- `law::L`: the dynamic closed-loop control law `u(t, x, p, v)`.
- `n_x::Int`: state dimension.
- `n_v::Int`: variable dimension.
- `cx::CX`: coercion function for state.
- `cp::CP`: coercion function for costate.

# Call signature
`(f::IPPseudoHVFIpAugRHS)(du, u, λ, t) -> nothing`

See also: [`CTFlows.Systems.IPPseudoHVFOoPAugRHS`](@extref).
"""
struct IPPseudoHVFIpAugRHS{
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    L<:Data.ControlLaw,
    CX<:Union{typeof(_safe_only),typeof(identity)},
    CP<:Union{typeof(_safe_only),typeof(identity)},
} <: AbstractIPPseudoHVFRHS
    h̃vf::Data.PseudoHamiltonianVectorField{F,TD,VD,Traits.InPlace}
    law::L
    n_x::Int
    n_v::Int
    cx::CX
    cp::CP
end

function (f::IPPseudoHVFIpAugRHS)(du, u, λ, t)
    v = variable(λ)
    _check_aug_batch_compat(u, v)
    x, p, _ = _aug_split(u, f.n_x, f.n_v)
    dx, dp, _ = _aug_split(du, f.n_x, f.n_v)
    cx, cp = f.cx(x), f.cp(p)
    u_ = f.law(t, cx, cp, v)
    dpv = similar(u[(end - f.n_v + 1):end])
    f.h̃vf(dx, dp, t, cx, cp, u_, v; dpv=dpv, variable_costate=true)
    du[(end - f.n_v + 1):end] .= dpv
    return nothing
end

# =============================================================================
# Display
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return a descriptive label for the RHS conversion performed by a pseudo-Hamiltonian vector field functor.

Used internally by `Base.show` for display.

See also: [`CTFlows.Systems.AbstractPseudoHVFRHS`](@extref).
"""
_rhs_conversion_label(::IPPseudoHVFOoPRHS) = "out-of-place PHVF → in-place interface"

"""
$(TYPEDSIGNATURES)

In-place PHVF wrapped as in-place interface.

See also: [`CTFlows.Systems._rhs_conversion_label`](@extref).
"""
_rhs_conversion_label(::IPPseudoHVFIpRHS) = "in-place PHVF → in-place interface"

"""
$(TYPEDSIGNATURES)

Out-of-place PHVF wrapped as out-of-place interface.

See also: [`CTFlows.Systems._rhs_conversion_label`](@extref).
"""
_rhs_conversion_label(::OoPPseudoHVFOoPRHS) = "out-of-place PHVF → out-of-place interface"

"""
$(TYPEDSIGNATURES)

In-place PHVF wrapped as out-of-place interface.

See also: [`CTFlows.Systems._rhs_conversion_label`](@extref).
"""
_rhs_conversion_label(::OoPPseudoHVFIpRHS) = "in-place PHVF → out-of-place interface"

"""
$(TYPEDSIGNATURES)

In-place PHVF wrapped as out-of-place interface with type-finalize conversion.

See also: [`CTFlows.Systems._rhs_conversion_label`](@extref).
"""
function _rhs_conversion_label(::OoPPseudoHVFIpFinalizeRHS)
    return "in-place PHVF → out-of-place interface + finalize"
end

"""
$(TYPEDSIGNATURES)

Out-of-place PHVF wrapped as in-place augmented interface.

See also: [`CTFlows.Systems._rhs_conversion_label`](@extref).
"""
function _rhs_conversion_label(::IPPseudoHVFOoPAugRHS)
    return "out-of-place PHVF → in-place augmented interface"
end

"""
$(TYPEDSIGNATURES)

In-place PHVF wrapped as in-place augmented interface.

See also: [`CTFlows.Systems._rhs_conversion_label`](@extref).
"""
function _rhs_conversion_label(::IPPseudoHVFIpAugRHS)
    return "in-place PHVF → in-place augmented interface"
end

"""
$(TYPEDSIGNATURES)

Display a compact representation of an `AbstractPseudoHVFRHS` functor.

Shows the functor type name, the wrapped PseudoHamiltonianVectorField's traits, and the conversion label.

See also: [`CTFlows.Systems.AbstractPseudoHVFRHS`](@extref), [`CTFlows.Systems._rhs_conversion_label`](@extref).
"""
function Base.show(io::IO, f::AbstractPseudoHVFRHS)
    fmt = Display.format_codes(io)
    td = Traits.time_dependence(f.h̃vf)
    vd = Traits.variable_dependence(f.h̃vf)
    md = Traits.mutability(f.h̃vf)
    wraps = "PseudoHamiltonianVectorField: $(Data._td_label(td)), $(Data._vd_label(vd)), $(Data._md_label(md))"
    Display.print_header(io, nameof(typeof(f)); fmt=fmt)
    Display.print_field(io, "wraps", wraps; fmt=fmt, value_style="")
    return Display.print_field(
        io, "converts", _rhs_conversion_label(f); last=true, fmt=fmt, value_style=""
    )
end

"""
$(TYPEDSIGNATURES)

Display an `AbstractPseudoHVFRHS` functor in the REPL with `text/plain` MIME type.

Delegates to the compact `show` method.

See also: [`CTFlows.Systems.AbstractPseudoHVFRHS`](@extref).
"""
function Base.show(io::IO, ::MIME"text/plain", f::AbstractPseudoHVFRHS)
    return show(io, f)
end
