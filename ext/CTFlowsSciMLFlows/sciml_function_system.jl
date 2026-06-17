# =============================================================================
# SciMLFunctionSystem
# =============================================================================

"""
$(TYPEDEF)

Concrete `AbstractStateSystem` wrapping a `SciMLBase.AbstractODEFunction`.

Unlike CTFlows-native systems (`VectorFieldSystem`), this system passes `p = variable`
directly to the ODE — no `ODEParameters` wrapper — so users can pass arbitrary
SciML parameter objects.

The mutability trait is encoded in the `iip` type parameter of the wrapped function:
- `AbstractODEFunction{true}` → in-place `f!(du, u, p, t)`
- `AbstractODEFunction{false}` → out-of-place `f(u, p, t) -> du`

The system pre-computes cross-adapters for both in-place and out-of-place call modes,
similar to `VectorFieldSystem`, ensuring compatibility with the generic `build_problem`
which dispatches based on `u0` mutability.

# Type Parameters
- `F <: SciMLBase.AbstractODEFunction`: The wrapped ODE function.
- `RHS<:Systems.AbstractIPRHS`: Pre-computed in-place RHS functor.
- `OOPROHS<:Systems.AbstractOoPRHS`: Pre-computed out-of-place RHS functor.
- `FINRHS`: Finalize functor for in-place functions with immutable `u0`, or `Nothing`.

# Fields
- `f::F`: The wrapped SciML ODE function.
- `rhs_fn::RHS`: In-place RHS with signature `(du, u, λ, t)`.
- `rhs_oop_fn::OOPROHS`: Out-of-place RHS with signature `(u, λ, t)`.
- `rhs_oop_finalize_fn::FINRHS`: Out-of-place RHS for immutable `u0` (iip only), or `Nothing`.

# Example
```julia
using SciMLBase, CTFlows

f = ODEFunction((du, u, p, t) -> du .= -p .* u)
sys = SciMLFunctionSystem(f)
# sys.rhs_fn is pre-computed in-place closure
# sys.rhs_oop_fn is pre-computed out-of-place closure (allocates buffer)
```
"""
struct SciMLFunctionSystem{
    F <: SciMLBase.AbstractODEFunction,
    RHS<:Systems.AbstractIPRHS,
    OOPROHS<:Systems.AbstractOoPRHS,
    FINRHS
} <: Systems.AbstractStateSystem{Traits.NonAutonomous, Traits.NonFixed}
    f::F
    rhs_fn::RHS
    rhs_oop_fn::OOPROHS
    rhs_oop_finalize_fn::FINRHS
end

# =============================================================================
# Constructors
# =============================================================================

"""
$(TYPEDSIGNATURES)

Construct a `SciMLFunctionSystem` from an in-place SciML ODE function.

Pre-computes all three RHS functors: in-place, out-of-place (with allocation),
and out-of-place with type conversion for immutable arrays.

# Arguments
- `f::SciMLBase.AbstractODEFunction{true}`: An in-place ODE function with signature `(du, u, p, t) -> nothing`.

# Returns
- `SciMLFunctionSystem`: The system with pre-computed RHS functors.

See also: [`CTFlowsSciMLFlows.SciMLFunctionSystem`](@ref), [`CTFlowsSciMLFlows.IPSciMLIpRHS`](@ref), [`CTFlowsSciMLFlows.OoPSciMLIpRHS`](@ref), [`CTFlowsSciMLFlows.OoPSciMLIpFinalizeRHS`](@ref).
"""
function SciMLFunctionSystem(f::SciMLBase.AbstractODEFunction{true})
    rhs_fn              = IPSciMLIpRHS(f)
    rhs_oop_fn          = OoPSciMLIpRHS(f)
    rhs_oop_finalize_fn = OoPSciMLIpFinalizeRHS(f)
    return SciMLFunctionSystem{typeof(f), typeof(rhs_fn), typeof(rhs_oop_fn), typeof(rhs_oop_finalize_fn)}(
        f, rhs_fn, rhs_oop_fn, rhs_oop_finalize_fn
    )
end

