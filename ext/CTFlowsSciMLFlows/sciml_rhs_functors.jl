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

# Call signature
`(r::IPSciMLIpRHS)(du, u, λ, t) -> nothing`

See also: [`CTFlowsSciMLFlows.OoPSciMLIpRHS`](@ref), [`CTFlowsSciMLFlows.OoPSciMLIpFinalizeRHS`](@ref), [`CTFlowsSciMLFlows.IPSciMLOoPRHS`](@ref), [`CTFlowsSciMLFlows.OoPSciMLOoPRHS`](@ref).
"""
struct IPSciMLIpRHS{F<:SciMLBase.AbstractODEFunction{true}} <: Systems.AbstractIPRHS
    f::F
end

function (r::IPSciMLIpRHS)(du, u, λ, t)
    r.f(du, u, Systems.variable(λ), t)
    nothing
end

"""
$(TYPEDEF)

Out-of-place RHS functor for an in-place SciML ODEFunction.

Wraps an in-place SciML function and provides an out-of-place interface
by allocating a temporary buffer on each call.

# Fields
- `f::F`: The wrapped SciML ODEFunction

# Call signature
`(r::OoPSciMLIpRHS)(u, λ, t) -> du`

See also: [`CTFlowsSciMLFlows.IPSciMLIpRHS`](@ref), [`CTFlowsSciMLFlows.OoPSciMLIpFinalizeRHS`](@ref), [`CTFlowsSciMLFlows.IPSciMLOoPRHS`](@ref), [`CTFlowsSciMLFlows.OoPSciMLOoPRHS`](@ref).
"""
struct OoPSciMLIpRHS{F<:SciMLBase.AbstractODEFunction{true}} <: Systems.AbstractOoPRHS
    f::F
end

function (r::OoPSciMLIpRHS)(u, λ, t)
    dx = similar(u)
    r.f(dx, u, Systems.variable(λ), t)
    dx
end

"""
$(TYPEDEF)

Out-of-place RHS functor for an in-place SciML ODEFunction with type conversion.

Wraps an in-place SciML function and provides an out-of-place interface
that converts the result to match the input type (e.g., Vector → SVector).

# Fields
- `f::F`: The wrapped SciML ODEFunction

# Call signature
`(r::OoPSciMLIpFinalizeRHS)(u, λ, t) -> du`

See also: [`CTFlowsSciMLFlows.IPSciMLIpRHS`](@ref), [`CTFlowsSciMLFlows.OoPSciMLIpRHS`](@ref), [`CTFlowsSciMLFlows.IPSciMLOoPRHS`](@ref), [`CTFlowsSciMLFlows.OoPSciMLOoPRHS`](@ref).
"""
struct OoPSciMLIpFinalizeRHS{F<:SciMLBase.AbstractODEFunction{true}} <: Systems.AbstractOoPRHS
    f::F
end

function (r::OoPSciMLIpFinalizeRHS)(u, λ, t)
    dx = similar(u)
    r.f(dx, u, Systems.variable(λ), t)
    typeof(u)(dx)
end

"""
$(TYPEDEF)

In-place RHS functor for an out-of-place SciML ODEFunction.

Wraps an out-of-place SciML function and provides an in-place interface
by allocating the result into the pre-allocated `du` buffer.

# Fields
- `f::F`: The wrapped SciML ODEFunction

# Call signature
`(r::IPSciMLOoPRHS)(du, u, λ, t) -> nothing`

See also: [`CTFlowsSciMLFlows.IPSciMLIpRHS`](@ref), [`CTFlowsSciMLFlows.OoPSciMLIpRHS`](@ref), [`CTFlowsSciMLFlows.OoPSciMLIpFinalizeRHS`](@ref), [`CTFlowsSciMLFlows.OoPSciMLOoPRHS`](@ref).
"""
struct IPSciMLOoPRHS{F<:SciMLBase.AbstractODEFunction{false}} <: Systems.AbstractIPRHS
    f::F
end

function (r::IPSciMLOoPRHS)(du, u, λ, t)
    du .= r.f(u, Systems.variable(λ), t)
    nothing
end

"""
$(TYPEDEF)

