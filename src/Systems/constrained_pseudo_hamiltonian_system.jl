# =============================================================================
# ConstrainedPseudoHamiltonianSystem — Hamiltonian system built from a constrained
# pseudo-Hamiltonian H(t,x,p,u,μ,v) = H̃(t,x,p,u,v) + μ·g(t,x,u,v), a dynamic
# closed-loop control law u(t,x,p,v) and a multiplier μ(t,x,p,v), differentiating H at
# fixed (u, μ) — the constrained `:partial` mode. The multiplier is frozen alongside the
# control in the RHS functors with `CTBase.Data.freeze_multiplier`. See
# .reports/constraints-and-duals/math.md.
# =============================================================================

"""
$(TYPEDEF)

Concrete `AbstractHamiltonianSystem` built from a constrained pseudo-Hamiltonian
`H(t,x,p,u,μ,v) = H̃(t,x,p,u,v) + μ·g(t,x,u,v)`, a dynamic closed-loop control law
`u(t,x,p,v)` and a multiplier `μ(t,x,p,v)`. It integrates

```
ẋ =  ∂H/∂p (t, x, p, u, μ, v) ,   ṗ = -∂H/∂x (t, x, p, u, μ, v)
```

with **both** the control `u = u(t,x,p,v)` **and** the multiplier value
`μ = μ(t,x,p,v)` **held fixed** during differentiation (the constrained `:partial`
mode, the partial derivatives of the PMP): the RHS evaluates them, then differentiates
[`CTBase.Data.freeze_multiplier`](@extref)`(H, μ)` at fixed `u`. The constrained `:total`
mode instead differentiates the [`CTBase.Data.ComposedConstrainedHamiltonian`](@extref)
`h(t,x,p,v) = H(t,x,p,u(t,x,p,v),μ(t,x,p,v),v)`; both modes share the same `H`, law and
multiplier.

# Type Parameters
- `TD <: TimeDependence`, `VD <: VariableDependence`: traits of the constrained
  pseudo-Hamiltonian.
- `PH <: ConstrainedPseudoHamiltonian`: concrete constrained pseudo-Hamiltonian type.
- `L <: ControlLaw`: concrete control-law type (`DynClosedLoopFeedback`).
- `M <: Multiplier`: concrete multiplier type.
- `BACKEND <: AbstractADBackend`: concrete AD backend type.

# Fields
- `h::PH`: the constrained pseudo-Hamiltonian `H(t,x,p,u,μ,v)`.
- `law::L`: the dynamic closed-loop control law.
- `μ::M`: the multiplier `μ(t,x,p,v)`.
- `backend::BACKEND`: the AD backend.

See also: [`CTFlows.Systems.PseudoHamiltonianSystem`](@extref),
[`CTBase.Data.ConstrainedPseudoHamiltonian`](@extref), [`CTBase.Data.Multiplier`](@extref).
"""
struct ConstrainedPseudoHamiltonianSystem{
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    PH<:Data.ConstrainedPseudoHamiltonian{<:Function,TD,VD},
    L<:Data.ControlLaw{<:Function,Traits.DynClosedLoopFeedback},
    M<:Data.Multiplier,
    BACKEND<:Differentiation.AbstractADBackend,
} <: AbstractHamiltonianSystem{TD,VD}
    h::PH
    law::L
    μ::M
    backend::BACKEND
end

"""
$(TYPEDSIGNATURES)

A `ConstrainedPseudoHamiltonianSystem` is AD-backed: the constrained pseudo-Hamiltonian
is differentiated at frozen `(u, μ)` to produce the RHS.

See also: [`CTFlows.Systems.ConstrainedPseudoHamiltonianSystem`](@extref),
[`CTBase.Traits.WithAD`](@extref).
"""
Traits.ad_trait(::ConstrainedPseudoHamiltonianSystem) = Traits.WithAD

# Note: no explicit outer constructor — Julia's auto-generated default outer
# constructor already matches this struct's own bounds exactly (TD, VD are
# inferable from `h`'s bound `PH<:Data.ConstrainedPseudoHamiltonian{<:Function,TD,VD}`).

# =============================================================================
# Getters
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the constrained pseudo-Hamiltonian `H(t,x,p,u,μ,v)` of a
`ConstrainedPseudoHamiltonianSystem`, with the control and the multiplier as explicit
arguments. The same object is returned in the `:total` mode, see
[`CTFlows.Systems.pseudo_hamiltonian`](@extref).

See also: [`CTFlows.Systems.ConstrainedPseudoHamiltonianSystem`](@extref).
"""
Data.pseudo_hamiltonian(sys::ConstrainedPseudoHamiltonianSystem) = sys.h

"""
$(TYPEDSIGNATURES)

Return the control law `u(t,x,p,v)` of a `ConstrainedPseudoHamiltonianSystem`.

