# =============================================================================
# RHS Functors for ConstrainedPseudoHamiltonianSystem (constrained :partial mode)
#
# Mirror the PseudoHamiltonianSystem functors, but add the constraint term μ·g with
# BOTH the control u AND the multiplier μ frozen at their feedback values. Per step:
#
#   u_ = law(t, x, p, v)          # frozen control  (already done by the :partial RHS)
#   μ_ = μ(t, x, p, v)            # frozen multiplier VALUE (new)
#
# are evaluated first, then held fixed while `pseudo_hamiltonian_gradient` (and
# `pseudo_variable_gradient`) differentiate H̃ + μ_·g through (x, p, v): g is
# differentiated, μ_ is a captured constant. This is the constrained `:partial` mode —
# see .reports/constraints-and-duals/math.md ("Point clé"). Baking μ as a *function*
# (the :total path, Flows.ConstrainedPseudoHamiltonianFunction) would instead
# differentiate through μ, producing the spurious (∂μ/∂x)ᵀg term.
# =============================================================================

# =============================================================================
# Frozen constrained pseudo-Hamiltonian
# =============================================================================

"""
$(TYPEDEF)

Constrained pseudo-Hamiltonian carrying a **frozen** multiplier value, used to compute
the constrained `:partial`-mode gradients. Represents

```
H̃c(t, x, p, u, v) = H̃(t, x, p, u, v) + μ_ · g(t, x, u, v)
```

where `μ_` is a **numeric value** (already evaluated at the current point), so automatic
differentiation through this functor differentiates `H̃` and `g` but treats `μ_` as a
constant — the constrained `:partial` semantics (`μ` frozen alongside `u`, `g`
differentiated). It subtypes [`CTBase.Data.AbstractPseudoHamiltonian`](@extref) so it is
accepted by [`CTBase.Differentiation.pseudo_hamiltonian_gradient`](@extref) and
[`CTBase.Differentiation.pseudo_variable_gradient`](@extref), which call it only through
the uniform `(t, x, p, u, v)` signature.

# Type Parameters
- `TD`, `VD`: time- and variable-dependence traits, inherited from the base `H̃`.
- `PH`: type of the base pseudo-Hamiltonian `H̃`.
- `G`: type of the path constraint `g`.
- `T`: type of the frozen multiplier value `μ_`.

# Fields
- `h̃::PH`: base pseudo-Hamiltonian, uniform call `H̃(t, x, p, u, v)`.
- `g::G`: path constraint, uniform call `g(t, x, u, v)`.
- `μ_::T`: frozen multiplier **value** (scalar or vector), captured as a constant.

See also: [`CTFlows.Systems.ConstrainedPseudoHamiltonianSystem`](@ref),
[`CTFlows.Systems.ConstrainedPseudoHamIpRHS`](@ref).
"""
struct FrozenConstrainedPseudoHamiltonian{
    TD<:Traits.TimeDependence,VD<:Traits.VariableDependence,PH,G,T
} <: Data.AbstractPseudoHamiltonian{TD,VD}
    h̃::PH
    g::G
    μ_::T
end

# Infer the (TD, VD) traits from the base pseudo-Hamiltonian.
function FrozenConstrainedPseudoHamiltonian(
    h̃::Data.PseudoHamiltonian{<:Function,TD,VD}, g, μ_
) where {TD<:Traits.TimeDependence,VD<:Traits.VariableDependence}
    return FrozenConstrainedPseudoHamiltonian{TD,VD,typeof(h̃),typeof(g),typeof(μ_)}(
        h̃, g, μ_
    )
end

# Uniform (t, x, p, u, v) call — the only signature the gradient primitives use. The
# base H̃ and the constraint g are differentiated through; μ_ is a captured constant.
function (h::FrozenConstrainedPseudoHamiltonian)(t, x, p, u, v)
    return h.h̃(t, x, p, u, v) + sum(h.μ_ .* h.g(t, x, u, v))
