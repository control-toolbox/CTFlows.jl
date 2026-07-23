"""
$(TYPEDEF)

Concrete `AbstractSystem` wrapping an [`CTBase.Data.AbstractVectorField`](@extref). The
variable for `NonFixed` vector fields is **not** stored here; it is passed at flow-call
time via the `variable` kwarg and threaded through `ODEProblem`'s `p` slot
wrapped in a `Systems.ODEParameters` struct.

# Fields
- `vf::F`: the underlying vector field (any `Data.AbstractVectorField{TD,VD,MD}`).
- `rhs::RHS`: the pre-computed in-place right-hand side closure with signature `(du, u, p, t) -> nothing`.
- `rhs_oop::OOPROHS`: the pre-computed out-of-place right-hand side closure with signature `(u, p, t) -> du`.
- `rhs_oop_finalize::FINRHS`: the finalize closure for in-place vector fields with immutable initial conditions, or `nothing` for out-of-place vector fields.

# Example
\`\`\`julia-repl
julia> using CTFlows.Systems

julia> vf = VectorField(x -> -x; autonomous=true, variable=false)
VectorField
  time_dependence: Autonomous
  variable_dependence: Fixed
  mutability: OutOfPlace
  function: var"#1"

julia> sys = VectorFieldSystem(vf)
VectorFieldSystem
  time_dependence: Autonomous
  variable_dependence: Fixed
  mutability: OutOfPlace
  vector_field: VectorField{var"#1", Autonomous, Fixed, OutOfPlace}
\`\`\`

See also: [`CTBase.Data.VectorField`](@extref), `TimeDependence`, [`CTBase.Traits.VariableDependence`](@extref), [`CTFlows.Systems.ODEParameters`](@ref).
"""
struct VectorFieldSystem{
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    MD<:Traits.AbstractMutabilityTrait,
    F<:Data.AbstractVectorField{TD,VD,MD},
    RHS<:AbstractIPRHS,
    OOPROHS<:AbstractOoPRHS,
    FINRHS,
} <: AbstractStateSystem{TD,VD}
    vf::F
    rhs::RHS
    rhs_oop::OOPROHS
    rhs_oop_finalize::FINRHS
end

# =============================================================================
# Constructors
# =============================================================================

# Out-of-place: accepts any AbstractVectorField (VectorField, ComposedVectorField, …).
function VectorFieldSystem(
    vf::Data.AbstractVectorField{TD,VD,Traits.OutOfPlace}
) where {TD<:Traits.TimeDependence,VD<:Traits.VariableDependence}
    rhs = IPVFOoPRHS(vf)
    rhs_oop = OoPVFOoPRHS(vf)
    rhs_oop_finalize = nothing
    return VectorFieldSystem{
        TD,VD,Traits.OutOfPlace,typeof(vf),typeof(rhs),typeof(rhs_oop),Nothing
    }(
        vf, rhs, rhs_oop, rhs_oop_finalize
    )
end

function VectorFieldSystem(
    vf::Data.VectorField{F,TD,VD,Traits.InPlace}
) where {F<:Function,TD<:Traits.TimeDependence,VD<:Traits.VariableDependence}
    rhs = IPVFIpRHS(vf)
    rhs_oop = OoPVFIpRHS(vf)
    rhs_oop_finalize = OoPVFIpFinalizeRHS(vf)
    return VectorFieldSystem{
        TD,VD,Traits.InPlace,typeof(vf),typeof(rhs),typeof(rhs_oop),typeof(rhs_oop_finalize)
    }(
        vf, rhs, rhs_oop, rhs_oop_finalize
    )
end

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

In-place right-hand side for a `VectorFieldSystem`. Returns the pre-computed
closure stored in the system, which has signature `(du, u, p, t) -> nothing` and
uses the uniform `(t, x, v)` call on the underlying `VectorField`, where `p`
is a `Systems.ODEParameters` wrapper containing the variable (or `nothing`
for `Fixed` systems).

# Arguments
- `sys::VectorFieldSystem`: The system for which to return the RHS function.

# Returns
- `Function`: The pre-computed closure with signature `(du, u, p, t) -> nothing`.

