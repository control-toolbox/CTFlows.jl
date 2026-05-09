# =============================================================================
# internal_norm — fallback implementations for grid invariance
# =============================================================================

"""
$(TYPEDSIGNATURES)

Extract the primal (real) value from a number. Base case for real numbers.

This is a fallback implementation used when AD backends are not loaded.
ForwardDiff-specific implementations are provided in `CTFlowsForwardDiff`.

# Arguments
- `x::Real`: A real number (e.g., `Float64`).

# Returns
- `Real`: The input value unchanged.

# Example
```julia
julia> CTFlows.Common.deepvalue(3.14)
3.14
```
"""
deepvalue(x::Real) = x

"""
$(TYPEDSIGNATURES)

Compute the internal norm for a scalar real number.

This is a fallback implementation used when AD backends are not loaded.
ForwardDiff-specific implementations are provided in `CTFlowsForwardDiff`.

# Arguments
- `u::Real`: A scalar real number.
- `t`: Time parameter (unused but required by SciML interface).

# Returns
- `Real`: The absolute value of the input.

# Example
```julia
julia> CTFlows.Common.real_norm(3.0, 0.0)
3.0
```
"""
real_norm(u::Real, t) = abs(u)
