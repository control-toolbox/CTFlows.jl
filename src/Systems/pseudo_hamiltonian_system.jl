# =============================================================================
# PseudoHamiltonianSystem — Hamiltonian system built from a pseudo-Hamiltonian H̃
# and a dynamic closed-loop control law u(t,x,p,v), differentiating at fixed u.
# =============================================================================

"""
$(TYPEDEF)

Concrete `AbstractHamiltonianSystem` built from a pseudo-Hamiltonian `H̃(t,x,p,u,v)`
and a dynamic closed-loop control law `u(t,x,p,v)`. It integrates the Hamiltonian
system

```
ẋ =  ∂H̃/∂p ,   ṗ = -∂H̃/∂x
```

with the control **held fixed** at the feedback value `u = u(t,x,p,v)` during
differentiation (the `:partial` mode). This coincides with the true Hamiltonian flow
of [`CTBase.Data.ComposedHamiltonian`](@extref) only where the feedback is stationary
(`∂H̃/∂u = 0`).

# Type Parameters
- `TD <: TimeDependence`, `VD <: VariableDependence`: traits of the pseudo-Hamiltonian.
- `PH <: PseudoHamiltonian`: concrete pseudo-Hamiltonian type.
- `L <: ControlLaw`: concrete control-law type (`DynClosedLoopFeedback`).
- `BACKEND <: AbstractADBackend`: concrete AD backend type.

# Fields
- `h̃::PH`: the pseudo-Hamiltonian.
- `law::L`: the dynamic closed-loop control law.
- `backend::BACKEND`: the AD backend.

See also: [`CTFlows.Systems.HamiltonianSystem`](@extref),
[`CTBase.Data.PseudoHamiltonian`](@extref), [`CTBase.Data.ComposedHamiltonian`](@extref).
"""
struct PseudoHamiltonianSystem{
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    PH<:Data.PseudoHamiltonian{<:Function,TD,VD},
    L<:Data.ControlLaw{<:Function,Traits.DynClosedLoopFeedback},
    BACKEND<:Differentiation.AbstractADBackend,
} <: AbstractHamiltonianSystem{TD,VD}
    h̃::PH
    law::L
    backend::BACKEND
end

Traits.ad_trait(::PseudoHamiltonianSystem) = Traits.WithAD

# Note: no explicit outer constructor — Julia's auto-generated default outer
# constructor already matches this struct's own bounds exactly (TD, VD are
# inferable from `h̃`'s bound `PH<:Data.PseudoHamiltonian{<:Function,TD,VD}`).

# =============================================================================
# Getters
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the pseudo-Hamiltonian `H̃` of a `PseudoHamiltonianSystem`.

See also: [`CTFlows.Systems.PseudoHamiltonianSystem`](@extref), [`CTFlows.Systems.control_law`](@extref).
"""
pseudo_hamiltonian(sys::PseudoHamiltonianSystem) = sys.h̃

"""
$(TYPEDSIGNATURES)

Return the control law `u(t,x,p,v)` of a `PseudoHamiltonianSystem`.

See also: [`CTFlows.Systems.PseudoHamiltonianSystem`](@extref), [`CTFlows.Systems.pseudo_hamiltonian`](@extref).
"""
control_law(sys::PseudoHamiltonianSystem) = sys.law

"""
$(TYPEDSIGNATURES)

Return the AD backend of a `PseudoHamiltonianSystem`.

See also: [`CTFlows.Systems.PseudoHamiltonianSystem`](@extref).
"""
backend(sys::PseudoHamiltonianSystem) = sys.backend

"""
$(TYPEDSIGNATURES)

Return the true Hamiltonian of a `PseudoHamiltonianSystem` — the
[`CTBase.Data.ComposedHamiltonian`](@extref) `H(t,x,p,v) = H̃(t,x,p,u(t,x,p,v),v)`
obtained by eliminating the control with the feedback law. Built on the fly.

