# =============================================================================
# internal_norm — fallback implementations for grid invariance
# =============================================================================

"""
$(TYPEDSIGNATURES)

Extract the primal value from a number. Base case for scalar numbers.

This is a fallback implementation used when AD backends are not loaded.
ForwardDiff-specific implementations are provided in `CTFlowsForwardDiff` for
recursive extraction from nested dual numbers.

# Arguments
- `x::Number`: A number (e.g., `Float64`, `ComplexF64`).

# Returns
- `Number`: The input value unchanged for real and complex numbers.

# Example
```julia-repl
julia> using CTFlows.Common

julia> deepvalue(3.14)
3.14

julia> deepvalue(1.0 + 2.0im)
1.0 + 2.0im
```

# Notes
- For `ForwardDiff.Dual` numbers, the more specific method in `CTFlowsForwardDiff`
  recursively extracts the primal value via `deepvalue(value(x))`.
- This method serves as the base case for all `Number` subtypes not handled by extensions.

See also: [`CTFlows.Common.real_norm`](@ref).
"""
deepvalue(x::Number) = x

"""
$(TYPEDSIGNATURES)

Compute the internal norm for a scalar number.

This is a fallback implementation used when AD backends are not loaded.
ForwardDiff-specific implementations are provided in `CTFlowsForwardDiff`.

# Arguments
- `u::Number`: A scalar number (real or complex).
- `t`: Time parameter (unused but required by SciML interface).

# Returns
- `Number`: The absolute value for real numbers, or magnitude for complex numbers.

# Example
```julia-repl
julia> using CTFlows.Common

julia> real_norm(3.0, 0.0)
3.0

julia> real_norm(3.0 + 4.0im, 0.0)
5.0
```

# Notes
- For real numbers, returns `abs(u)`.
- For complex numbers, returns `abs(u)` (the magnitude).
- Used by SciML integrators for step-size control in grid-invariant computations.

See also: [`CTFlows.Common.deepvalue`](@ref).
"""
real_norm(u::Number, t) = abs(u)
