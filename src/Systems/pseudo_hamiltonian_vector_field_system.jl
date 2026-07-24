# =============================================================================
# PseudoHamiltonianVectorFieldSystem — Hamiltonian system built from a
# PseudoHamiltonianVectorField (ẋ,ṗ) = (dx,dp)(t,x,p,u,v) and a DynClosedLoop
# control law u(t,x,p,v), with NO automatic differentiation.
# =============================================================================

"""
$(TYPEDEF)

Concrete `AbstractHamiltonianSystem` built from a pseudo-Hamiltonian vector field
`h̃vf(t,x,p,u,v) = (ẋ,ṗ)` (already differentiated by the user, no AD) and a dynamic
closed-loop control law `u(t,x,p,v)`. It integrates

```
ẋ, ṗ = h̃vf(t, x, p, u, v)   with   u = law(t, x, p, v)
```

by evaluating the feedback law once per step and passing the resulting `u` directly
to `h̃vf` — the vector-field analogue of [`CTFlows.Systems.PseudoHamiltonianSystem`](@ref),
which instead differentiates a scalar pseudo-Hamiltonian `H̃` by AD at fixed `u`. Here
there is no AD anywhere: `h̃vf` already returns the derivatives directly.

# Type Parameters
- `F`: concrete type of the wrapped pseudo-Hamiltonian vector field function.
- `TD <: TimeDependence`, `VD <: VariableDependence`, `MD <: AbstractMutabilityTrait`:
  traits of the pseudo-Hamiltonian vector field.
- `L <: ControlLaw`: concrete control-law type (`DynClosedLoopFeedback`).

# Fields
- `h̃vf::PseudoHamiltonianVectorField{F,TD,VD,MD}`: the pseudo-Hamiltonian vector field.
- `law::L`: the dynamic closed-loop control law.

See also: [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref),
[`CTFlows.Systems.PseudoHamiltonianSystem`](@ref),
[`CTBase.Data.PseudoHamiltonianVectorField`](@extref).
"""
struct PseudoHamiltonianVectorFieldSystem{
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    MD<:Traits.AbstractMutabilityTrait,
    L<:Data.ControlLaw{<:Function,Traits.DynClosedLoopFeedback},
} <: AbstractHamiltonianSystem{TD,VD}
    h̃vf::Data.PseudoHamiltonianVectorField{F,TD,VD,MD}
    law::L
end

Traits.ad_trait(::PseudoHamiltonianVectorFieldSystem) = Traits.WithoutAD

# Note: no explicit outer constructor — Julia's auto-generated default outer
# constructor already matches this struct's own bounds exactly (all 5 type
# parameters are inferable from the `h̃vf`/`law` fields' types).

# =============================================================================
# RHS builders (lazy — read the config to build type-specific functors)
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the in-place RHS ([`CTFlows.Systems.IPPseudoHVFOoPRHS`](@ref)) for a
`PseudoHamiltonianVectorFieldSystem` wrapping an out-of-place vector field.

See also: [`CTFlows.Systems.get_oop_rhs`](@ref).
"""
function get_ip_rhs(
    sys::PseudoHamiltonianVectorFieldSystem{F,TD,VD,Traits.OutOfPlace},
    config::Configs.AbstractHamiltonianConfig,
) where {F<:Function,TD<:Traits.TimeDependence,VD<:Traits.VariableDependence}
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    return IPPseudoHVFOoPRHS(
        sys.h̃vf, sys.law, _state_dim(x0), _coerce_state(x0), _coerce_state(p0)
    )
end

"""
$(TYPEDSIGNATURES)

Return the in-place RHS ([`CTFlows.Systems.IPPseudoHVFIpRHS`](@ref)) for a
`PseudoHamiltonianVectorFieldSystem` wrapping an in-place vector field.

See also: [`CTFlows.Systems.get_oop_rhs`](@ref).
"""
function get_ip_rhs(
    sys::PseudoHamiltonianVectorFieldSystem{F,TD,VD,Traits.InPlace},
    config::Configs.AbstractHamiltonianConfig,
) where {F<:Function,TD<:Traits.TimeDependence,VD<:Traits.VariableDependence}
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    return IPPseudoHVFIpRHS(
        sys.h̃vf, sys.law, _state_dim(x0), _coerce_state(x0), _coerce_state(p0)
    )
end

"""
$(TYPEDSIGNATURES)

Return the out-of-place RHS ([`CTFlows.Systems.OoPPseudoHVFOoPRHS`](@ref)) for a
`PseudoHamiltonianVectorFieldSystem` wrapping an out-of-place vector field.

See also: [`CTFlows.Systems.get_ip_rhs`](@ref).
"""
function get_oop_rhs(
    sys::PseudoHamiltonianVectorFieldSystem{F,TD,VD,Traits.OutOfPlace},
    config::Configs.AbstractHamiltonianConfig,
) where {F<:Function,TD<:Traits.TimeDependence,VD<:Traits.VariableDependence}
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    return OoPPseudoHVFOoPRHS(
        sys.h̃vf, sys.law, _state_dim(x0), _coerce_state(x0), _coerce_state(p0)
    )
end

"""
$(TYPEDSIGNATURES)

Return the out-of-place RHS for a `PseudoHamiltonianVectorFieldSystem` wrapping an
in-place vector field.

# Returns
- [`CTFlows.Systems.OoPPseudoHVFIpFinalizeRHS`](@ref) for immutable initial conditions
  (e.g. `SVector`), converting the result back to the input array type.
