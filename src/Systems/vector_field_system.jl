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

# Variable-dependence trait override
variable_dependence(::Type{<:VectorFieldSystem{<:Any, <:Any, VD}}) where {VD} = VD