end

# =============================================================================
# Standard functors
# =============================================================================

"""
$(TYPEDEF)

In-place RHS functor for a [`CTFlows.Systems.ConstrainedPseudoHamiltonianSystem`](@ref).
Evaluates the feedback control `u_ = law(t, x, p, v)` and the multiplier value
`μ_ = μ(t, x, p, v)`, then computes, at that fixed `(u_, μ_)`,

```
ẋ =  ∂/∂p [ H̃ + μ_·g ]
ṗ = -∂/∂x [ H̃ + μ_·g ]
```

with `g` differentiated and `μ_` frozen (constrained `:partial` mode).

# Fields
- `h̃::PH`: base pseudo-Hamiltonian `H̃(t, x, p, u, v)`.
- `law::L`: dynamic closed-loop control law `u(t, x, p, v)`.
- `g::G`: path constraint `g(t, x, u, v)`.
- `μ::M`: multiplier `μ(t, x, p, v)`.
- `backend::B`: the AD backend.
- `N::Int`: state dimension.
- `cx::CX`: state coercion.
- `cp::CP`: costate coercion.

See also: [`CTFlows.Systems.ConstrainedPseudoHamOoPRHS`](@ref),
[`CTFlows.Systems.ConstrainedPseudoHamIpAugRHS`](@ref), [`CTFlows.Systems.PseudoHamIpRHS`](@ref).
"""
struct ConstrainedPseudoHamIpRHS{
    PH<:Data.PseudoHamiltonian,L<:Data.ControlLaw,G,M,B,CX,CP
} <: AbstractIPPseudoHamRHS
    h̃::PH
    law::L
    g::G
    μ::M
    backend::B
    N::Int
    cx::CX
    cp::CP
end

function (f::ConstrainedPseudoHamIpRHS)(du, u, λ, t)
    x, p = _ham_split(u, f.N)
    v = variable(λ)
    cx, cp = f.cx(x), f.cp(p)
    u_ = f.law(t, cx, cp, v)          # frozen control
    μ_ = f.μ(t, cx, cp, v)            # frozen multiplier value
    h̃c = FrozenConstrainedPseudoHamiltonian(f.h̃, f.g, μ_)
    ∂x, ∂p = Differentiation.pseudo_hamiltonian_gradient(f.backend, h̃c, t, cx, cp, u_, v)
    _ham_assign!(du, ∂p, -∂x, f.N)
    return nothing
end

"""
$(TYPEDEF)

Out-of-place RHS functor for a [`CTFlows.Systems.ConstrainedPseudoHamiltonianSystem`](@ref);
see [`CTFlows.Systems.ConstrainedPseudoHamIpRHS`](@ref) for the computation. Returns
`vcat(∂p, -∂x)`.

# Fields
- `h̃::PH`: base pseudo-Hamiltonian `H̃(t, x, p, u, v)`.
- `law::L`: dynamic closed-loop control law `u(t, x, p, v)`.
- `g::G`: path constraint `g(t, x, u, v)`.
- `μ::M`: multiplier `μ(t, x, p, v)`.
- `backend::B`: the AD backend.
- `N::Int`: state dimension.
- `cx::CX`: state coercion.
- `cp::CP`: costate coercion.

See also: [`CTFlows.Systems.ConstrainedPseudoHamIpRHS`](@ref).
"""
struct ConstrainedPseudoHamOoPRHS{
    PH<:Data.PseudoHamiltonian,L<:Data.ControlLaw,G,M,B,CX,CP
} <: AbstractOoPPseudoHamRHS
    h̃::PH
    law::L
    g::G
    μ::M
    backend::B
    N::Int
    cx::CX
    cp::CP
end

