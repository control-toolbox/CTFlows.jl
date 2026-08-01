# =============================================================================
# ConstrainedPseudoHamiltonianSystem — Hamiltonian system built from a
# pseudo-Hamiltonian H̃(t,x,p,u,v), a dynamic closed-loop control law u(t,x,p,v),
# a path constraint g(t,x,u,v) and a multiplier μ(t,x,p,v), differentiating the
# constrained pseudo-Hamiltonian H̃ + μ·g at fixed (u, μ) — the constrained
# `:partial` mode. The multiplier is frozen alongside the control in the RHS
# functors; only H̃ and g are differentiated. See
# .reports/constraints-and-duals/math.md.
# =============================================================================

"""
$(TYPEDEF)

Concrete `AbstractHamiltonianSystem` built from a pseudo-Hamiltonian `H̃(t,x,p,u,v)`, a
dynamic closed-loop control law `u(t,x,p,v)`, a path constraint `g(t,x,u,v)` and a
multiplier `μ(t,x,p,v)`. It integrates the Hamiltonian system of the **constrained**
pseudo-Hamiltonian `H̃ + μ·g`

```
ẋ =  ∂/∂p [H̃ + μ·g] ,   ṗ = -∂/∂x [H̃ + μ·g]
```

with **both** the control `u = u(t,x,p,v)` **and** the multiplier value
`μ = μ(t,x,p,v)` **held fixed** during differentiation (the constrained `:partial`
mode): `g` is differentiated in `(x,p,v)`, `μ` is not. This is the counterpart of
[`CTFlows.Systems.PseudoHamiltonianSystem`](@ref) for constrained flows; the constrained
`:total` mode instead bakes `μ` as a function and composes with the law (see
`CTFlows.Flows.ConstrainedPseudoHamiltonianFunction`).

# Type Parameters
- `TD <: TimeDependence`, `VD <: VariableDependence`: traits of the pseudo-Hamiltonian.
- `PH <: PseudoHamiltonian`: concrete pseudo-Hamiltonian type.
- `L <: ControlLaw`: concrete control-law type (`DynClosedLoopFeedback`).
- `G`: concrete path-constraint type.
- `M`: concrete multiplier type.
- `BACKEND <: AbstractADBackend`: concrete AD backend type.

# Fields
- `h̃::PH`: the (base) pseudo-Hamiltonian.
- `law::L`: the dynamic closed-loop control law.
- `g::G`: the path constraint `g(t,x,u,v)`.
- `μ::M`: the multiplier `μ(t,x,p,v)`.
- `backend::BACKEND`: the AD backend.

See also: [`CTFlows.Systems.PseudoHamiltonianSystem`](@ref),
[`CTFlows.Systems.FrozenConstrainedPseudoHamiltonian`](@ref),
[`CTBase.Data.PathConstraint`](@extref), [`CTBase.Data.Multiplier`](@extref).
"""
struct ConstrainedPseudoHamiltonianSystem{
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    PH<:Data.PseudoHamiltonian{<:Function,TD,VD},
    L<:Data.ControlLaw{<:Function,Traits.DynClosedLoopFeedback},
    G,
    M,
    BACKEND<:Differentiation.AbstractADBackend,
} <: AbstractHamiltonianSystem{TD,VD}
    h̃::PH
    law::L
    g::G
    μ::M
    backend::BACKEND
end

"""
$(TYPEDSIGNATURES)

A `ConstrainedPseudoHamiltonianSystem` is AD-backed: the constrained pseudo-Hamiltonian
`H̃ + μ·g` is differentiated at frozen `(u, μ)` to produce the RHS.

See also: [`CTFlows.Systems.ConstrainedPseudoHamiltonianSystem`](@ref),
[`CTBase.Traits.WithAD`](@extref).
"""
Traits.ad_trait(::ConstrainedPseudoHamiltonianSystem) = Traits.WithAD