- [`CTFlows.Systems.OoPPseudoHVFIpRHS`](@ref) otherwise.

# Notes
- Emits a performance warning when called with immutable initial conditions.

See also: [`CTFlows.Systems.get_ip_rhs`](@ref).
"""
function get_oop_rhs(
    sys::PseudoHamiltonianVectorFieldSystem{F,TD,VD,Traits.InPlace},
    config::Configs.AbstractHamiltonianConfig,
) where {F<:Function,TD<:Traits.TimeDependence,VD<:Traits.VariableDependence}
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    if !ismutable(x0)
        @warn "InPlace PseudoHamiltonianVectorField with immutable u0 (e.g. SVector): consider using an out-of-place function for better performance."
        return OoPPseudoHVFIpFinalizeRHS(
            sys.h̃vf, sys.law, _state_dim(x0), _coerce_state(x0), _coerce_state(p0)
        )
    end
    return OoPPseudoHVFIpRHS(
        sys.h̃vf, sys.law, _state_dim(x0), _coerce_state(x0), _coerce_state(p0)
    )
end

"""
$(TYPEDSIGNATURES)

Return the augmented in-place RHS ([`CTFlows.Systems.IPPseudoHVFOoPAugRHS`](@ref)) for
a `PseudoHamiltonianVectorFieldSystem` wrapping an out-of-place vector field, with
variable costate.

See also: [`CTFlows.Systems.get_ip_rhs`](@ref).
"""
function get_ip_rhs_augmented(
    sys::PseudoHamiltonianVectorFieldSystem{F,TD,VD,Traits.OutOfPlace},
    config::Configs.AbstractAugmentedHamiltonianConfig,
) where {F<:Function,TD<:Traits.TimeDependence,VD<:Traits.VariableDependence}
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    n_x = _state_dim(x0)
    pv0 = Configs.initial_variable_costate(config)
    n_v = _state_dim(pv0)
    return IPPseudoHVFOoPAugRHS(
        sys.h̃vf, sys.law, n_x, n_v, _coerce_state(x0), _coerce_state(p0)
    )
end

"""
$(TYPEDSIGNATURES)

Return the augmented in-place RHS ([`CTFlows.Systems.IPPseudoHVFIpAugRHS`](@ref)) for
a `PseudoHamiltonianVectorFieldSystem` wrapping an in-place vector field, with
variable costate.

See also: [`CTFlows.Systems.get_ip_rhs`](@ref).
"""
function get_ip_rhs_augmented(
    sys::PseudoHamiltonianVectorFieldSystem{F,TD,VD,Traits.InPlace},
    config::Configs.AbstractAugmentedHamiltonianConfig,
) where {F<:Function,TD<:Traits.TimeDependence,VD<:Traits.VariableDependence}
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    n_x = _state_dim(x0)
    pv0 = Configs.initial_variable_costate(config)
    n_v = _state_dim(pv0)
    return IPPseudoHVFIpAugRHS(
        sys.h̃vf, sys.law, n_x, n_v, _coerce_state(x0), _coerce_state(p0)
    )
end

# =============================================================================
# Trait getters
# =============================================================================

"""
$(TYPEDSIGNATURES)

A variable-dependent `PseudoHamiltonianVectorFieldSystem` supports variable-costate
integration (`ṗv = -∂H̃/∂v` at fixed control, supplied directly by `h̃vf`), analogous
to [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref).

See also: [`CTBase.Traits.SupportsVariableCostate`](@extref).
"""
function Traits.variable_costate_trait(
    ::PseudoHamiltonianVectorFieldSystem{F,TD,Traits.NonFixed,MD,L}
) where {
    F<:Function,
    TD<:Traits.TimeDependence,
    MD<:Traits.AbstractMutabilityTrait,
    L<:Data.ControlLaw{<:Function,Traits.DynClosedLoopFeedback},
}
    return Traits.SupportsVariableCostate
end

# =============================================================================
# Base.show
# =============================================================================

"""
$(TYPEDSIGNATURES)

Display a compact representation of a `PseudoHamiltonianVectorFieldSystem`.

Shows the type name, the wrapped `PseudoHamiltonianVectorField`'s traits, and the
control law.

See also: [`CTFlows.Systems.PseudoHamiltonianVectorFieldSystem`](@ref).
"""
function Base.show(
    io::IO, sys::PseudoHamiltonianVectorFieldSystem{F,TD,VD,MD,L}
) where {
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    MD<:Traits.AbstractMutabilityTrait,
    L<:Data.ControlLaw{<:Function,Traits.DynClosedLoopFeedback},
}
    fmt = Display.format_codes(io)
    wraps = "PseudoHamiltonianVectorField: $(Data._td_label(TD)), $(Data._vd_label(VD)), $(Data._md_label(MD))"
    Display.print_header(io, "PseudoHamiltonianVectorFieldSystem"; fmt=fmt)
    Display.print_field(io, "wraps", wraps; fmt=fmt, value_style="")
    return Display.print_field(io, "", sys.law; last=true, fmt=fmt, value_style="")
end

"""
$(TYPEDSIGNATURES)

Display a `PseudoHamiltonianVectorFieldSystem` in the REPL with text/plain MIME type.

Delegates to the compact `show` method.

See also: [`CTFlows.Systems.PseudoHamiltonianVectorFieldSystem`](@ref).
"""
function Base.show(io::IO, ::MIME"text/plain", sys::PseudoHamiltonianVectorFieldSystem)
    return show(io, sys)
end