See also: [`CTFlows.Systems.pseudo_hamiltonian`](@extref), [`CTFlows.Systems.HamiltonianSystem`](@extref).
"""
function hamiltonian(sys::PseudoHamiltonianSystem)
    return Data.ComposedHamiltonian(sys.h̃, sys.law)
end

# =============================================================================
# RHS builders (lazy — read the config to build type-specific functors)
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the in-place RHS ([`CTFlows.Systems.PseudoHamIpRHS`](@extref)) for a
`PseudoHamiltonianSystem`.

See also: [`CTFlows.Systems.get_oop_rhs`](@extref).
"""
function get_ip_rhs(sys::PseudoHamiltonianSystem, config::Configs.AbstractHamiltonianConfig)
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    N = _state_dim(x0)
    cx = _coerce_state(x0)
    cp = _coerce_state(p0)
    return PseudoHamIpRHS(sys.h̃, sys.law, sys.backend, N, cx, cp)
end

"""
$(TYPEDSIGNATURES)

Return the out-of-place RHS ([`CTFlows.Systems.PseudoHamOoPRHS`](@extref)) for a
`PseudoHamiltonianSystem`.

See also: [`CTFlows.Systems.get_ip_rhs`](@extref).
"""
function get_oop_rhs(
    sys::PseudoHamiltonianSystem, config::Configs.AbstractHamiltonianConfig
)
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    N = _state_dim(x0)
    cx = _coerce_state(x0)
    cp = _coerce_state(p0)
    return PseudoHamOoPRHS(sys.h̃, sys.law, sys.backend, N, cx, cp)
end

"""
$(TYPEDSIGNATURES)

Return the augmented in-place RHS ([`CTFlows.Systems.PseudoHamIpAugRHS`](@extref)) for a
`PseudoHamiltonianSystem` with variable costate.

See also: [`CTFlows.Systems.get_ip_rhs`](@extref).
"""
function get_ip_rhs_augmented(
    sys::PseudoHamiltonianSystem, config::Configs.AbstractAugmentedHamiltonianConfig
)
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    n_x = _state_dim(x0)
    pv0 = Configs.initial_variable_costate(config)
    n_v = _state_dim(pv0)
    cx = _coerce_state(x0)
    cp = _coerce_state(p0)
    return PseudoHamIpAugRHS(sys.h̃, sys.law, sys.backend, n_x, n_v, cx, cp)
end

# =============================================================================
# Trait getters
# =============================================================================

"""
$(TYPEDSIGNATURES)

A variable-dependent `PseudoHamiltonianSystem` supports variable-costate integration
(`ṗv = -∂H̃/∂v` at fixed control), analogous to `HamiltonianSystem`.

See also: [`CTBase.Traits.SupportsVariableCostate`](@extref).
"""
function Traits.variable_costate_trait(
    ::PseudoHamiltonianSystem{TD,Traits.NonFixed,PH,L,B}
) where {
    TD<:Traits.TimeDependence,
    PH<:Data.PseudoHamiltonian{<:Function,TD,Traits.NonFixed},
    L<:Data.ControlLaw{<:Function,Traits.DynClosedLoopFeedback},
    B<:Differentiation.AbstractADBackend,
}
    return Traits.SupportsVariableCostate
end

# =============================================================================
# Base.show
# =============================================================================

"""
$(TYPEDSIGNATURES)

Display a compact representation of a `PseudoHamiltonianSystem`.

Shows the type name, time/variable dependence traits, and the wrapped pseudo-Hamiltonian,
control law, and AD backend.

See also: [`CTFlows.Systems.PseudoHamiltonianSystem`](@extref).
"""
function Base.show(io::IO, sys::PseudoHamiltonianSystem)
    fmt = Display.format_codes(io)
    Display.print_header(io, "PseudoHamiltonianSystem"; fmt=fmt)
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
    return Display.print_field(
        io, "backend", sys.backend; last=true, fmt=fmt, value_style=""
    )
end
