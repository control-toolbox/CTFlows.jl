"""
$(TYPEDEF)

Parametric container for a vector-field function together with its
time-dependence and variable-dependence traits.

# Type Parameters
- `F`: concrete type of the wrapped function.
- `TD <: TimeDependence`: `Autonomous` or `NonAutonomous`.
- `VD <: VariableDependence`: `Fixed` or `NonFixed`.

# Fields
- `f::F`: the vector-field function.

# Construction

Use the keyword constructor:

```julia
VectorField(f; autonomous = true, variable = false)        # default: f(x)
VectorField((t, x) -> ...; autonomous = false)             # f(t, x)
VectorField((x, v) -> ...; variable = true)                # f(x, v)
VectorField((t, x, v) -> ...; autonomous = false, variable = true)
```

# Call Signatures

Every `VectorField` is callable via its **natural** signature (matching the
traits), and via a **uniform** signature `(t, x, v)` that ignores the
unused arguments — this uniform form is used internally to build the right-hand
side of the ODE in a trait-agnostic way.

See also: [`CTFlows.Data.AbstractVectorField`](@ref), [`CTFlows.Common.TimeDependence`](@ref), [`CTFlows.Common.VariableDependence`](@ref).
"""
struct VectorField{F<:Function, TD<:TimeDependence, VD<:VariableDependence} <: AbstractVectorField{TD, VD}
    f::F
end

"""
$(TYPEDSIGNATURES)

Construct a `VectorField` with trait flags.

# Arguments
- `f::Function`: The vector-field function.
- `is_autonomous::Bool`: If true, system is autonomous (default: `Common.__is_autonomous()`).
- `is_variable::Bool`: If true, system depends on variable parameters (default: `Common.__is_variable()`).

# Returns
- `VectorField`: A VectorField with appropriate traits.

# Example
\`\`\`julia-repl
julia> using CTFlows.Systems, CTFlows.Common

julia> vf = VectorField(x -> -x)  # Uses defaults: is_autonomous=true, is_variable=false
VectorField
  time_dependence: Autonomous
  variable_dependence: Fixed
  function: var"#1"

julia> vf = VectorField((t, x) -> t .* x; is_autonomous=false)
VectorField
  time_dependence: NonAutonomous
  variable_dependence: Fixed
  function: var"#2"
\`\`\`

See also: [`CTFlows.Data.VectorField`](@ref), [`CTFlows.Common.Autonomous`](@ref), [`CTFlows.Common.NonAutonomous`](@ref), [`CTFlows.Common.Fixed`](@ref), [`CTFlows.Common.NonFixed`](@ref).
"""
function VectorField(f; is_autonomous::Bool = Common.__is_autonomous(), is_variable::Bool = Common.__is_variable())
    TD = is_autonomous ? Autonomous : NonAutonomous
    VD = is_variable ? NonFixed : Fixed
    return VectorField{typeof(f), TD, VD}(f)
end

# =============================================================================
# Natural call signatures - one per trait combination
# =============================================================================

(F::VectorField{<:Function, Autonomous, Fixed})(x) = F.f(x)
(F::VectorField{<:Function, NonAutonomous, Fixed})(t, x) = F.f(t, x)
(F::VectorField{<:Function, Autonomous, NonFixed})(x, v) = F.f(x, v)
(F::VectorField{<:Function, NonAutonomous, NonFixed})(t, x, v) = F.f(t, x, v)

# =============================================================================
# Uniform (t, x, v) call - used by VectorFieldSystem.rhs
# Every combination forwards to its natural call, ignoring unused args.
# (NonAutonomous, NonFixed) is already covered by the natural signature above.
# =============================================================================

(F::VectorField{<:Function, Autonomous, Fixed})(t, x, v) = F.f(x)
(F::VectorField{<:Function, NonAutonomous, Fixed})(t, x, v) = F.f(t, x)
(F::VectorField{<:Function, Autonomous, NonFixed})(t, x, v) = F.f(x, v)

# =============================================================================
# Base.show
# =============================================================================

"""
$(TYPEDSIGNATURES)

Display a compact representation of a VectorField.

Shows the type name, time dependence, variable dependence, and function type.

# Arguments
- `io::IO`: The IO stream to write to.
- `vf::VectorField`: The VectorField to display.

See also: [`CTFlows.Data.VectorField`](@ref).
"""
function Base.show(io::IO, vf::VectorField{F, TD, VD}) where {F, TD, VD}
    println(io, "VectorField")
    println(io, "  time_dependence: ", nameof(TD))
    println(io, "  variable_dependence: ", nameof(VD))
    print(io, "  function: ", typeof(vf.f))
end

"""
$(TYPEDSIGNATURES)

Display a VectorField in the REPL with text/plain MIME type.

Delegates to the compact show method.

# Arguments
- `io::IO`: The IO stream to write to.
- `::MIME"text/plain"`: The MIME type for REPL display.
- `vf::VectorField`: The VectorField to display.

See also: [`CTFlows.Data.VectorField`](@ref).
"""
function Base.show(io::IO, ::MIME"text/plain", vf::VectorField{F, TD, VD}) where {F, TD, VD}
    show(io, vf)
end
