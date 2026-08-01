# =============================================================================
# RHS Functors for SciMLFunctionSystem
# =============================================================================

# =============================================================================
# Concrete functors
# =============================================================================

"""
$(TYPEDEF)

In-place RHS functor for an in-place SciML ODEFunction.

Wraps an in-place SciML function and provides an in-place interface
by directly calling the function.

# Fields
- `f::F`: The wrapped SciML ODEFunction
- `cx::CX`: coercion applied to the state before calling `f` (`_safe_only` for a 1-D
  state, `identity` otherwise, per issue #357 — `SciMLFunctionSystem` shares
  `VectorFieldSystem`'s `Systems`/`Trajectories` dispatch, so it gets the same
  1-D = scalar coercion; see [`CTFlows.Systems._coerce_state`](@extref)).

# Call signature
`(r::IPSciMLIpRHS)(du, u, λ, t) -> nothing`

See also: [`CTFlowsSciMLFlows.OoPSciMLIpRHS`](@extref), [`CTFlowsSciMLFlows.OoPSciMLIpFinalizeRHS`](@extref), [`CTFlowsSciMLFlows.IPSciMLOoPRHS`](@extref), [`CTFlowsSciMLFlows.OoPSciMLOoPRHS`](@extref).
"""
struct IPSciMLIpRHS{
    F<:SciMLBase.AbstractODEFunction{true},
    CX<:Union{typeof(Systems._safe_only),typeof(identity)},
} <: Systems.AbstractIPRHS
    f::F
    cx::CX
end

function (r::IPSciMLIpRHS)(du, u, λ, t)
    r.f(du, r.cx(u), Systems.variable(λ), t)
    return nothing
end

"""
$(TYPEDEF)

Out-of-place RHS functor for an in-place SciML ODEFunction.

Wraps an in-place SciML function and provides an out-of-place interface
by allocating a temporary buffer on each call.

# Fields
- `f::F`: The wrapped SciML ODEFunction
- `cx::CX`: coercion applied to the state before calling `f`.

# Call signature
`(r::OoPSciMLIpRHS)(u, λ, t) -> du`

# Notes
- `dx = similar(u)` already matches `u`'s actual (uncoerced) shape, so no reshaping is
  needed even when `cx` collapses the CALL argument to a scalar.

See also: [`CTFlowsSciMLFlows.IPSciMLIpRHS`](@extref), [`CTFlowsSciMLFlows.OoPSciMLIpFinalizeRHS`](@extref), [`CTFlowsSciMLFlows.IPSciMLOoPRHS`](@extref), [`CTFlowsSciMLFlows.OoPSciMLOoPRHS`](@extref).
"""
struct OoPSciMLIpRHS{
    F<:SciMLBase.AbstractODEFunction{true},
    CX<:Union{typeof(Systems._safe_only),typeof(identity)},
} <: Systems.AbstractOoPRHS
    f::F
    cx::CX
end

function (r::OoPSciMLIpRHS)(u, λ, t)
    dx = similar(u)
    r.f(dx, r.cx(u), Systems.variable(λ), t)
    return dx
end

"""
$(TYPEDEF)

Out-of-place RHS functor for an in-place SciML ODEFunction with type conversion.

Wraps an in-place SciML function and provides an out-of-place interface
that converts the result to match the input type (e.g., Vector → SVector).

# Fields
- `f::F`: The wrapped SciML ODEFunction
- `cx::CX`: coercion applied to the state before calling `f`.

# Call signature
`(r::OoPSciMLIpFinalizeRHS)(u, λ, t) -> du`

See also: [`CTFlowsSciMLFlows.IPSciMLIpRHS`](@extref), [`CTFlowsSciMLFlows.OoPSciMLIpRHS`](@extref), [`CTFlowsSciMLFlows.IPSciMLOoPRHS`](@extref), [`CTFlowsSciMLFlows.OoPSciMLOoPRHS`](@extref).
"""
struct OoPSciMLIpFinalizeRHS{
    F<:SciMLBase.AbstractODEFunction{true},
    CX<:Union{typeof(Systems._safe_only),typeof(identity)},
} <: Systems.AbstractOoPRHS
    f::F
    cx::CX
end

function (r::OoPSciMLIpFinalizeRHS)(u, λ, t)
    dx = similar(u)
    r.f(dx, r.cx(u), Systems.variable(λ), t)
    return typeof(u)(dx)
end

"""
$(TYPEDEF)

In-place RHS functor for an out-of-place SciML ODEFunction.

Wraps an out-of-place SciML function and provides an in-place interface
by allocating the result into the pre-allocated `du` buffer.

# Fields
- `f::F`: The wrapped SciML ODEFunction
- `cx::CX`: coercion applied to the state before calling `f`.

# Call signature
`(r::IPSciMLOoPRHS)(du, u, λ, t) -> nothing`

See also: [`CTFlowsSciMLFlows.IPSciMLIpRHS`](@extref), [`CTFlowsSciMLFlows.OoPSciMLIpRHS`](@extref), [`CTFlowsSciMLFlows.OoPSciMLIpFinalizeRHS`](@extref), [`CTFlowsSciMLFlows.OoPSciMLOoPRHS`](@extref).
"""
struct IPSciMLOoPRHS{
    F<:SciMLBase.AbstractODEFunction{false},
    CX<:Union{typeof(Systems._safe_only),typeof(identity)},
} <: Systems.AbstractIPRHS
    f::F
    cx::CX
end

function (r::IPSciMLOoPRHS)(du, u, λ, t)
    du .= r.f(r.cx(u), Systems.variable(λ), t)
    return nothing
