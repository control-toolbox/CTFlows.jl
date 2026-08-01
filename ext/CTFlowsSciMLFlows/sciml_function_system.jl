# =============================================================================
# SciMLFunctionSystem
# =============================================================================

"""
$(TYPEDEF)

Concrete `AbstractStateSystem` wrapping a `SciMLBase.AbstractODEFunction`.

Unlike a genuine SciML bypass (`SciMLProblemFlow`, wrapping an `AbstractODEProblem`),
this system implements `Systems.AbstractSystem` (`get_ip_rhs`/`get_oop_rhs`) and shares
`VectorFieldSystem`'s `Systems`/`Trajectories` dispatch, so per issue
[control-toolbox/CTFlows.jl#357](https://github.com/control-toolbox/CTFlows.jl/issues/357)
it also follows the "1-D = scalar" convention: RHS closures are built lazily by
`get_ip_rhs`/`get_oop_rhs` based on the actual initial condition type, coercing a 1-D
state to a scalar before calling the wrapped ODE function — mirroring
[`CTFlows.Systems.VectorFieldSystem`](@extref).

Unlike CTFlows-native systems, this system passes `p = variable` directly to the ODE —
no `ODEParameters` wrapper — so users can pass arbitrary SciML parameter objects.

The mutability trait is encoded in the `iip` type parameter of the wrapped function:
- `AbstractODEFunction{true}` → in-place `f!(du, u, p, t)`
- `AbstractODEFunction{false}` → out-of-place `f(u, p, t) -> du`

# Type Parameters
- `F <: SciMLBase.AbstractODEFunction`: The wrapped ODE function.

# Fields
- `f::F`: The wrapped SciML ODE function.

# Example
```julia
using SciMLBase, CTFlows

f = ODEFunction((du, u, p, t) -> du .= -p .* u)
sys = SciMLFunctionSystem(f)
```
"""
struct SciMLFunctionSystem{F<:SciMLBase.AbstractODEFunction} <:
       Systems.AbstractStateSystem{Traits.NonAutonomous,Traits.NonFixed}
    f::F
end

# Note: no explicit outer constructor — Julia's auto-generated default outer
# constructor already matches this struct's own bound exactly (the single type
# parameter is inferable from the `f` field's type), same as VectorFieldSystem.

# =============================================================================
# Unified getters: get_ip_rhs / get_oop_rhs
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the in-place right-hand side for an in-place `SciMLFunctionSystem`.

Lazy implementation: reads `x0` from the config to build a type-specific closure.

# Arguments
- `sys::SciMLFunctionSystem{<:SciMLBase.AbstractODEFunction{true}}`: The in-place system.
- `config::Configs.AbstractStateConfig`: The state configuration.

# Returns
- `Systems.AbstractIPRHS`: The in-place closure with signature `(du, u, λ, t) -> nothing`.

See also: [`CTFlows.Systems.get_oop_rhs`](@extref).
"""
function Systems.get_ip_rhs(
    sys::SciMLFunctionSystem{F}, config::Configs.AbstractStateConfig
) where {F<:SciMLBase.AbstractODEFunction{true}}
    x0 = Configs.initial_state(config)
    return IPSciMLIpRHS(sys.f, Systems._coerce_state(x0))
end

"""
$(TYPEDSIGNATURES)

Return the in-place right-hand side for an out-of-place `SciMLFunctionSystem`.

Lazy implementation: reads `x0` from the config to build a type-specific closure.

# Arguments
- `sys::SciMLFunctionSystem{<:SciMLBase.AbstractODEFunction{false}}`: The out-of-place system.
- `config::Configs.AbstractStateConfig`: The state configuration.

# Returns
- `Systems.AbstractIPRHS`: The in-place closure with signature `(du, u, λ, t) -> nothing`.

See also: [`CTFlows.Systems.get_oop_rhs`](@extref).
"""
function Systems.get_ip_rhs(
    sys::SciMLFunctionSystem{F}, config::Configs.AbstractStateConfig
) where {F<:SciMLBase.AbstractODEFunction{false}}
    x0 = Configs.initial_state(config)
    return IPSciMLOoPRHS(sys.f, Systems._coerce_state(x0))
end

"""
$(TYPEDSIGNATURES)

Return the out-of-place right-hand side for an out-of-place `SciMLFunctionSystem`.

Lazy implementation: reads `x0` from the config to build a type-specific closure.

# Arguments
- `sys::SciMLFunctionSystem{<:SciMLBase.AbstractODEFunction{false}}`: The out-of-place system.
- `config::Configs.AbstractStateConfig`: The state configuration.

# Returns
- `Systems.AbstractOoPRHS`: The out-of-place closure with signature `(u, λ, t) -> du`.

See also: [`CTFlows.Systems.get_ip_rhs`](@extref).
"""
function Systems.get_oop_rhs(
    sys::SciMLFunctionSystem{F}, config::Configs.AbstractStateConfig
) where {F<:SciMLBase.AbstractODEFunction{false}}
    x0 = Configs.initial_state(config)
    return OoPSciMLOoPRHS(sys.f, Systems._coerce_state(x0))
end

"""
$(TYPEDSIGNATURES)

Return the out-of-place right-hand side for an in-place `SciMLFunctionSystem`.

Lazy implementation: reads `x0` from the config to build a type-specific closure.
This method is called when `!ismutable(u0)`, so the finalize path is used whenever
`x0` is itself immutable (e.g. `SVector`).

# Arguments
- `sys::SciMLFunctionSystem{<:SciMLBase.AbstractODEFunction{true}}`: The in-place system.
- `config::Configs.AbstractStateConfig`: The state configuration.

# Returns
- `Systems.AbstractOoPRHS`: The out-of-place closure with signature `(u, λ, t) -> du`.

# Notes
- Emits a performance warning when called with immutable initial conditions.

See also: [`CTFlows.Systems.get_ip_rhs`](@extref).
"""
function Systems.get_oop_rhs(
    sys::SciMLFunctionSystem{F}, config::Configs.AbstractStateConfig
) where {F<:SciMLBase.AbstractODEFunction{true}}
    x0 = Configs.initial_state(config)
    cx = Systems._coerce_state(x0)
    if !ismutable(x0)
        @warn "InPlace SciMLFunction with immutable u0 (e.g. SVector): consider using an out-of-place function for better performance."
        return OoPSciMLIpFinalizeRHS(sys.f, cx)
    end
    return OoPSciMLIpRHS(sys.f, cx)
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

See also: [`CTFlowsSciMLFlows.SciMLFunctionSystem`](@extref).
"""
function Base.show(io::IO, sys::SciMLFunctionSystem{F}) where {F}
    fmt = Display.format_codes(io)
    iip = SciMLBase.isinplace(sys.f)
    wraps = "ODEFunction: non-autonomous, variable, " * (iip ? "in-place" : "out-of-place")
    Display.print_header(io, "SciMLFunctionSystem"; fmt=fmt)
    return Display.print_field(io, "wraps", wraps; last=true, fmt=fmt, value_style="")
end

"""
$(TYPEDSIGNATURES)

Display a `SciMLFunctionSystem` in the REPL with text/plain MIME type.

Delegates to the compact show method.

# Arguments
- `io::IO`: The IO stream to write to.
- `::MIME"text/plain"`: The MIME type for REPL display.
- `sys::SciMLFunctionSystem`: The system to display.

See also: [`CTFlowsSciMLFlows.SciMLFunctionSystem`](@extref).
"""
function Base.show(io::IO, ::MIME"text/plain", sys::SciMLFunctionSystem)
    return show(io, sys)
end
