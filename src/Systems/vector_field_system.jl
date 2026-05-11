"""
$(TYPEDEF)

Concrete `AbstractSystem` wrapping a `VectorField`. The variable for
`NonFixed` vector fields is **not** stored here; it is passed at flow-call
time via the `variable` kwarg and threaded through `ODEProblem`'s `p` slot
wrapped in a `Common.ODEParameters` struct.

# Fields
- `vf::VectorField{F, TD, VD}`: the underlying vector field.
- `rhs::RHS`: the pre-computed in-place right-hand side closure with signature `(du, u, p, t) -> nothing`.
- `rhs_oop::OOPROHS`: the pre-computed out-of-place right-hand side closure with signature `(u, p, t) -> du`.

# Example
\`\`\`julia-repl
julia> using CTFlows.Systems, CTFlows.Common

julia> vf = VectorField(x -> -x; autonomous=true, variable=false)
VectorField
  time_dependence: Autonomous
  variable_dependence: Fixed
  function: var"#1"

julia> sys = VectorFieldSystem(vf)
VectorFieldSystem
  time_dependence: Autonomous
  variable_dependence: Fixed
  vector_field: VectorField{var"#1", Autonomous, Fixed}
\`\`\`

See also: [`CTFlows.Systems.AbstractSystem`](@ref), [`CTFlows.Data.VectorField`](@ref), [`CTFlows.Common.TimeDependence`](@ref), [`CTFlows.Common.VariableDependence`](@ref), [`CTFlows.Common.ODEParameters`](@ref).
"""
struct VectorFieldSystem{F<:Function, TD<:Common.TimeDependence, VD<:Common.VariableDependence, RHS<:Function, OOPROHS<:Function} <: AbstractStateSystem{TD, VD}
    vf::Data.VectorField{F, TD, VD}
    rhs::RHS
    rhs_oop::OOPROHS

    function VectorFieldSystem(vf::Data.VectorField{F, TD, VD}) where {F, TD, VD}
        rhs = function (du, u, λ, t)
            du .= vf(t, u, λ.variable)
            return nothing
        end
        rhs_oop = (u, λ, t) -> vf(t, u, λ.variable)
        return new{F, TD, VD, typeof(rhs), typeof(rhs_oop)}(vf, rhs, rhs_oop)
    end
end

"""
$(TYPEDSIGNATURES)

In-place right-hand side for a `VectorFieldSystem`. Returns the pre-computed
closure stored in the system, which has signature `(du, u, p, t) -> nothing` and
uses the uniform `(t, x, v)` call on the underlying `VectorField`, where `p`
is a `Common.ODEParameters` wrapper containing the variable (or `nothing`
for `Fixed` systems).

# Arguments
- `sys::VectorFieldSystem`: The system for which to return the RHS function.

# Returns
- `Function`: The pre-computed closure with signature `(du, u, p, t) -> nothing`.

# Example
\`\`\`julia
using CTFlows.Systems, CTFlows.Common

vf = VectorField(x -> -x; autonomous=true, variable=false)
sys = VectorFieldSystem(vf)
rhs = Systems.rhs(sys)

du = zeros(2)
u = [1.0, 2.0]
p = Common.ODEParameters(nothing)
rhs(du, u, p, 0.0)
# du is now [-1.0, -2.0]
\`\`\`

# Notes
- The closure is computed once at construction time for performance.
- Multiple calls to `rhs` return the same function object.
- The closure reads `p.variable` to access the actual variable value.

See also: [`CTFlows.Systems.VectorFieldSystem`](@ref), [`CTFlows.Systems.AbstractSystem`](@ref), [`CTFlows.Common.ODEParameters`](@ref).
"""
function rhs(sys::VectorFieldSystem)
    return sys.rhs
end

"""
$(TYPEDSIGNATURES)

Out-of-place right-hand side for a `VectorFieldSystem`. Returns the pre-computed
closure stored in the system, which has signature `(u, p, t) -> du` and uses
the uniform `(t, x, v)` call on the underlying `VectorField`, where `p`
is a `Common.ODEParameters` wrapper containing the variable (or `nothing`
for `Fixed` systems).

# Arguments
- `sys::VectorFieldSystem`: The system for which to return the RHS function.

# Returns
- `Function`: The pre-computed closure with signature `(u, p, t) -> du`.

# Example
```julia
using CTFlows.Systems, CTFlows.Common

vf = VectorField(x -> -x; autonomous=true, variable=false)
sys = VectorFieldSystem(vf)
rhs_oop = Systems.rhs_oop(sys)

u = [1.0, 2.0]
p = Common.ODEParameters(nothing)
du = rhs_oop(u, p, 0.0)
# du is [-1.0, -2.0]
```

# Notes
- The closure is computed once at construction time for performance.
- Multiple calls to `rhs_oop` return the same function object.
- This method is used for immutable array types like `StaticArrays.SVector`.
- The closure uses the uniform `(t, x, v)` signature to work with all trait combinations.

See also: [`CTFlows.Systems.VectorFieldSystem`](@ref), [`CTFlows.Systems.rhs`](@ref), [`CTFlows.Common.ODEParameters`](@ref).
"""
function rhs_oop(sys::VectorFieldSystem)
    return sys.rhs_oop
end

# =============================================================================
# Base.show
# =============================================================================

"""
$(TYPEDSIGNATURES)

Display a compact representation of a VectorFieldSystem.

Shows the type name, time dependence, variable dependence, and the underlying vector field type.

# Arguments
- `io::IO`: The IO stream to write to.
- `sys::VectorFieldSystem`: The VectorFieldSystem to display.

See also: [`CTFlows.Systems.VectorFieldSystem`](@ref).
"""
function Base.show(io::IO, sys::VectorFieldSystem{F, TD, VD, RHS, OOPROHS}) where {F, TD, VD, RHS, OOPROHS}
    println(io, "VectorFieldSystem")
    println(io, "  time_dependence: ", TD)
    println(io, "  variable_dependence: ", VD)
    print(io, "  vector_field: ", typeof(sys.vf))
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
function Base.show(io::IO, ::MIME"text/plain", sys::VectorFieldSystem{F, TD, VD, RHS, OOPROHS}) where {F, TD, VD, RHS, OOPROHS}
    show(io, sys)
end