"""
$(TYPEDSIGNATURES)

Construct a `SciMLFunctionSystem` from an out-of-place SciML ODE function.

Pre-computes in-place and out-of-place RHS functors. No finalize functor is needed
since the function is already out-of-place.

# Arguments
- `f::SciMLBase.AbstractODEFunction{false}`: An out-of-place ODE function with signature `(u, p, t) -> du`.

# Returns
- `SciMLFunctionSystem`: The system with pre-computed RHS functors.

See also: [`CTFlowsSciMLFlows.SciMLFunctionSystem`](@ref), [`CTFlowsSciMLFlows.IPSciMLOoPRHS`](@ref), [`CTFlowsSciMLFlows.OoPSciMLOoPRHS`](@ref).
"""
function SciMLFunctionSystem(f::SciMLBase.AbstractODEFunction{false})
    rhs_fn     = IPSciMLOoPRHS(f)
    rhs_oop_fn = OoPSciMLOoPRHS(f)
    return SciMLFunctionSystem{typeof(f), typeof(rhs_fn), typeof(rhs_oop_fn), Nothing}(
        f, rhs_fn, rhs_oop_fn, nothing
    )
end

# =============================================================================
# rhs and rhs_oop methods
# =============================================================================

"""
$(TYPEDSIGNATURES)

In-place right-hand side for a `SciMLFunctionSystem`.

Returns the pre-computed in-place closure stored in the system, which has signature
`(du, u, λ, t)` where `λ` is a `Common.ODEParameters` wrapper. The closure extracts
`Common.variable(λ)` and calls the underlying SciML function.

# Arguments
- `sys::SciMLFunctionSystem`: The system for which to return the RHS function.

# Returns
- `Systems.AbstractIPRHS`: The pre-computed functor with signature `(du, u, λ, t)`.

See also: [`CTFlowsSciMLFlows.SciMLFunctionSystem`](@ref), [`CTFlows.Systems.rhs_oop`](@ref).
"""
Systems.rhs(sys::SciMLFunctionSystem) = sys.rhs_fn

"""
$(TYPEDSIGNATURES)

Out-of-place right-hand side for a `SciMLFunctionSystem` with out-of-place function.

Returns the pre-computed out-of-place closure with signature `(u, λ, t)`. The optional
`is_mutable` argument is accepted but ignored: for out-of-place systems `rhs_oop` is
always the correct callable regardless of u0 mutability.

# Arguments
- `sys::SciMLFunctionSystem{..., Nothing}`: The out-of-place system.
- `::Bool`: Ignored. Accepted for API uniformity.

# Returns
- `Systems.AbstractOoPRHS`: The pre-computed functor with signature `(u, λ, t)`.

See also: [`CTFlowsSciMLFlows.SciMLFunctionSystem`](@ref), [`CTFlows.Systems.rhs`](@ref).
"""
function Systems.rhs_oop(sys::SciMLFunctionSystem{F, RHS, OOPROHS, Nothing}, ::Bool = true) where {F, RHS, OOPROHS}
    return sys.rhs_oop_fn
end

"""
$(TYPEDSIGNATURES)

Out-of-place right-hand side for a `SciMLFunctionSystem` with in-place function,
dispatching on u0 mutability.

For in-place SciML functions the appropriate callable depends on whether the initial
condition `u0` is mutable:
- **`is_mutable = true`** (default): returns `rhs_oop_fn`, which allocates a mutable
  buffer and returns it. Correct when `u0` is a `Vector` or similar mutable array.
- **`is_mutable = false`**: returns `rhs_oop_finalize_fn`, which allocates a mutable
  buffer, fills it via the in-place call, then converts back to `typeof(u)`. A one-time
  performance warning is emitted in this case.

# Arguments
- `sys::SciMLFunctionSystem{..., FINRHS}`: The in-place system.
- `is_mutable::Bool`: `true` if u0 is mutable, `false` if immutable. Defaults to `true`.

# Returns
- `Systems.AbstractOoPRHS`: The appropriate functor with signature `(u, λ, t)`.

# Notes
- Prefer out-of-place SciML functions when u0 is immutable (e.g. `StaticArrays.SVector`)
  for best performance.

See also: [`CTFlowsSciMLFlows.SciMLFunctionSystem`](@ref), [`CTFlows.Systems.rhs`](@ref).
"""
function Systems.rhs_oop(sys::SciMLFunctionSystem{F, RHS, OOPROHS, FINRHS}, is_mutable::Bool = true) where {F, RHS, OOPROHS, FINRHS}
    is_mutable && return sys.rhs_oop_fn
    @warn "InPlace SciMLFunction with immutable u0 (e.g. SVector): consider using an out-of-place function for better performance."
    return sys.rhs_oop_finalize_fn