Out-of-place RHS functor for an out-of-place SciML ODEFunction.

Wraps an out-of-place SciML function and provides an out-of-place interface
by directly calling the function.

# Fields
- `f::F`: The wrapped SciML ODEFunction

# Call signature
`(r::OoPSciMLOoPRHS)(u, λ, t) -> du`

See also: [`CTFlowsSciMLFlows.IPSciMLIpRHS`](@ref), [`CTFlowsSciMLFlows.OoPSciMLIpRHS`](@ref), [`CTFlowsSciMLFlows.OoPSciMLIpFinalizeRHS`](@ref), [`CTFlowsSciMLFlows.IPSciMLOoPRHS`](@ref).
"""
struct OoPSciMLOoPRHS{F<:SciMLBase.AbstractODEFunction{false}} <: Systems.AbstractOoPRHS
    f::F
end

function (r::OoPSciMLOoPRHS)(u, λ, t)
    r.f(u, Systems.variable(λ), t)
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

See also: [`_AnySciMLRHS`](@ref).
"""
_rhs_sciml_label(::IPSciMLIpRHS) = "in-place SciML → in-place interface"
_rhs_sciml_label(::OoPSciMLIpRHS) = "in-place SciML → out-of-place interface"
_rhs_sciml_label(::OoPSciMLIpFinalizeRHS) = "in-place SciML → out-of-place interface + finalize"
_rhs_sciml_label(::IPSciMLOoPRHS) = "out-of-place SciML → in-place interface"
_rhs_sciml_label(::OoPSciMLOoPRHS) = "out-of-place SciML → out-of-place interface"

"""
$(TYPEDSIGNATURES)

Union type of all SciML RHS functors.

# Notes
- Internal type alias used for method dispatch on display methods.
- Covers all five conversion strategies between in-place and out-of-place interfaces.

See also: [`_rhs_sciml_label`](@ref), [`IPSciMLIpRHS`](@ref), [`OoPSciMLIpRHS`](@ref), [`OoPSciMLIpFinalizeRHS`](@ref), [`IPSciMLOoPRHS`](@ref), [`OoPSciMLOoPRHS`](@ref).
"""
const _AnySciMLRHS = Union{IPSciMLIpRHS, OoPSciMLIpRHS, OoPSciMLIpFinalizeRHS,
                           IPSciMLOoPRHS, OoPSciMLOoPRHS}

"""
$(TYPEDSIGNATURES)

Display a compact representation of a SciML RHS functor.

Shows the functor type name, the wrapped ODE function's mutability trait,
and the conversion strategy label.

# Arguments
- `io::IO`: The IO stream to write to.
- `r::_AnySciMLRHS`: The SciML RHS functor to display.

See also: [`CTFlowsSciMLFlows._rhs_sciml_label`](@ref), [`CTFlowsSciMLFlows._AnySciMLRHS`](@ref).
"""
function Base.show(io::IO, r::_AnySciMLRHS)
    println(io, nameof(typeof(r)))
    iip = SciMLBase.isinplace(r.f)
    println(io, "  wraps: ODEFunction: ", iip ? "in-place" : "out-of-place")
    print(io,   "  converts: ", _rhs_sciml_label(r))
end

"""
$(TYPEDSIGNATURES)

Display a SciML RHS functor in the REPL with text/plain MIME type.

Delegates to the compact show method.

# Arguments
- `io::IO`: The IO stream to write to.
- `::MIME"text/plain"`: The MIME type for REPL display.
- `r::_AnySciMLRHS`: The SciML RHS functor to display.

See also: [`CTFlowsSciMLFlows._AnySciMLRHS`](@ref).
"""
function Base.show(io::IO, ::MIME"text/plain", r::_AnySciMLRHS)
    show(io, r)
end
