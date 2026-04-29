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
"""
function VectorField(f; autonomous::Bool = true, variable::Bool = false)
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