# Note: no explicit outer constructor — Julia's auto-generated default outer
# constructor already matches this struct's own bounds exactly (TD, VD are
# inferable from `h̃`'s bound `PH<:Data.PseudoHamiltonian{<:Function,TD,VD}`;
# `g`, `μ` are unbounded fields, matching the struct's own `G`, `M`).

# =============================================================================
# Getters
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the **base** pseudo-Hamiltonian `H̃` of a `ConstrainedPseudoHamiltonianSystem`
(without the `μ·g` term). The constraint and multiplier are exposed separately by
[`CTFlows.Systems.constraint`](@ref) and [`CTFlows.Systems.multiplier`](@ref).

See also: [`CTFlows.Systems.ConstrainedPseudoHamiltonianSystem`](@ref).
"""
pseudo_hamiltonian(sys::ConstrainedPseudoHamiltonianSystem) = sys.h̃

"""
$(TYPEDSIGNATURES)

Return the control law `u(t,x,p,v)` of a `ConstrainedPseudoHamiltonianSystem`.

See also: [`CTFlows.Systems.ConstrainedPseudoHamiltonianSystem`](@ref).
"""
control_law(sys::ConstrainedPseudoHamiltonianSystem) = sys.law

"""
$(TYPEDSIGNATURES)

Return the path constraint `g(t,x,u,v)` of a `ConstrainedPseudoHamiltonianSystem`.

See also: [`CTFlows.Systems.multiplier`](@ref), [`CTFlows.Systems.ConstrainedPseudoHamiltonianSystem`](@ref).
"""
constraint(sys::ConstrainedPseudoHamiltonianSystem) = sys.g

"""
$(TYPEDSIGNATURES)

Return the multiplier `μ(t,x,p,v)` of a `ConstrainedPseudoHamiltonianSystem`.

See also: [`CTFlows.Systems.constraint`](@ref), [`CTFlows.Systems.ConstrainedPseudoHamiltonianSystem`](@ref).
"""
multiplier(sys::ConstrainedPseudoHamiltonianSystem) = sys.μ

"""
$(TYPEDSIGNATURES)

Return the AD backend of a `ConstrainedPseudoHamiltonianSystem`.

See also: [`CTFlows.Systems.ConstrainedPseudoHamiltonianSystem`](@ref).
"""
backend(sys::ConstrainedPseudoHamiltonianSystem) = sys.backend

"""
$(TYPEDSIGNATURES)

Return the **base** (unconstrained) true Hamiltonian of a
`ConstrainedPseudoHamiltonianSystem` — the [`CTBase.Data.ComposedHamiltonian`](@extref)
`H(t,x,p,v) = H̃(t,x,p,u(t,x,p,v),v)`. The integrated dynamics additionally include the
`μ·g` term (with `μ` frozen during differentiation); the constraint and multiplier are
available via [`CTFlows.Systems.constraint`](@ref) / [`CTFlows.Systems.multiplier`](@ref).
On a boundary arc, where `g ≡ 0`, this base Hamiltonian coincides with the constrained
one.

See also: [`CTFlows.Systems.pseudo_hamiltonian`](@ref), [`CTFlows.Systems.constraint`](@ref).
"""
function hamiltonian(sys::ConstrainedPseudoHamiltonianSystem)
    return Data.ComposedHamiltonian(sys.h̃, sys.law)
end

# =============================================================================
# RHS builders (lazy — read the config to build type-specific functors)
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the in-place RHS ([`CTFlows.Systems.ConstrainedPseudoHamIpRHS`](@ref)) for a
`ConstrainedPseudoHamiltonianSystem`.

See also: [`CTFlows.Systems.get_oop_rhs`](@ref).
"""
function get_ip_rhs(
    sys::ConstrainedPseudoHamiltonianSystem, config::Configs.AbstractHamiltonianConfig
)
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    N = _state_dim(x0)
    cx = _coerce_state(x0)
    cp = _coerce_state(p0)
    return ConstrainedPseudoHamIpRHS(sys.h̃, sys.law, sys.g, sys.μ, sys.backend, N, cx, cp)
