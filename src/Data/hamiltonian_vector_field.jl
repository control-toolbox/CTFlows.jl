"""
$(TYPEDEF)

Parametric container for a Hamiltonian vector field function together with its
time-dependence and variable-dependence traits.

The function returns a tuple `(dx, dp)` representing the derivatives of state `x`
and costate `p` according to Hamiltonian dynamics.

# Type Parameters
- `F`: concrete type of the wrapped function.
- `TD <: TimeDependence`: `Autonomous` or `NonAutonomous`.
- `VD <: VariableDependence`: `Fixed` or `NonFixed`.

# Fields
- `f::F`: the Hamiltonian vector field function.

# Construction

Use the keyword constructor:

```julia
HamiltonianVectorField(f; autonomous = true, variable = false)        # default: f(x, p)
HamiltonianVectorField((t, x, p) -> ...; autonomous = false)             # f(t, x, p)
HamiltonianVectorField((x, p, v) -> ...; variable = true)                # f(x, p, v)
HamiltonianVectorField((t, x, p, v) -> ...; autonomous = false, variable = true)
```

# Call Signatures

Every `HamiltonianVectorField` is callable via its **natural** signature (matching the
traits), and via a **uniform** signature `(t, x, p, v)` that ignores the
unused arguments.

See also: [`CTFlows.Data.VectorField`](@ref), [`CTFlows.Common.TimeDependence`](@ref), [`CTFlows.Common.VariableDependence`](@ref).
"""
struct HamiltonianVectorField{F<:Function, TD<:Common.TimeDependence, VD<:Common.VariableDependence}
    f::F
end

"""
$(TYPEDSIGNATURES)

Construct a `HamiltonianVectorField` with trait flags.

# Arguments
- `f::Function`: The Hamiltonian vector field function returning `(dx, dp)`.
- `is_autonomous::Bool`: If true, system is autonomous (default: `Common.__is_autonomous()`).
- `is_variable::Bool`: If true, system depends on variable parameters (default: `Common.__is_variable()`).

# Returns
- `HamiltonianVectorField`: A HamiltonianVectorField with appropriate traits.

# Example
```julia-repl
julia> using CTFlows.Systems, CTFlows.Common

julia> hvf = HamiltonianVectorField((x, p) -> (x, -p))  # Uses defaults: is_autonomous=true, is_variable=false
HamiltonianVectorField
  time_dependence: Autonomous
  variable_dependence: Fixed
  function: var"#1"

julia> hvf = HamiltonianVectorField((t, x, p) -> (t .* x, -p); is_autonomous=false)
HamiltonianVectorField
  time_dependence: NonAutonomous
  variable_dependence: Fixed
  function: var"#2"
```

See also: [`CTFlows.Data.HamiltonianVectorField`](@ref), [`CTFlows.Common.Autonomous`](@ref), [`CTFlows.Common.NonAutonomous`](@ref), [`CTFlows.Common.Fixed`](@ref), [`CTFlows.Common.NonFixed`](@ref).
"""
function HamiltonianVectorField(f; is_autonomous::Bool = Common.__is_autonomous(), is_variable::Bool = Common.__is_variable())
    TD = is_autonomous ? Common.Autonomous : Common.NonAutonomous
    VD = is_variable ? Common.NonFixed : Common.Fixed
    return HamiltonianVectorField{typeof(f), TD, VD}(f)
end

# =============================================================================
# Natural call signatures - one per trait combination
# =============================================================================

(H::HamiltonianVectorField{<:Function, Common.Autonomous, Common.Fixed})(x, p) = H.f(x, p)
(H::HamiltonianVectorField{<:Function, Common.NonAutonomous, Common.Fixed})(t, x, p) = H.f(t, x, p)
(H::HamiltonianVectorField{<:Function, Common.Autonomous, Common.NonFixed})(x, p, v) = H.f(x, p, v)
(H::HamiltonianVectorField{<:Function, Common.NonAutonomous, Common.NonFixed})(t, x, p, v) = H.f(t, x, p, v)

# =============================================================================
# Uniform (t, x, p, v) call - used by HamiltonianVectorFieldSystem.rhs
# Every combination forwards to its natural call, ignoring unused args.
# (NonAutonomous, NonFixed) is already covered by the natural signature above.
# =============================================================================

(H::HamiltonianVectorField{<:Function, Common.Autonomous, Common.Fixed})(t, x, p, v) = H.f(x, p)
(H::HamiltonianVectorField{<:Function, Common.NonAutonomous, Common.Fixed})(t, x, p, v) = H.f(t, x, p)
(H::HamiltonianVectorField{<:Function, Common.Autonomous, Common.NonFixed})(t, x, p, v) = H.f(x, p, v)

