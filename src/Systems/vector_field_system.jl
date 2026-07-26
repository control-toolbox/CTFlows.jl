"""
$(TYPEDEF)

Concrete `AbstractSystem` wrapping an [`CTBase.Data.AbstractVectorField`](@extref). The
variable for `NonFixed` vector fields is **not** stored here; it is passed at flow-call
time via the `variable` kwarg and threaded through `ODEProblem`'s `p` slot
wrapped in a `Systems.ODEParameters` struct.

The system does not store pre-computed RHS closures. Instead, closures are built
lazily by `get_ip_rhs`/`get_oop_rhs` based on the actual initial condition type,
coercing a 1-D state to a scalar before calling the user's vector field (issue
[control-toolbox/CTFlows.jl#357](https://github.com/control-toolbox/CTFlows.jl/issues/357))
— mirroring [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref).

# Fields
- `vf::F`: the underlying vector field (any `Data.AbstractVectorField{TD,VD,MD}`).

# Example
\`\`\`julia-repl
julia> using CTFlows.Systems

julia> vf = Data.VectorField(x -> -x)
VectorField: autonomous, fixed (no variable), out-of-place
  natural call: f(x)
  uniform call: f(t, x, v)

julia> sys = VectorFieldSystem(vf)
VectorFieldSystem
├─ time_dependence: Autonomous
├─ variable_dependence: Fixed
└─ VectorField: autonomous, fixed (no variable), out-of-place
   natural call: f(x)
   uniform call: f(t, x, v)
\`\`\`

See also: [`CTBase.Data.VectorField`](@extref), `TimeDependence`, [`CTBase.Traits.VariableDependence`](@extref), [`CTFlows.Systems.ODEParameters`](@ref).
"""
struct VectorFieldSystem{
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    MD<:Traits.AbstractMutabilityTrait,
    F<:Data.AbstractVectorField{TD,VD,MD},
} <: AbstractStateSystem{TD,VD}
    vf::F
end

# Note: no explicit outer constructor — Julia's auto-generated default outer
# constructor already matches this struct's own bounds exactly (all 4 type
# parameters are inferable from the `vf` field's type), same as
# HamiltonianVectorFieldSystem.

# =============================================================================
# Getter
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the underlying vector field of a `VectorFieldSystem`, as a
[`CTBase.Data.AbstractVectorField`](@extref) — the field `X(t, x, v)` integrated by the
state flow.

See also: [`CTFlows.Systems.VectorFieldSystem`](@ref), [`CTFlows.Systems.hamiltonian_vector_field`](@ref).
"""
vector_field(sys::VectorFieldSystem) = sys.vf

"""
$(TYPEDSIGNATURES)

Return the in-place right-hand side for an out-of-place `VectorFieldSystem`.

