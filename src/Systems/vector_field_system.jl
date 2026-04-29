"""
$(TYPEDEF)

Concrete `AbstractSystem` wrapping a `VectorField`. The variable for
`NonFixed` vector fields is **not** stored here; it is passed at flow-call
time via the `variable` kwarg and threaded through `ODEProblem`'s `p` slot.

# Fields
- `vf::VectorField{F, TD, VD}`: the underlying vector field.
"""
struct VectorFieldSystem{F, TD, VD} <: AbstractSystem
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

Return `(n_x = nothing,)` for `VectorFieldSystem`: the state dimension is
determined at integration time by the config's `x0`, not stored on the system.
"""
dimensions(::VectorFieldSystem) = (n_x = nothing,)

"""
$(TYPEDSIGNATURES)

Extract the variable dependence trait from a VectorFieldSystem.

# Returns
- `Type{<:VariableDependence}`: The variable dependence trait type (Fixed or NonFixed).
"""
function variable_dependence(::Type{<:VectorFieldSystem{<:Any, <:Any, VD}}) where {VD <: VariableDependence}
    return VD
end

function variable_dependence(sys::VectorFieldSystem{<:Any, <:Any, VD}) where {VD <: VariableDependence}
    return VD
end

"""
$(TYPEDSIGNATURES)

Extract the time dependence trait from a VectorFieldSystem.

# Returns
- `Type{<:TimeDependence}`: The time dependence trait type (Autonomous or NonAutonomous).
"""
function time_dependence(::Type{<:VectorFieldSystem{<:Any, TD, <:Any}}) where {TD <: TimeDependence}
    return TD
end

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

# =============================================================================
# CTModels-style predicate methods
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return true if the VectorFieldSystem is autonomous (time-independent).

# Returns
- `Bool`: true if time_dependence is Autonomous.
"""
function is_autonomous(sys::VectorFieldSystem{<:Any, Autonomous, <:Any})
    return true
end

function is_autonomous(sys::VectorFieldSystem{<:Any, NonAutonomous, <:Any})
    return false
end

"""
$(TYPEDSIGNATURES)

Return true if the VectorFieldSystem is non-autonomous (time-dependent).

# Returns
- `Bool`: true if time_dependence is NonAutonomous.
"""
function is_nonautonomous(sys::VectorFieldSystem{<:Any, Autonomous, <:Any})
    return false
end

function is_nonautonomous(sys::VectorFieldSystem{<:Any, NonAutonomous, <:Any})
    return true
end

"""
$(TYPEDSIGNATURES)

Return true if the VectorFieldSystem depends on variable parameters.

# Returns
- `Bool`: true if variable_dependence is NonFixed.
"""
function is_variable(sys::VectorFieldSystem{<:Any, <:Any, NonFixed})
    return true
end

function is_variable(sys::VectorFieldSystem{<:Any, <:Any, Fixed})
    return false
end

"""
$(TYPEDSIGNATURES)

Alias for `is_variable` for CTModels compatibility.

# Returns
- `Bool`: true if variable_dependence is NonFixed.
"""
has_variable(sys::VectorFieldSystem) = is_variable(sys)

"""
$(TYPEDSIGNATURES)

Return true if the VectorFieldSystem does not depend on variable parameters.

# Returns
- `Bool`: true if variable_dependence is Fixed.
"""
function is_nonvariable(sys::VectorFieldSystem{<:Any, <:Any, Fixed})
    return true
end

function is_nonvariable(sys::VectorFieldSystem{<:Any, <:Any, NonFixed})
    return false
end
