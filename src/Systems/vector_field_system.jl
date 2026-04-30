"""
$(TYPEDEF)

Concrete `AbstractSystem` wrapping a `VectorField`. The variable for
`NonFixed` vector fields is **not** stored here; it is passed at flow-call
time via the `variable` kwarg and threaded through `ODEProblem`'s `p` slot.

# Fields
- `vf::VectorField{F, TD, VD}`: the underlying vector field.
"""
struct VectorFieldSystem{F, TD<:Common.TimeDependence, VD<:Common.VariableDependence} <: AbstractSystem
    vf::VectorField{F, TD, VD}
end

"""
$(TYPEDSIGNATURES)

In-place right-hand side for a `VectorFieldSystem`. The returned closure has
signature `(du, u, p, t) -> nothing` and uses the uniform `(t, x, v)` call on
the underlying `VectorField`, where `p` carries the variable (or `nothing`
for `Fixed` systems).
"""
function rhs!(sys::VectorFieldSystem)
    vf = sys.vf
    return function (du, u, p, t)
        du .= vf(t, u, p)
        return nothing
    end
end

"""
$(TYPEDSIGNATURES)

Extract the variable dependence trait from a VectorFieldSystem.

# Returns
- `Type{<:VariableDependence}`: The variable dependence trait type (Fixed or NonFixed).
"""
function variable_dependence(sys::VectorFieldSystem{<:Any, <:Any, VD}) where {VD <: VariableDependence}
    return VD
end

"""
$(TYPEDSIGNATURES)

Extract the time dependence trait from a VectorFieldSystem.

# Returns
- `Type{<:TimeDependence}`: The time dependence trait type (Autonomous or NonAutonomous).
"""
function time_dependence(sys::VectorFieldSystem{<:Any, TD, <:Any}) where {TD <: TimeDependence}
    return TD
end

# =============================================================================
# Base.show
# =============================================================================

function Base.show(io::IO, sys::VectorFieldSystem{F, TD, VD}) where {F, TD, VD}
    println(io, "VectorFieldSystem")
    println(io, "  time_dependence: ", TD)
    println(io, "  variable_dependence: ", VD)
    print(io, "  vector_field: ", typeof(sys.vf))
end

function Base.show(io::IO, ::MIME"text/plain", sys::VectorFieldSystem{F, TD, VD}) where {F, TD, VD}
    show(io, sys)
end