# =============================================================================
# Trait accessors for HamiltonianVectorField
# =============================================================================

"""
$(TYPEDSIGNATURES)

Indicate that `HamiltonianVectorField` has the time-dependence trait.

This implementation declares that all Hamiltonian vector fields support time-dependence queries.
Concrete `HamiltonianVectorField` instances have their time dependence encoded in the type parameter `TD`.

See also: [`CTFlows.Common.time_dependence`](@ref), [`CTFlows.Data.HamiltonianVectorField`](@ref).
"""
Common.has_time_dependence_trait(::HamiltonianVectorField) = true

"""
$(TYPEDSIGNATURES)

Indicate that `HamiltonianVectorField` has the variable-dependence trait.

This implementation declares that all Hamiltonian vector fields support variable-dependence queries.
Concrete `HamiltonianVectorField` instances have their variable dependence encoded in the type parameter `VD`.

See also: [`CTFlows.Common.variable_dependence`](@ref), [`CTFlows.Data.HamiltonianVectorField`](@ref).
"""
Common.has_variable_dependence_trait(::HamiltonianVectorField) = true

"""
$(TYPEDSIGNATURES)

Extract the time dependence trait from a HamiltonianVectorField.

# Returns
- `Type{<:TimeDependence}`: The time dependence trait type (Autonomous or NonAutonomous).

# Example
```julia
using CTFlows.Systems
using CTFlows.Common

hvf_autonomous = HamiltonianVectorField((x, p) -> (x, -p); autonomous=true)
Common.time_dependence(hvf_autonomous)  # Returns Autonomous

hvf_nonautonomous = HamiltonianVectorField((t, x, p) -> (t .* x, -p); autonomous=false)
Common.time_dependence(hvf_nonautonomous)  # Returns NonAutonomous
```

See also: [`CTFlows.Common.has_time_dependence_trait`](@ref), [`CTFlows.Common.is_autonomous`](@ref).
"""
function Common.time_dependence(hvf::HamiltonianVectorField{<:Function, TD, <:Common.VariableDependence}) where {TD <: Common.TimeDependence}
    return TD
end

"""
$(TYPEDSIGNATURES)

Extract the variable dependence trait from a HamiltonianVectorField.

# Returns
- `Type{<:VariableDependence}`: The variable dependence trait type (Fixed or NonFixed).

# Example
```julia
using CTFlows.Systems
using CTFlows.Common

hvf_fixed = HamiltonianVectorField((x, p) -> (x, -p); variable=false)
Common.variable_dependence(hvf_fixed)  # Returns Fixed

hvf_nonfixed = HamiltonianVectorField((x, p, v) -> (x .* v, -p); variable=true)
Common.variable_dependence(hvf_nonfixed)  # Returns NonFixed
```

See also: [`CTFlows.Common.has_variable_dependence_trait`](@ref), [`CTFlows.Common.is_variable`](@ref).
"""
function Common.variable_dependence(hvf::HamiltonianVectorField{<:Function, <:Common.TimeDependence, VD}) where {VD <: Common.VariableDependence}
    return VD
end

# =============================================================================
# Base.show
# =============================================================================

"""
$(TYPEDSIGNATURES)

Display a compact representation of a HamiltonianVectorField.

Shows the type name, time dependence, variable dependence, and function type.

# Arguments
- `io::IO`: The IO stream to write to.
- `hvf::HamiltonianVectorField`: The HamiltonianVectorField to display.

See also: [`CTFlows.Data.HamiltonianVectorField`](@ref).
"""
function Base.show(io::IO, hvf::HamiltonianVectorField{F, TD, VD}) where {F, TD, VD}
    println(io, "HamiltonianVectorField")
    println(io, "  time_dependence: ", nameof(TD))
    println(io, "  variable_dependence: ", nameof(VD))
    print(io, "  function: ", typeof(hvf.f))
end

"""
$(TYPEDSIGNATURES)

Display a HamiltonianVectorField in the REPL with text/plain MIME type.

Delegates to the compact show method.

# Arguments
- `io::IO`: The IO stream to write to.
- `::MIME"text/plain"`: The MIME type for REPL display.
- `hvf::HamiltonianVectorField`: The HamiltonianVectorField to display.

See also: [`CTFlows.Data.HamiltonianVectorField`](@ref).
"""
function Base.show(io::IO, ::MIME"text/plain", hvf::HamiltonianVectorField{F, TD, VD}) where {F, TD, VD}
    show(io, hvf)
end
