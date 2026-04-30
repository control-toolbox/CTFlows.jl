"""
$(TYPEDEF)

Concrete `AbstractSystem` wrapping a `VectorField`. The variable for
`NonFixed` vector fields is **not** stored here; it is passed at flow-call
time via the `variable` kwarg and threaded through `ODEProblem`'s `p` slot.

# Fields
- `vf::VectorField{F, TD, VD}`: the underlying vector field.

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

See also: [`CTFlows.Systems.AbstractSystem`](@ref), [`CTFlows.Systems.VectorField`](@ref), [`CTFlows.Common.TimeDependence`](@ref), [`CTFlows.Common.VariableDependence`](@ref).
"""
struct VectorFieldSystem{F<:Function, TD<:Common.TimeDependence, VD<:Common.VariableDependence} <: AbstractSystem
    vf::VectorField{F, TD, VD}
end

"""
$(TYPEDSIGNATURES)

In-place right-hand side for a `VectorFieldSystem`. The returned closure has
signature `(du, u, p, t) -> nothing` and uses the uniform `(t, x, v)` call on
the underlying `VectorField`, where `p` carries the variable (or `nothing`
for `Fixed` systems).

# Arguments
- `sys::VectorFieldSystem`: The system for which to generate the RHS function.

# Returns
- `Function`: A closure with signature `(du, u, p, t) -> nothing`.

# Example
\`\`\`julia
using CTFlows.Systems, CTFlows.Common

vf = VectorField(x -> -x; autonomous=true, variable=false)
sys = VectorFieldSystem(vf)
rhs = Systems.rhs!(sys)

du = zeros(2)
u = [1.0, 2.0]
rhs(du, u, nothing, 0.0)
# du is now [-1.0, -2.0]
\`\`\`

See also: [`CTFlows.Systems.VectorFieldSystem`](@ref), [`CTFlows.Systems.AbstractSystem`](@ref).
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

# Example
\`\`\`julia
using CTFlows.Systems
using CTFlows.Common

vf_fixed = VectorField(x -> -x; variable=false)
sys_fixed = VectorFieldSystem(vf_fixed)
Common.variable_dependence(sys_fixed)  # Returns Fixed

vf_nonfixed = VectorField((x, v) -> -x .* v; variable=true)
sys_nonfixed = VectorFieldSystem(vf_nonfixed)
Common.variable_dependence(sys_nonfixed)  # Returns NonFixed
\`\`\`

See also: [`CTFlows.Common.has_variable_dependence_trait`](@ref), [`CTFlows.Common.is_variable`](@ref), [`CTFlows.Systems.VectorFieldSystem`](@ref).
"""
function Common.variable_dependence(sys::VectorFieldSystem{<:Function, <:TimeDependence, VD}) where {VD <: VariableDependence}
    return VD
end

"""
$(TYPEDSIGNATURES)

Extract the time dependence trait from a VectorFieldSystem.

# Returns
- `Type{<:TimeDependence}`: The time dependence trait type (Autonomous or NonAutonomous).

# Example
\`\`\`julia
using CTFlows.Systems
using CTFlows.Common

vf_autonomous = VectorField(x -> -x; autonomous=true)
sys_autonomous = VectorFieldSystem(vf_autonomous)
Common.time_dependence(sys_autonomous)  # Returns Autonomous

vf_nonautonomous = VectorField((t, x) -> t .* x; autonomous=false)
sys_nonautonomous = VectorFieldSystem(vf_nonautonomous)
Common.time_dependence(sys_nonautonomous)  # Returns NonAutonomous
\`\`\`

See also: [`CTFlows.Common.has_time_dependence_trait`](@ref), [`CTFlows.Common.is_autonomous`](@ref), [`CTFlows.Systems.VectorFieldSystem`](@ref).
"""
function Common.time_dependence(sys::VectorFieldSystem{<:Function, TD, <:VariableDependence}) where {TD <: TimeDependence}
    return TD
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
function Base.show(io::IO, sys::VectorFieldSystem{F, TD, VD}) where {F, TD, VD}
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
function Base.show(io::IO, ::MIME"text/plain", sys::VectorFieldSystem{F, TD, VD}) where {F, TD, VD}
    show(io, sys)
end