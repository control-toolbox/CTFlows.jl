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

See also: [`CTFlows.Data.AbstractVectorField`](@ref), [`CTFlows.Common.TimeDependence`](@ref), [`CTFlows.Common.VariableDependence`](@ref).
"""
struct HamiltonianVectorField{F<:Function, TD<:Common.TimeDependence, VD<:Common.VariableDependence} <: AbstractVectorField{TD, VD}
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