Lazy implementation: reads `x0` from the config to build a type-specific closure,
coercing the state to a scalar before calling the user's vector field when the
declared dimension is 1 (issue #357) — see
[`CTFlows.Systems._coerce_state`](@ref).

# Arguments
- `sys::VectorFieldSystem{..., OutOfPlace, ...}`: The out-of-place system.
- `config::Configs.AbstractStateConfig`: The state configuration.

# Returns
- `IPVFOoPRHS`: An in-place RHS functor with signature `(du, u, p, t) -> nothing`.

See also: [`CTFlows.Systems.get_oop_rhs`](@ref).
"""
function get_ip_rhs(
    sys::VectorFieldSystem{TD,VD,Traits.OutOfPlace,F}, config::Configs.AbstractStateConfig
) where {
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    F<:Data.AbstractVectorField{TD,VD,Traits.OutOfPlace},
}
    x0 = Configs.initial_state(config)
    return IPVFOoPRHS(sys.vf, _coerce_state(x0))
end

"""
$(TYPEDSIGNATURES)

Return the in-place right-hand side for an in-place `VectorFieldSystem`.

Lazy implementation: reads `x0` from the config to build a type-specific closure.

# Arguments
- `sys::VectorFieldSystem{..., InPlace, ...}`: The in-place system.
- `config::Configs.AbstractStateConfig`: The state configuration.

# Returns
- `IPVFIpRHS`: An in-place RHS functor with signature `(du, u, p, t) -> nothing`.

See also: [`CTFlows.Systems.get_oop_rhs`](@ref).
"""
function get_ip_rhs(
    sys::VectorFieldSystem{TD,VD,Traits.InPlace,F}, config::Configs.AbstractStateConfig
) where {
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    F<:Data.AbstractVectorField{TD,VD,Traits.InPlace},
}
    x0 = Configs.initial_state(config)
    return IPVFIpRHS(sys.vf, _coerce_state(x0))
end

"""
$(TYPEDSIGNATURES)

Return the out-of-place right-hand side for an out-of-place `VectorFieldSystem`.

Lazy implementation: reads `x0` from the config to build a type-specific closure.

# Arguments
- `sys::VectorFieldSystem{..., OutOfPlace, ...}`: The out-of-place system.
- `config::Configs.AbstractStateConfig`: The state configuration.

# Returns
- `OoPVFOoPRHS`: An out-of-place RHS functor with signature `(u, p, t) -> du`.

See also: [`CTFlows.Systems.get_ip_rhs`](@ref).
"""
function get_oop_rhs(
    sys::VectorFieldSystem{TD,VD,Traits.OutOfPlace,F}, config::Configs.AbstractStateConfig
) where {
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    F<:Data.AbstractVectorField{TD,VD,Traits.OutOfPlace},
}
    x0 = Configs.initial_state(config)
    return OoPVFOoPRHS(sys.vf, _coerce_state(x0))
end

"""
$(TYPEDSIGNATURES)

Return the out-of-place right-hand side for an in-place `VectorFieldSystem`.

Lazy implementation: reads `x0` from the config to build a type-specific closure.
This method is called when `!ismutable(u0)`, so the finalize path is used whenever
`x0` is itself immutable (e.g. `SVector`).

# Arguments
- `sys::VectorFieldSystem{..., InPlace, ...}`: The in-place system.
- `config::Configs.AbstractStateConfig`: The state configuration.

# Returns
- `OoPVFIpRHS` or `OoPVFIpFinalizeRHS`: An out-of-place RHS functor.

# Notes
- Emits a performance warning when called with immutable initial conditions.

See also: [`CTFlows.Systems.get_ip_rhs`](@ref).
"""
function get_oop_rhs(
    sys::VectorFieldSystem{TD,VD,Traits.InPlace,F}, config::Configs.AbstractStateConfig
) where {
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    F<:Data.AbstractVectorField{TD,VD,Traits.InPlace},
}
    x0 = Configs.initial_state(config)
    cx = _coerce_state(x0)
    if !ismutable(x0)
        @warn "InPlace VectorField with immutable u0 (e.g. SVector): consider using an out-of-place function for better performance."
        return OoPVFIpFinalizeRHS(sys.vf, cx)
    end
    return OoPVFIpRHS(sys.vf, cx)
end

# =============================================================================
# Base.show
# =============================================================================

"""
$(TYPEDSIGNATURES)

Display a compact representation of a VectorFieldSystem.

Shows the type name and the wrapped VectorField with its traits.

# Arguments
- `io::IO`: The IO stream to write to.
- `sys::VectorFieldSystem`: The VectorFieldSystem to display.

See also: [`CTFlows.Systems.VectorFieldSystem`](@ref).
"""
function Base.show(
    io::IO, sys::VectorFieldSystem{TD,VD,MD,F}
) where {
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    MD<:Traits.AbstractMutabilityTrait,
    F<:Data.AbstractVectorField{TD,VD,MD},
}
    fmt = Display.format_codes(io)
    Display.print_header(io, "VectorFieldSystem"; fmt=fmt)
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
    return Display.print_field(io, "", sys.vf; last=true, fmt=fmt, value_style="")
end

"""
$(TYPEDSIGNATURES)

Display a VectorFieldSystem in the REPL with text/plain MIME type.

Delegates to the compact show method.

# Arguments
- `io::IO`: The IO stream to write to.
- `::MIME"text/plain"`: The MIME type for REPL display.
- `sys::VectorFieldSystem`: The VectorFieldSystem to display.

See also: [`CTFlows.Systems.VectorFieldSystem`](@ref).
"""
function Base.show(io::IO, ::MIME"text/plain", sys::VectorFieldSystem)
    return show(io, sys)
end