end

"""
$(TYPEDEF)

Out-of-place RHS functor for an out-of-place SciML ODEFunction.

Wraps an out-of-place SciML function and provides an out-of-place interface
by directly calling the function.

# Fields
- `f::F`: The wrapped SciML ODEFunction
- `cx::CX`: coercion applied to the state before calling `f`.

# Call signature
`(r::OoPSciMLOoPRHS)(u, λ, t) -> du`

# Notes
- Unlike the Hamiltonian-family out-of-place functors, this functor has a single
  block and nothing to reassemble: when `cx` collapses `u` to a scalar for the call,
  `f` may return a bare scalar too, which does not match `u`'s own (uncoerced)
  container shape. That case is reshaped back explicitly, matching
  [`CTFlows.Systems.OoPVFOoPRHS`](@extref)'s identical handling.

See also: [`CTFlowsSciMLFlows.IPSciMLIpRHS`](@extref), [`CTFlowsSciMLFlows.OoPSciMLIpRHS`](@extref), [`CTFlowsSciMLFlows.OoPSciMLIpFinalizeRHS`](@extref), [`CTFlowsSciMLFlows.IPSciMLOoPRHS`](@extref).
"""
struct OoPSciMLOoPRHS{
    F<:SciMLBase.AbstractODEFunction{false},
    CX<:Union{typeof(Systems._safe_only),typeof(identity)},
} <: Systems.AbstractOoPRHS
    f::F
    cx::CX
end

function (r::OoPSciMLOoPRHS)(u, λ, t)
    du = r.f(r.cx(u), Systems.variable(λ), t)
    if du isa Number && !(u isa Number)
        buf = similar(u)
        buf .= du
        return typeof(u)(buf)
    end
    return du
end

# =============================================================================
# Display helpers
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return a human-readable label describing the RHS conversion strategy.

# Arguments
- `r::IPSciMLIpRHS`: In-place SciML → in-place interface functor.
- `r::OoPSciMLIpRHS`: In-place SciML → out-of-place interface functor.
- `r::OoPSciMLIpFinalizeRHS`: In-place SciML → out-of-place interface with type conversion functor.
- `r::IPSciMLOoPRHS`: Out-of-place SciML → in-place interface functor.
- `r::OoPSciMLOoPRHS`: Out-of-place SciML → out-of-place interface functor.

# Returns
- `String`: A descriptive label of the conversion strategy.

# Notes
- Internal helper used for display purposes in `Base.show` methods.
- Labels describe both the wrapped SciML function's interface and the provided interface.

See also: [`_AnySciMLRHS`](@extref).
"""
_rhs_sciml_label(::IPSciMLIpRHS) = "in-place SciML → in-place interface"
_rhs_sciml_label(::OoPSciMLIpRHS) = "in-place SciML → out-of-place interface"
function _rhs_sciml_label(::OoPSciMLIpFinalizeRHS)
    return "in-place SciML → out-of-place interface + finalize"
end
_rhs_sciml_label(::IPSciMLOoPRHS) = "out-of-place SciML → in-place interface"
_rhs_sciml_label(::OoPSciMLOoPRHS) = "out-of-place SciML → out-of-place interface"

"""
$(TYPEDSIGNATURES)

Union type of all SciML RHS functors.

# Notes
- Internal type alias used for method dispatch on display methods.
- Covers all five conversion strategies between in-place and out-of-place interfaces.

See also: [`_rhs_sciml_label`](@extref), [`IPSciMLIpRHS`](@extref), [`OoPSciMLIpRHS`](@extref), [`OoPSciMLIpFinalizeRHS`](@extref), [`IPSciMLOoPRHS`](@extref), [`OoPSciMLOoPRHS`](@extref).
"""
const _AnySciMLRHS = Union{
    IPSciMLIpRHS,OoPSciMLIpRHS,OoPSciMLIpFinalizeRHS,IPSciMLOoPRHS,OoPSciMLOoPRHS
}

"""
$(TYPEDSIGNATURES)

Display a compact representation of a SciML RHS functor.

Shows the functor type name, the wrapped ODE function's mutability trait,
and the conversion strategy label.

# Arguments
- `io::IO`: The IO stream to write to.
- `r::_AnySciMLRHS`: The SciML RHS functor to display.

See also: [`CTFlowsSciMLFlows._rhs_sciml_label`](@extref), [`CTFlowsSciMLFlows._AnySciMLRHS`](@extref).
"""
function Base.show(io::IO, r::_AnySciMLRHS)
    fmt = Display.format_codes(io)
    iip = SciMLBase.isinplace(r.f)
    Display.print_header(io, nameof(typeof(r)); fmt=fmt)
    Display.print_field(
        io,
        "wraps",
        "ODEFunction: " * (iip ? "in-place" : "out-of-place");
        fmt=fmt,
        value_style="",
    )
    return Display.print_field(
        io, "converts", _rhs_sciml_label(r); last=true, fmt=fmt, value_style=""
    )
end

"""
$(TYPEDSIGNATURES)

Display a SciML RHS functor in the REPL with text/plain MIME type.

Delegates to the compact show method.

# Arguments
- `io::IO`: The IO stream to write to.
- `::MIME"text/plain"`: The MIME type for REPL display.
- `r::_AnySciMLRHS`: The SciML RHS functor to display.

See also: [`CTFlowsSciMLFlows._AnySciMLRHS`](@extref).
"""
function Base.show(io::IO, ::MIME"text/plain", r::_AnySciMLRHS)
    return show(io, r)
end