end

# =============================================================================
# Unified getters: get_ip_rhs / get_oop_rhs
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the in-place right-hand side for a `SciMLFunctionSystem`.

Eager implementation: ignores the config and returns the pre-computed closure.

# Arguments
- `sys::SciMLFunctionSystem`: The system.
- `_`: The configuration (ignored).

# Returns
- `Systems.AbstractIPRHS`: The pre-computed in-place closure with signature `(du, u, λ, t) -> nothing`.

See also: [`CTFlowsSciMLFlows.SciMLFunctionSystem`](@ref), [`CTFlows.Systems.get_oop_rhs`](@ref).
"""
Systems.get_ip_rhs(sys::SciMLFunctionSystem, _) = sys.rhs_fn

"""
$(TYPEDSIGNATURES)

Return the out-of-place right-hand side for an out-of-place `SciMLFunctionSystem`.

Eager implementation: ignores the config and returns the pre-computed closure.

# Arguments
- `sys::SciMLFunctionSystem{..., Nothing}`: The out-of-place system.
- `_`: The configuration (ignored).

# Returns
- `Systems.AbstractOoPRHS`: The pre-computed out-of-place closure with signature `(u, λ, t) -> du`.

See also: [`CTFlowsSciMLFlows.SciMLFunctionSystem`](@ref), [`CTFlows.Systems.get_ip_rhs`](@ref).
"""
function Systems.get_oop_rhs(sys::SciMLFunctionSystem{F, RHS, OOPROHS, Nothing}, _) where {F, RHS, OOPROHS}
    return sys.rhs_oop_fn
end

"""
$(TYPEDSIGNATURES)

Return the out-of-place right-hand side for an in-place `SciMLFunctionSystem`.

Eager implementation: ignores the config and returns the finalize closure.
This method is called when `!ismutable(u0)`, so always returns `rhs_oop_finalize_fn`.

# Arguments
- `sys::SciMLFunctionSystem{..., FINRHS}`: The in-place system.
- `_`: The configuration (ignored).

# Returns
- `Systems.AbstractOoPRHS`: The finalize closure with signature `(u, λ, t) -> du`.

# Notes
- Emits a performance warning since this path is suboptimal for immutable arrays.

See also: [`CTFlowsSciMLFlows.SciMLFunctionSystem`](@ref), [`CTFlows.Systems.get_ip_rhs`](@ref).
"""
function Systems.get_oop_rhs(sys::SciMLFunctionSystem{F, RHS, OOPROHS, FINRHS}, _) where {F, RHS, OOPROHS, FINRHS}
    @warn "InPlace SciMLFunction with immutable u0 (e.g. SVector): consider using an out-of-place function for better performance."
    return sys.rhs_oop_finalize_fn
end

# =============================================================================
# Base.show
# =============================================================================

"""
$(TYPEDSIGNATURES)

Display a compact representation of a `SciMLFunctionSystem`.

Shows the type name, the wrapped ODE function type, and its mutability trait.

# Arguments
- `io::IO`: The IO stream to write to.
- `sys::SciMLFunctionSystem`: The system to display.

See also: [`CTFlowsSciMLFlows.SciMLFunctionSystem`](@ref).
"""
function Base.show(io::IO, sys::SciMLFunctionSystem{F}) where F
    println(io, "SciMLFunctionSystem")
    iip = SciMLBase.isinplace(sys.f)
    println(io, "  wraps: ODEFunction: non-autonomous, variable, ", iip ? "in-place" : "out-of-place")
    print(io,   "  rhs:   ", nameof(typeof(sys.rhs_fn)), " (", _rhs_sciml_label(sys.rhs_fn), ")")
end

"""
$(TYPEDSIGNATURES)

Display a `SciMLFunctionSystem` in the REPL with text/plain MIME type.

Delegates to the compact show method.

# Arguments
- `io::IO`: The IO stream to write to.
- `::MIME"text/plain"`: The MIME type for REPL display.
- `sys::SciMLFunctionSystem`: The system to display.

See also: [`CTFlowsSciMLFlows.SciMLFunctionSystem`](@ref).
"""
function Base.show(io::IO, ::MIME"text/plain", sys::SciMLFunctionSystem)
    show(io, sys)
end
