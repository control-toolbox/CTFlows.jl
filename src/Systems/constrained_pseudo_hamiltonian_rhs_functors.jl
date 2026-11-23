# =============================================================================
# RHS Functors for ConstrainedPseudoHamiltonianSystem (constrained :partial mode)
#
# Mirror the PseudoHamiltonianSystem functors on the constrained pseudo-Hamiltonian
# H(t,x,p,u,μ,v), with BOTH the control u AND the multiplier μ frozen at their feedback
# values. Per step:
#
#   u_ = law(t, x, p, v)                    # frozen control
#   μ_ = μ(t, x, p, v)                      # frozen multiplier VALUE
#   h̃ = Data.freeze_multiplier(H, μ_)       # H̃(t,x,p,u,v) = H(t,x,p,u,μ_,v)
#
# then `pseudo_hamiltonian_gradient` (and `pseudo_variable_gradient`) differentiate h̃ at
# fixed u_: the constraint is differentiated, μ_ is a captured constant. This is the
# constrained `:partial` mode — see .reports/constraints-and-duals/math.md ("Point clé").
# The `:total` mode (Data.ComposedConstrainedHamiltonian) differentiates through μ and
# the law instead, adding (∂μ/∂x)ᵀg and (∂H/∂u)(∂u/∂x).
# =============================================================================
# Standard functors
# =============================================================================

"""
$(TYPEDEF)

In-place RHS functor for a [`CTFlows.Systems.ConstrainedPseudoHamiltonianSystem`](@extref).
Evaluates the feedback control `u_ = law(t, x, p, v)` and the multiplier value
`μ_ = μ(t, x, p, v)`, then computes, at that fixed `(u_, μ_)`,

```
ẋ =  ∂/∂p [ H̃ + μ_·g ]
ṗ = -∂/∂x [ H̃ + μ_·g ]
```

with `g` differentiated and `μ_` frozen (constrained `:partial` mode).

# Fields
- `h::PH`: constrained pseudo-Hamiltonian `H(t, x, p, u, μ, v)`.
- `law::L`: dynamic closed-loop control law `u(t, x, p, v)`.
- `μ::M`: multiplier `μ(t, x, p, v)`.
- `backend::B`: the AD backend.
- `N::Int`: state dimension.
- `cx::CX`: state coercion.
- `cp::CP`: costate coercion.

See also: [`CTFlows.Systems.ConstrainedPseudoHamOoPRHS`](@extref),
[`CTFlows.Systems.ConstrainedPseudoHamIpAugRHS`](@extref), [`CTFlows.Systems.PseudoHamIpRHS`](@extref).
"""
struct ConstrainedPseudoHamIpRHS{
    PH<:Data.ConstrainedPseudoHamiltonian,
    L<:Data.ControlLaw,
    M<:Data.Multiplier,
    B<:Differentiation.AbstractADBackend,
    CX<:Union{typeof(_safe_only),typeof(identity)},
    CP<:Union{typeof(_safe_only),typeof(identity)},
} <: AbstractIPPseudoHamRHS
    h::PH
    law::L
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
    h̃c = Data.freeze_multiplier(f.h, μ_)
    ∂x, ∂p = Differentiation.pseudo_hamiltonian_gradient(f.backend, h̃c, t, cx, cp, u_, v)
    _ham_assign!(du, ∂p, -∂x, f.N)
    return nothing
end