# Example
\`\`\`julia
using CTFlows.Systems

vf = VectorField(x -> -x; autonomous=true, variable=false)
sys = VectorFieldSystem(vf)
rhs = Systems.get_ip_rhs(sys, config)

du = zeros(2)
u = [1.0, 2.0]
p = Systems.ODEParameters(nothing)
rhs(du, u, p, 0.0)
# du is now [-1.0, -2.0]
\`\`\`

# Notes
- The closure is computed once at construction time for performance.
- Multiple calls to `get_ip_rhs` return the same function object.
- The closure reads `variable(p)` to access the actual variable value.

See also: [`CTFlows.Systems.VectorFieldSystem`](@ref), [`CTFlows.Systems.AbstractSystem`](@ref), [`CTFlows.Systems.ODEParameters`](@ref).
"""

"""
$(TYPEDSIGNATURES)

Return the in-place right-hand side for a `VectorFieldSystem`.

Eager implementation: ignores the config and returns the pre-computed closure.

# Arguments
- `sys::VectorFieldSystem`: The vector field system.
- `_`: The configuration (ignored).

# Returns
- `Function`: The pre-computed in-place closure with signature `(du, u, p, t) -> nothing`.

See also: [`CTFlows.Systems.get_oop_rhs`](@ref), `rhs`.
"""
function get_ip_rhs(sys::VectorFieldSystem, _)
    return sys.rhs
end

"""
$(TYPEDSIGNATURES)

Return the out-of-place right-hand side for a `VectorFieldSystem`.

Eager implementation: ignores the config and returns the pre-computed closure.
For `InPlace` systems, returns `rhs_oop_finalize` (the finalize path) since
`get_oop_rhs` is only called when `!ismutable(u0)`.

# Arguments
- `sys::VectorFieldSystem{..., OutOfPlace, ...}`: The out-of-place system.
- `_`: The configuration (ignored).

# Returns
- `Function`: The pre-computed out-of-place closure with signature `(u, p, t) -> du`.

See also: [`CTFlows.Systems.get_ip_rhs`](@ref).
"""
function get_oop_rhs(
    sys::VectorFieldSystem{TD,VD,Traits.OutOfPlace,F,RHS,OOPROHS,Nothing}, _
) where {
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    F<:Data.AbstractVectorField{TD,VD,Traits.OutOfPlace},
    RHS<:AbstractIPRHS,
    OOPROHS<:AbstractOoPRHS,
}
    return sys.rhs_oop
end

"""
$(TYPEDSIGNATURES)

Return the out-of-place right-hand side for an `InPlace` `VectorFieldSystem`.

Eager implementation: ignores the config and returns the finalize closure.
This method is called when `!ismutable(u0)`, so we always return `rhs_oop_finalize`.

# Arguments
- `sys::VectorFieldSystem{..., InPlace, ...}`: The in-place system.
- `_`: The configuration (ignored).

# Returns
- `Function`: The finalize closure with signature `(u, p, t) -> du`.

# Notes
- Emits a performance warning since this path is suboptimal for immutable arrays.

See also: [`CTFlows.Systems.get_ip_rhs`](@ref).
"""
function get_oop_rhs(
    sys::VectorFieldSystem{TD,VD,Traits.InPlace,F,RHS,OOPROHS,FINRHS}, _
) where {
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    F<:Data.AbstractVectorField{TD,VD,Traits.InPlace},
    RHS<:AbstractIPRHS,
    OOPROHS<:AbstractOoPRHS,
    FINRHS,
}
    @warn "InPlace VectorField with immutable u0 (e.g. SVector): consider using an out-of-place function for better performance."
    return sys.rhs_oop_finalize
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
    io::IO, sys::VectorFieldSystem{TD,VD,MD,F,RHS,OOPROHS,FINRHS}
) where {
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    MD<:Traits.AbstractMutabilityTrait,
    F<:Data.AbstractVectorField{TD,VD,MD},
    RHS<:AbstractIPRHS,
    OOPROHS<:AbstractOoPRHS,
    FINRHS,
}
    fmt = Display.format_codes(io)
    wraps = "VectorField: $(Data._td_label(TD)), $(Data._vd_label(VD)), $(Data._md_label(MD))"
    rhs = "$(nameof(typeof(sys.rhs))) ($(_rhs_conversion_label(sys.rhs)))"
    Display.print_header(io, "VectorFieldSystem"; fmt=fmt)
    Display.print_field(io, "wraps", wraps; fmt=fmt, value_style="")
    return Display.print_field(io, "rhs", rhs; last=true, fmt=fmt, value_style="")
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
