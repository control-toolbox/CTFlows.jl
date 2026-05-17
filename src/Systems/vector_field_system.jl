"""
$(TYPEDEF)

Concrete `AbstractSystem` wrapping a `VectorField`. The variable for
`NonFixed` vector fields is **not** stored here; it is passed at flow-call
time via the `variable` kwarg and threaded through `ODEProblem`'s `p` slot
wrapped in a `Common.ODEParameters` struct.

# Fields
- `vf::VectorField{F, TD, VD, MD}`: the underlying vector field.
- `rhs::RHS`: the pre-computed in-place right-hand side closure with signature `(du, u, p, t) -> nothing`.
- `rhs_oop::OOPROHS`: the pre-computed out-of-place right-hand side closure with signature `(u, p, t) -> du`.
- `rhs_oop_finalize::FINRHS`: the finalize closure for in-place vector fields with immutable initial conditions, or `nothing` for out-of-place vector fields.

# Example
\`\`\`julia-repl
julia> using CTFlows.Systems, CTFlows.Common

julia> vf = VectorField(x -> -x; autonomous=true, variable=false)
VectorField
  time_dependence: Autonomous
  variable_dependence: Fixed
  mutability: OutOfPlace
  function: var"#1"

julia> sys = VectorFieldSystem(vf)
VectorFieldSystem
  time_dependence: Autonomous
  variable_dependence: Fixed
  mutability: OutOfPlace
  vector_field: VectorField{var"#1", Autonomous, Fixed, OutOfPlace}
\`\`\`

See also: [`CTFlows.Systems.AbstractSystem`](@ref), [`CTFlows.Data.VectorField`](@ref), [`CTFlows.Common.TimeDependence`](@ref), [`CTFlows.Common.VariableDependence`](@ref), [`CTFlows.Common.ODEParameters`](@ref).
"""
struct VectorFieldSystem{F<:Function, TD<:Common.TimeDependence, VD<:Common.VariableDependence, MD<:Common.AbstractMutabilityTrait, RHS<:Function, OOPROHS<:Function, FINRHS} <: AbstractStateSystem{TD, VD}
    vf::Data.VectorField{F, TD, VD, MD}
    rhs::RHS
    rhs_oop::OOPROHS
    rhs_oop_finalize::FINRHS
end

# =============================================================================
# Constructors
# =============================================================================

function VectorFieldSystem(vf::Data.VectorField{F, TD, VD, OutOfPlace}) where {F, TD, VD}
    rhs              = _build_rhs_vf_oop(vf)
    rhs_oop          = _build_oop_rhs_vf_oop(vf)
    rhs_oop_finalize = nothing
    return VectorFieldSystem{F, TD, VD, OutOfPlace, typeof(rhs), typeof(rhs_oop), Nothing}(vf, rhs, rhs_oop, rhs_oop_finalize)
end

function VectorFieldSystem(vf::Data.VectorField{F, TD, VD, InPlace}) where {F, TD, VD}
    rhs              = _build_rhs_vf_ip(vf)
    rhs_oop          = _build_oop_rhs_vf_ip(vf)
    rhs_oop_finalize = _build_finalize_rhs_vf_ip(vf)
    return VectorFieldSystem{F, TD, VD, InPlace, typeof(rhs), typeof(rhs_oop), typeof(rhs_oop_finalize)}(vf, rhs, rhs_oop, rhs_oop_finalize)
end

# =============================================================================
# Internal helpers: RHS builders
# =============================================================================

function _build_rhs_vf_oop(vf::Data.VectorField{F, TD, VD, OutOfPlace}) where {F, TD, VD}
    return (du, u, λ, t) -> (du .= vf(t, u, variable(λ)); nothing)
end

function _build_rhs_vf_ip(vf::Data.VectorField{F, TD, VD, InPlace}) where {F, TD, VD}
    return (du, u, λ, t) -> (vf(du, t, u, variable(λ)); nothing)
end

function _build_oop_rhs_vf_oop(vf::Data.VectorField{F, TD, VD, OutOfPlace}) where {F, TD, VD}
    return (u, λ, t) -> vf(t, u, variable(λ))
end

function _build_oop_rhs_vf_ip(vf::Data.VectorField{F, TD, VD, InPlace}) where {F, TD, VD}
    return function (u, λ, t)
        dx = similar(u)
        vf(dx, t, u, variable(λ))
        return dx
    end
end

