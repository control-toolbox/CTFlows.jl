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

Prefer the keyword constructor for clarity:

```julia
VectorField(f; autonomous = true, variable = false)        # default: f(x)
VectorField((t, x) -> ...; autonomous = false)             # f(t, x)
VectorField((x, v) -> ...; variable = true)                # f(x, v)
VectorField((t, x, v) -> ...; autonomous = false, variable = true)
```

Explicit-type constructor:

```julia
VectorField(f, Autonomous, Fixed)
```

# Call Signatures

Every `VectorField` is callable via its **natural** signature (matching the
traits), and via a **uniform** signature `(t, x, v)` that ignores the
unused arguments — this uniform form is used internally to build the right-hand
side of the ODE in a trait-agnostic way.
"""
struct VectorField{F, TD <: TimeDependence, VD <: VariableDependence}
    f::F
end

"""
$(TYPEDSIGNATURES)

Construct a `VectorField` with trait flags.

# Arguments
- `f::Function`: The vector-field function.
- `autonomous::Bool`: If true, system is autonomous (default: `Common.__autonomous()`).
- `variable::Bool`: If true, system depends on variable parameters (default: `Common.__variable()`).

# Returns
- `VectorField`: A VectorField with appropriate traits.

# Example
\`\`\`julia-repl
julia> using CTFlows.Systems, CTFlows.Common

julia> vf = VectorField(x -> -x)  # Uses defaults: autonomous=true, variable=false
VectorField
  time_dependence: Autonomous
  variable_dependence: Fixed
  function: var"#1"

julia> vf = VectorField((t, x) -> t .* x; autonomous=false)
VectorField
  time_dependence: NonAutonomous
  variable_dependence: Fixed
  function: var"#2"
\`\`\`
"""
function VectorField(f; autonomous::Bool = Common.__autonomous(), variable::Bool = Common.__variable())
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return VectorField{typeof(f), TD, VD}(f)
end

"""
$(TYPEDSIGNATURES)

Construct a `VectorField` with explicit trait types.
"""
function VectorField(
    f,
    ::Type{TD},
    ::Type{VD},
) where {TD <: TimeDependence, VD <: VariableDependence}
    return VectorField{typeof(f), TD, VD}(f)
end

# =============================================================================
# Natural call signatures - one per trait combination
# =============================================================================

(F::VectorField{<:Any, Autonomous, Fixed})(x) = F.f(x)
(F::VectorField{<:Any, NonAutonomous, Fixed})(t, x) = F.f(t, x)
(F::VectorField{<:Any, Autonomous, NonFixed})(x, v) = F.f(x, v)
(F::VectorField{<:Any, NonAutonomous, NonFixed})(t, x, v) = F.f(t, x, v)

# =============================================================================
# Uniform (t, x, v) call - used by VectorFieldSystem.rhs!
# Every combination forwards to its natural call, ignoring unused args.
# (NonAutonomous, NonFixed) is already covered by the natural signature above.
# =============================================================================

(F::VectorField{<:Any, Autonomous, Fixed})(t, x, v) = F.f(x)
(F::VectorField{<:Any, NonAutonomous, Fixed})(t, x, v) = F.f(t, x)
(F::VectorField{<:Any, Autonomous, NonFixed})(t, x, v) = F.f(x, v)

# =============================================================================
# Trait accessors for VectorField
# =============================================================================

"""
$(TYPEDSIGNATURES)

Extract the time dependence trait from a VectorField.

# Returns
- `Type{<:TimeDependence}`: The time dependence trait type (Autonomous or NonAutonomous).
"""
function time_dependence(vf::VectorField{<:Any, TD, <:Any}) where {TD <: TimeDependence}
    return TD
end

"""
$(TYPEDSIGNATURES)

Extract the variable dependence trait from a VectorField.

# Returns
- `Type{<:VariableDependence}`: The variable dependence trait type (Fixed or NonFixed).
"""
function variable_dependence(vf::VectorField{<:Any, <:Any, VD}) where {VD <: VariableDependence}
    return VD
end

# =============================================================================
# CTModels-style predicate methods
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return true if the VectorField is autonomous (time-independent).

# Returns
- `Bool`: true if time_dependence is Autonomous.
"""
function is_autonomous(vf::VectorField{<:Any, Autonomous, <:Any})
    return true
end

function is_autonomous(vf::VectorField{<:Any, NonAutonomous, <:Any})
    return false
end

"""
$(TYPEDSIGNATURES)

Return true if the VectorField is non-autonomous (time-dependent).

# Returns
- `Bool`: true if time_dependence is NonAutonomous.
"""
function is_nonautonomous(vf::VectorField{<:Any, Autonomous, <:Any})
    return false
end

function is_nonautonomous(vf::VectorField{<:Any, NonAutonomous, <:Any})
    return true
end

"""
$(TYPEDSIGNATURES)

Return true if the VectorField depends on variable parameters.

# Returns
- `Bool`: true if variable_dependence is NonFixed.
"""
function is_variable(vf::VectorField{<:Any, <:Any, NonFixed})
    return true
end

function is_variable(vf::VectorField{<:Any, <:Any, Fixed})
    return false
end

"""
$(TYPEDSIGNATURES)

Alias for `is_variable` for CTModels compatibility.

# Returns
- `Bool`: true if variable_dependence is NonFixed.
"""
has_variable(vf::VectorField) = is_variable(vf)

"""
$(TYPEDSIGNATURES)

Return true if the VectorField does not depend on variable parameters.

# Returns
- `Bool`: true if variable_dependence is Fixed.
"""
function is_nonvariable(vf::VectorField{<:Any, <:Any, Fixed})
    return true
end

function is_nonvariable(vf::VectorField{<:Any, <:Any, NonFixed})
    return false
end

# =============================================================================
# Base.show
# =============================================================================

function Base.show(io::IO, vf::VectorField{F, TD, VD}) where {F, TD, VD}
    println(io, "VectorField")
    println(io, "  time_dependence: ", TD)
    println(io, "  variable_dependence: ", VD)
    print(io, "  function: ", typeof(vf.f))
end

function Base.show(io::IO, ::MIME"text/plain", vf::VectorField{F, TD, VD}) where {F, TD, VD}
    show(io, vf)
end
