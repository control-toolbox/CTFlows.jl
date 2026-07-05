# =============================================================================
# RHS Functors for PseudoHamiltonianSystem
#
# Mirror the HamiltonianSystem functors, but the control is *not* differentiated:
# the feedback value u = law(t, x, p, v) is evaluated first and then held fixed
# while `pseudo_hamiltonian_gradient` (and `pseudo_variable_gradient`) take partial
# derivatives of H̃ at that fixed u. This is the `:partial` mode.
# =============================================================================

# =============================================================================
# Abstract hierarchy — subtypes AbstractRHS{T} (mutability), not AbstractHamRHS
# (whose Base.show assumes a single `h` field; here we carry `h̃` and `law`).
# =============================================================================

"""
$(TYPEDEF)

Abstract supertype for pseudo-Hamiltonian right-hand side (RHS) functors. The type
parameter encodes the mutability trait (in-place vs out-of-place).

See also: [`CTFlows.Systems.AbstractRHS`](@ref), [`CTFlows.Systems.PseudoHamIpRHS`](@ref).
"""
abstract type AbstractPseudoHamRHS{T<:Traits.AbstractMutabilityTrait} <: AbstractRHS{T} end

"""
$(TYPEDEF)

Abstract supertype for in-place pseudo-Hamiltonian RHS functors.

See also: [`CTFlows.Systems.AbstractPseudoHamRHS`](@ref).
"""
abstract type AbstractIPPseudoHamRHS <: AbstractPseudoHamRHS{Traits.InPlace} end

"""
$(TYPEDEF)

Abstract supertype for out-of-place pseudo-Hamiltonian RHS functors.

See also: [`CTFlows.Systems.AbstractPseudoHamRHS`](@ref).
"""
abstract type AbstractOoPPseudoHamRHS <: AbstractPseudoHamRHS{Traits.OutOfPlace} end

# =============================================================================
# Standard functors
# =============================================================================

"""
$(TYPEDEF)

In-place RHS functor for a `PseudoHamiltonianSystem`. Evaluates the feedback control
`u = law(t, x, p, v)` and then computes, at that fixed `u`,

```
ẋ =  ∂H̃/∂p
ṗ = -∂H̃/∂x
```

# Fields
- `h̃::PH`: the pseudo-Hamiltonian `H̃(t, x, p, u, v)`.
- `law::L`: the dynamic closed-loop control law `u(t, x, p, v)`.
- `backend::B`: the AD backend.
- `N::Int`: state dimension.
- `cx::CX`: state coercion.
- `cp::CP`: costate coercion.

See also: [`CTFlows.Systems.PseudoHamOoPRHS`](@ref), [`CTFlows.Systems.PseudoHamIpAugRHS`](@ref).
"""
struct PseudoHamIpRHS{PH<:Data.PseudoHamiltonian,L<:Data.ControlLaw,B,CX,CP} <:
       AbstractIPPseudoHamRHS
    h̃::PH
    law::L
    backend::B
    N::Int
    cx::CX
    cp::CP
end

function (f::PseudoHamIpRHS)(du, u, λ, t)
    x, p = _ham_split(u, f.N)
    v = variable(λ)
    cx, cp = f.cx(x), f.cp(p)
    u_ = f.law(t, cx, cp, v)   # DynClosedLoop uniform call (t, x, p, v)
    ∂x, ∂p = Differentiation.pseudo_hamiltonian_gradient(f.backend, f.h̃, t, cx, cp, u_, v)
    _ham_assign!(du, ∂p, -∂x, f.N)
    return nothing
end

"""
$(TYPEDEF)

Out-of-place RHS functor for a `PseudoHamiltonianSystem`; see
[`CTFlows.Systems.PseudoHamIpRHS`](@ref) for the computation. Returns `vcat(∂p, -∂x)`.

# Fields
- `h̃::PH`: the pseudo-Hamiltonian `H̃(t, x, p, u, v)`.
- `law::L`: the dynamic closed-loop control law `u(t, x, p, v)`.
- `backend::B`: the AD backend.
- `N::Int`: state dimension.
- `cx::CX`: state coercion.
- `cp::CP`: costate coercion.

See also: [`CTFlows.Systems.PseudoHamIpRHS`](@ref).
"""
struct PseudoHamOoPRHS{PH<:Data.PseudoHamiltonian,L<:Data.ControlLaw,B,CX,CP} <:
       AbstractOoPPseudoHamRHS
    h̃::PH
    law::L
    backend::B
    N::Int
    cx::CX
    cp::CP