See also: [`CTFlows.Systems.ConstrainedPseudoHamiltonianSystem`](@extref).
"""
Data.control_law(sys::ConstrainedPseudoHamiltonianSystem) = sys.law

"""
$(TYPEDSIGNATURES)

Return the multiplier `μ(t,x,p,v)` of a `ConstrainedPseudoHamiltonianSystem`.

See also: [`CTFlows.Systems.ConstrainedPseudoHamiltonianSystem`](@extref).
"""
Data.multiplier(sys::ConstrainedPseudoHamiltonianSystem) = sys.μ

"""
$(TYPEDSIGNATURES)

Return the AD backend of a `ConstrainedPseudoHamiltonianSystem`.

See also: [`CTFlows.Systems.ConstrainedPseudoHamiltonianSystem`](@extref).
"""
backend(sys::ConstrainedPseudoHamiltonianSystem) = sys.backend

"""
$(TYPEDSIGNATURES)

Return the Hamiltonian of a `ConstrainedPseudoHamiltonianSystem`, the
[`CTBase.Data.ComposedConstrainedHamiltonian`](@extref)
`h(t,x,p,v) = H(t,x,p,u(t,x,p,v),μ(t,x,p,v),v)`, **including** the constraint terms.
The same object is returned in the `:total` mode.

See also: [`CTFlows.Systems.pseudo_hamiltonian`](@extref), [`CTFlows.Systems.multiplier`](@extref).
"""
function Data.hamiltonian(sys::ConstrainedPseudoHamiltonianSystem)
    return Data.ComposedConstrainedHamiltonian(sys.h, sys.law, sys.μ)
end

# =============================================================================
# RHS builders (lazy — read the config to build type-specific functors)
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the in-place RHS ([`CTFlows.Systems.ConstrainedPseudoHamIpRHS`](@extref)) for a
`ConstrainedPseudoHamiltonianSystem`.

See also: [`CTFlows.Systems.get_oop_rhs`](@extref).
"""
function get_ip_rhs(
    sys::ConstrainedPseudoHamiltonianSystem, config::Configs.AbstractHamiltonianConfig
)
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    N = _state_dim(x0)
    cx = _coerce_state(x0)
    cp = _coerce_state(p0)
    return ConstrainedPseudoHamIpRHS(sys.h, sys.law, sys.μ, sys.backend, N, cx, cp)
end

"""
$(TYPEDSIGNATURES)

Return the out-of-place RHS ([`CTFlows.Systems.ConstrainedPseudoHamOoPRHS`](@extref)) for a
`ConstrainedPseudoHamiltonianSystem`.

See also: [`CTFlows.Systems.get_ip_rhs`](@extref).
"""
function get_oop_rhs(
    sys::ConstrainedPseudoHamiltonianSystem, config::Configs.AbstractHamiltonianConfig
)
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    N = _state_dim(x0)
    cx = _coerce_state(x0)
    cp = _coerce_state(p0)
    return ConstrainedPseudoHamOoPRHS(sys.h, sys.law, sys.μ, sys.backend, N, cx, cp)
end

"""
$(TYPEDSIGNATURES)

Return the augmented in-place RHS ([`CTFlows.Systems.ConstrainedPseudoHamIpAugRHS`](@extref))
for a `ConstrainedPseudoHamiltonianSystem` with variable costate.

See also: [`CTFlows.Systems.get_ip_rhs`](@extref).
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
        sys.h, sys.law, sys.μ, sys.backend, n_x, n_v, cx, cp
    )
end

# =============================================================================
# Trait getters
# =============================================================================

"""
$(TYPEDSIGNATURES)

A variable-dependent `ConstrainedPseudoHamiltonianSystem` supports variable-costate
integration (`ṗv = -∂H/∂v` at fixed control and multiplier).

See also: [`CTBase.Traits.SupportsVariableCostate`](@extref).
"""
function Traits.variable_costate_trait(
    ::ConstrainedPseudoHamiltonianSystem{TD,Traits.NonFixed,PH,L,M,B}
) where {
    TD<:Traits.TimeDependence,
    PH<:Data.ConstrainedPseudoHamiltonian{<:Function,TD,Traits.NonFixed},
    L<:Data.ControlLaw{<:Function,Traits.DynClosedLoopFeedback},
    M<:Data.Multiplier,
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

Shows the type name, time/variable dependence traits, and the wrapped constrained
pseudo-Hamiltonian, control law, multiplier, and AD backend.

See also: [`CTFlows.Systems.ConstrainedPseudoHamiltonianSystem`](@extref).
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
    Display.print_field(io, "", sys.h; fmt=fmt, value_style="")
    Display.print_field(io, "", sys.law; fmt=fmt, value_style="")
    Display.print_field(io, "", sys.μ; fmt=fmt, value_style="")
    return Display.print_field(
        io, "backend", sys.backend; last=true, fmt=fmt, value_style=""
    )
end