"""
$(TYPEDEF)

Out-of-place RHS functor for a [`CTFlows.Systems.ConstrainedPseudoHamiltonianSystem`](@extref);
see [`CTFlows.Systems.ConstrainedPseudoHamIpRHS`](@extref) for the computation. Returns
`vcat(∂p, -∂x)`.

# Fields
- `h::PH`: constrained pseudo-Hamiltonian `H(t, x, p, u, μ, v)`.
- `law::L`: dynamic closed-loop control law `u(t, x, p, v)`.
- `μ::M`: multiplier `μ(t, x, p, v)`.
- `backend::B`: the AD backend.
- `N::Int`: state dimension.
- `cx::CX`: state coercion.
- `cp::CP`: costate coercion.

See also: [`CTFlows.Systems.ConstrainedPseudoHamIpRHS`](@extref).
"""
struct ConstrainedPseudoHamOoPRHS{
    PH<:Data.ConstrainedPseudoHamiltonian,
    L<:Data.ControlLaw,
    M<:Data.Multiplier,
    B<:Differentiation.AbstractADBackend,
    CX<:Union{typeof(_safe_only),typeof(identity)},
    CP<:Union{typeof(_safe_only),typeof(identity)},
} <: AbstractOoPPseudoHamRHS
    h::PH
    law::L
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
    h̃c = Data.freeze_multiplier(f.h, μ_)
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
[`CTFlows.Systems.ConstrainedPseudoHamiltonianSystem`](@extref) with variable costate.
Extends [`CTFlows.Systems.ConstrainedPseudoHamIpRHS`](@extref) with `ṗv = -∂/∂v[H̃ + μ_·g]`
(control and multiplier frozen), computed by
[`CTBase.Differentiation.pseudo_variable_gradient`](@extref). The augmented state is
`[x; p; pv]`; the `ṗv` block picks up `−μ_ᵀ ∂g/∂v` at frozen `μ`.

# Fields
- `h::PH`: constrained pseudo-Hamiltonian `H(t, x, p, u, μ, v)`.
- `law::L`: dynamic closed-loop control law `u(t, x, p, v)`.
- `μ::M`: multiplier `μ(t, x, p, v)`.
- `backend::B`: the AD backend.
- `n_x::Int`: state dimension.
- `n_v::Int`: variable dimension.
- `cx::CX`: state coercion.
- `cp::CP`: costate coercion.

See also: [`CTFlows.Systems.ConstrainedPseudoHamIpRHS`](@extref),
[`CTFlows.Systems.PseudoHamIpAugRHS`](@extref).
"""
struct ConstrainedPseudoHamIpAugRHS{
    PH<:Data.ConstrainedPseudoHamiltonian,
    L<:Data.ControlLaw,
    M<:Data.Multiplier,
    B<:Differentiation.AbstractADBackend,
    CX<:Union{typeof(_safe_only),typeof(identity)},
    CP<:Union{typeof(_safe_only),typeof(identity)},
} <: AbstractIPPseudoHamRHS
    h::PH
    law::L
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
    h̃c = Data.freeze_multiplier(f.h, μ_)
    ∂x, ∂p = Differentiation.pseudo_hamiltonian_gradient(f.backend, h̃c, t, cx, cp, u_, v)
    ∂pv = Differentiation.pseudo_variable_gradient(f.backend, h̃c, t, cx, cp, u_, v)
    _aug_assign!(du, ∂p, -∂x, -∂pv, f.n_x, f.n_v)
    return nothing
end

# =============================================================================
# Display
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return a descriptive label for the RHS conversion performed by a constrained pseudo-Hamiltonian functor.

Used internally by `Base.show` for display.

See also: [`CTFlows.Systems.AbstractPseudoHamRHS`](@extref).
"""
function _rhs_conversion_label(::ConstrainedPseudoHamIpRHS)
    return "Constrained PseudoHamiltonian AD → in-place interface"
end

"""
$(TYPEDSIGNATURES)

Constrained pseudo-Hamiltonian AD wrapped as out-of-place interface.

See also: [`CTFlows.Systems._rhs_conversion_label`](@extref).
"""
function _rhs_conversion_label(::ConstrainedPseudoHamOoPRHS)
    return "Constrained PseudoHamiltonian AD → out-of-place interface"
end

"""
$(TYPEDSIGNATURES)

Constrained pseudo-Hamiltonian AD wrapped as in-place augmented interface.

See also: [`CTFlows.Systems._rhs_conversion_label`](@extref).
"""
function _rhs_conversion_label(::ConstrainedPseudoHamIpAugRHS)
    return "Constrained PseudoHamiltonian AD → in-place augmented interface"
end