end

function (f::PseudoHamOoPRHS)(u, λ, t)
    x, p = _ham_split(u, f.N)
    v = variable(λ)
    cx, cp = f.cx(x), f.cp(p)
    u_ = f.law(t, cx, cp, v)
    ∂x, ∂p = Differentiation.pseudo_hamiltonian_gradient(f.backend, f.h̃, t, cx, cp, u_, v)
    return vcat(∂p, -∂x)
end

# =============================================================================
# Augmented functor (variable costate)
#
# ẋ =  ∂H̃/∂p ; ṗ = -∂H̃/∂x ; ṗv = -∂H̃/∂v  (all at fixed u = law(t,x,p,v))
# =============================================================================

"""
$(TYPEDEF)

In-place augmented RHS functor for a `PseudoHamiltonianSystem` with variable costate.
Extends [`CTFlows.Systems.PseudoHamIpRHS`](@ref) with `ṗv = -∂H̃/∂v` (control fixed),
computed by [`CTBase.Differentiation.pseudo_variable_gradient`](@extref). The augmented
state is `[x; p; pv]`.

# Fields
- `h̃::PH`: the pseudo-Hamiltonian `H̃(t, x, p, u, v)`.
- `law::L`: the dynamic closed-loop control law `u(t, x, p, v)`.
- `backend::B`: the AD backend.
- `n_x::Int`: state dimension.
- `n_v::Int`: variable dimension.
- `cx::CX`: state coercion.
- `cp::CP`: costate coercion.

See also: [`CTFlows.Systems.PseudoHamIpRHS`](@ref), [`CTFlows.Systems.HamIpAugRHS`](@ref).
"""
struct PseudoHamIpAugRHS{PH<:Data.PseudoHamiltonian,L<:Data.ControlLaw,B,CX,CP} <:
       AbstractIPPseudoHamRHS
    h̃::PH
    law::L
    backend::B
    n_x::Int
    n_v::Int
    cx::CX
    cp::CP
end

function (f::PseudoHamIpAugRHS)(du, u, λ, t)
    v = variable(λ)
    _check_aug_batch_compat(u, v)
    x, p, _ = _aug_split(u, f.n_x, f.n_v)
    cx, cp = f.cx(x), f.cp(p)
    u_ = f.law(t, cx, cp, v)
    ∂x, ∂p = Differentiation.pseudo_hamiltonian_gradient(f.backend, f.h̃, t, cx, cp, u_, v)
    ∂pv = Differentiation.pseudo_variable_gradient(f.backend, f.h̃, t, cx, cp, u_, v)
    _aug_assign!(du, ∂p, -∂x, -∂pv, f.n_x, f.n_v)
    return nothing
end

# =============================================================================
# Display
# =============================================================================

_rhs_conversion_label(::PseudoHamIpRHS) = "PseudoHamiltonian AD → in-place interface"
_rhs_conversion_label(::PseudoHamOoPRHS) = "PseudoHamiltonian AD → out-of-place interface"
function _rhs_conversion_label(::PseudoHamIpAugRHS)
    return "PseudoHamiltonian AD → in-place augmented interface"
end

function Base.show(io::IO, f::AbstractPseudoHamRHS)
    fmt = Display.format_codes(io)
    td = Traits.time_dependence(f.h̃)
    vd = Traits.variable_dependence(f.h̃)
    wraps = "PseudoHamiltonian: $(Data._td_label(td)), $(Data._vd_label(vd))"
    Display.print_header(io, nameof(typeof(f)); fmt = fmt)
    Display.print_field(io, "wraps", wraps; fmt = fmt, value_style = "")
    return Display.print_field(
        io,
        "converts",
        _rhs_conversion_label(f);
        last = true,
        fmt = fmt,
        value_style = "",
    )
end

function Base.show(io::IO, ::MIME"text/plain", f::AbstractPseudoHamRHS)
    return show(io, f)
end