end

"""
$(TYPEDSIGNATURES)

Return the out-of-place RHS ([`CTFlows.Systems.ConstrainedPseudoHamOoPRHS`](@ref)) for a
`ConstrainedPseudoHamiltonianSystem`.

See also: [`CTFlows.Systems.get_ip_rhs`](@ref).
"""
function get_oop_rhs(
    sys::ConstrainedPseudoHamiltonianSystem, config::Configs.AbstractHamiltonianConfig
)
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    N = _state_dim(x0)
    cx = _coerce_state(x0)
    cp = _coerce_state(p0)
    return ConstrainedPseudoHamOoPRHS(sys.h̃, sys.law, sys.g, sys.μ, sys.backend, N, cx, cp)
end

"""
$(TYPEDSIGNATURES)

Return the augmented in-place RHS ([`CTFlows.Systems.ConstrainedPseudoHamIpAugRHS`](@ref))
for a `ConstrainedPseudoHamiltonianSystem` with variable costate.

See also: [`CTFlows.Systems.get_ip_rhs`](@ref).
"""
function get_ip_rhs_augmented(
    sys::ConstrainedPseudoHamiltonianSystem,
    config::Configs.AbstractAugmentedHamiltonianConfig,
)
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    n_x = _state_dim(x0)
    pv0 = Configs.initial_variable_costate(config)
    n_v = _state_dim(pv0)
    cx = _coerce_state(x0)
    cp = _coerce_state(p0)
    return ConstrainedPseudoHamIpAugRHS(
        sys.h̃, sys.law, sys.g, sys.μ, sys.backend, n_x, n_v, cx, cp
    )
end

# =============================================================================
# Trait getters
# =============================================================================

"""
$(TYPEDSIGNATURES)

A variable-dependent `ConstrainedPseudoHamiltonianSystem` supports variable-costate
integration (`ṗv = -∂/∂v[H̃ + μ·g]` at fixed control and multiplier).

See also: [`CTBase.Traits.SupportsVariableCostate`](@extref).
"""
function Traits.variable_costate_trait(
    ::ConstrainedPseudoHamiltonianSystem{TD,Traits.NonFixed,PH,L,G,M,B}
) where {
    TD<:Traits.TimeDependence,
    PH<:Data.PseudoHamiltonian{<:Function,TD,Traits.NonFixed},
    L<:Data.ControlLaw{<:Function,Traits.DynClosedLoopFeedback},
    G,
    M,
    B<:Differentiation.AbstractADBackend,
}
    return Traits.SupportsVariableCostate
end

# =============================================================================
# Base.show
# =============================================================================

"""
$(TYPEDSIGNATURES)

Display a compact representation of a `ConstrainedPseudoHamiltonianSystem`.

Shows the type name, time/variable dependence traits, and the wrapped pseudo-Hamiltonian,
control law, constraint, multiplier, and AD backend.

See also: [`CTFlows.Systems.ConstrainedPseudoHamiltonianSystem`](@ref).
"""
function Base.show(io::IO, sys::ConstrainedPseudoHamiltonianSystem)
    fmt = Display.format_codes(io)
    Display.print_header(io, "ConstrainedPseudoHamiltonianSystem"; fmt=fmt)
    Display.print_field(
        io,
        "time_dependence",
        nameof(Traits.time_dependence(sys));
        fmt=fmt,
        value_style=fmt.type,
    )
    Display.print_field(
        io,
        "variable_dependence",
        nameof(Traits.variable_dependence(sys));
        fmt=fmt,
        value_style=fmt.type,
    )
    Display.print_field(io, "", sys.h̃; fmt=fmt, value_style="")
    Display.print_field(io, "", sys.law; fmt=fmt, value_style="")
    Display.print_field(io, "", sys.g; fmt=fmt, value_style="")
    Display.print_field(io, "", sys.μ; fmt=fmt, value_style="")
    return Display.print_field(
        io, "backend", sys.backend; last=true, fmt=fmt, value_style=""
    )
end