function (f::ConstrainedPseudoHamOoPRHS)(u, λ, t)
    x, p = _ham_split(u, f.N)
    v = variable(λ)
    cx, cp = f.cx(x), f.cp(p)
    u_ = f.law(t, cx, cp, v)
    μ_ = f.μ(t, cx, cp, v)
    h̃c = FrozenConstrainedPseudoHamiltonian(f.h̃, f.g, μ_)
    ∂x, ∂p = Differentiation.pseudo_hamiltonian_gradient(f.backend, h̃c, t, cx, cp, u_, v)
    return vcat(∂p, -∂x)
end

# =============================================================================
# Augmented functor (variable costate)
#
# ẋ = ∂/∂p[H̃+μ_·g] ; ṗ = -∂/∂x[H̃+μ_·g] ; ṗv = -∂/∂v[H̃+μ_·g]  (u_, μ_ frozen)
# =============================================================================

"""
$(TYPEDEF)

In-place augmented RHS functor for a
[`CTFlows.Systems.ConstrainedPseudoHamiltonianSystem`](@ref) with variable costate.
Extends [`CTFlows.Systems.ConstrainedPseudoHamIpRHS`](@ref) with `ṗv = -∂/∂v[H̃ + μ_·g]`
(control and multiplier frozen), computed by
[`CTBase.Differentiation.pseudo_variable_gradient`](@extref). The augmented state is
`[x; p; pv]`; the `ṗv` block picks up `−μ_ᵀ ∂g/∂v` at frozen `μ`.

# Fields
- `h̃::PH`: base pseudo-Hamiltonian `H̃(t, x, p, u, v)`.
- `law::L`: dynamic closed-loop control law `u(t, x, p, v)`.
- `g::G`: path constraint `g(t, x, u, v)`.
- `μ::M`: multiplier `μ(t, x, p, v)`.
- `backend::B`: the AD backend.
- `n_x::Int`: state dimension.
- `n_v::Int`: variable dimension.
- `cx::CX`: state coercion.
- `cp::CP`: costate coercion.

See also: [`CTFlows.Systems.ConstrainedPseudoHamIpRHS`](@ref),
[`CTFlows.Systems.PseudoHamIpAugRHS`](@ref).
"""
struct ConstrainedPseudoHamIpAugRHS{
    PH<:Data.PseudoHamiltonian,L<:Data.ControlLaw,G,M,B,CX,CP
} <: AbstractIPPseudoHamRHS
    h̃::PH
    law::L
    g::G
    μ::M
    backend::B
    n_x::Int
    n_v::Int
    cx::CX
    cp::CP
end

function (f::ConstrainedPseudoHamIpAugRHS)(du, u, λ, t)
    v = variable(λ)
    _check_aug_batch_compat(u, v)
    x, p, _ = _aug_split(u, f.n_x, f.n_v)
    cx, cp = f.cx(x), f.cp(p)
    u_ = f.law(t, cx, cp, v)
    μ_ = f.μ(t, cx, cp, v)
    h̃c = FrozenConstrainedPseudoHamiltonian(f.h̃, f.g, μ_)
    ∂x, ∂p = Differentiation.pseudo_hamiltonian_gradient(f.backend, h̃c, t, cx, cp, u_, v)
    ∂pv = Differentiation.pseudo_variable_gradient(f.backend, h̃c, t, cx, cp, u_, v)
    _aug_assign!(du, ∂p, -∂x, -∂pv, f.n_x, f.n_v)
    return nothing
end

# =============================================================================
# Display
# =============================================================================

function _rhs_conversion_label(::ConstrainedPseudoHamIpRHS)
    return "Constrained PseudoHamiltonian AD → in-place interface"
end
function _rhs_conversion_label(::ConstrainedPseudoHamOoPRHS)
    return "Constrained PseudoHamiltonian AD → out-of-place interface"
end
function _rhs_conversion_label(::ConstrainedPseudoHamIpAugRHS)
    return "Constrained PseudoHamiltonian AD → in-place augmented interface"
end