function _build_finalize_rhs_vf_ip(vf::Data.VectorField{F, TD, VD, InPlace}) where {F, TD, VD}
    return function (u, λ, t)
        dx = similar(u)
        vf(dx, t, u, variable(λ))
        return typeof(u)(dx)
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
- The closure reads `variable(p)` to access the actual variable value.

See also: [`CTFlows.Systems.VectorFieldSystem`](@ref), [`CTFlows.Systems.AbstractSystem`](@ref), [`CTFlows.Common.ODEParameters`](@ref).
"""
function rhs(sys::VectorFieldSystem)
    return sys.rhs
end

"""
$(TYPEDSIGNATURES)

Out-of-place right-hand side for an `OutOfPlace` `VectorFieldSystem`.

Returns the pre-computed closure with signature `(u, p, t) -> du`. The optional
`is_u0_mutable` argument is accepted but ignored: for out-of-place vector fields
`rhs_oop` is always the correct callable regardless of u0 mutability.

# Arguments
- `sys::VectorFieldSystem{..., OutOfPlace, ...}`: The out-of-place system.
- `::Bool`: Ignored. Accepted for API uniformity with the `InPlace` method.

# Returns
- `Function`: The pre-computed closure with signature `(u, p, t) -> du`.

See also: [`CTFlows.Systems.VectorFieldSystem`](@ref), [`CTFlows.Systems.rhs`](@ref).
"""
function rhs_oop(sys::VectorFieldSystem{F, TD, VD, OutOfPlace, RHS, OOPROHS, Nothing}, ::Bool = true) where {F, TD, VD, RHS, OOPROHS}
    return sys.rhs_oop
end

"""
$(TYPEDSIGNATURES)

Out-of-place right-hand side for an `InPlace` `VectorFieldSystem`, dispatching on u0 mutability.

For in-place vector fields the appropriate callable depends on whether the initial
condition `u0` is mutable:
- **`is_u0_mutable = true`** (default): returns `rhs_oop`, which allocates a mutable
  buffer and returns it. Correct when `u0` is a `Vector` or similar mutable array.
- **`is_u0_mutable = false`**: returns `rhs_oop_finalize`, which allocates a mutable
  buffer, fills it via the in-place call, then converts back to `typeof(u)`. Correct
  when `u0` is immutable (e.g. `StaticArrays.SVector`). A one-time performance
  warning is emitted in this case.

# Arguments
- `sys::VectorFieldSystem{..., InPlace, ...}`: The in-place system.
- `is_u0_mutable::Bool`: `true` if u0 is mutable, `false` if immutable. Defaults to `true`.

# Returns
- `Function`: The appropriate closure with signature `(u, p, t) -> du`.

# Notes
- Prefer out-of-place vector fields when u0 is a `StaticArrays.SVector` for best performance.

See also: [`CTFlows.Systems.VectorFieldSystem`](@ref), [`CTFlows.Systems.rhs`](@ref).
"""
function rhs_oop(sys::VectorFieldSystem{F, TD, VD, InPlace, RHS, OOPROHS, FINRHS}, is_u0_mutable::Bool = true) where {F, TD, VD, RHS, OOPROHS, FINRHS}
    is_u0_mutable && return sys.rhs_oop
    @warn "InPlace VectorField with immutable u0 (e.g. SVector): consider using an out-of-place function for better performance."
    return sys.rhs_oop_finalize
end

# =============================================================================
# Base.show
# =============================================================================

"""
$(TYPEDSIGNATURES)

Display a compact representation of a VectorFieldSystem.

Shows the type name and the wrapped VectorField with its traits.

# Arguments
- `io::IO`: The IO stream to write to.
- `sys::VectorFieldSystem`: The VectorFieldSystem to display.

See also: [`CTFlows.Systems.VectorFieldSystem`](@ref).
"""
function Base.show(io::IO, sys::VectorFieldSystem{F, TD, VD, MD, RHS, OOPROHS, FINRHS}) where {F, TD, VD, MD, RHS, OOPROHS, FINRHS}
    println(io, "VectorFieldSystem")
    wraps = "VectorField: $(Data._td_label(TD)), $(Data._vd_label(VD)), $(Data._md_label(MD))"
    print(io, "  wraps: ", wraps)
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
function Base.show(io::IO, ::MIME"text/plain", sys::VectorFieldSystem{F, TD, VD, MD, RHS, OOPROHS, FINRHS}) where {F, TD, VD, MD, RHS, OOPROHS, FINRHS}
    show(io, sys)
end