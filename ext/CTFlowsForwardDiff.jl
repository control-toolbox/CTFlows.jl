module CTFlowsForwardDiff

"""
    CTFlowsForwardDiff

Package extension providing ForwardDiff-specific implementations for grid invariance (IND).
Activated automatically when ForwardDiff is loaded together with CTFlows.

This extension adds:
- `deepvalue(x::ForwardDiff.Dual)` — Recursive extraction of primal values from nested duals
- `real_norm(u::ForwardDiff.Dual, t)` — Internal norm for scalar dual numbers

These functions extend the fallback implementations in `CTFlows.Common` to support ForwardDiff dual numbers.
"""
CTFlowsForwardDiff

import DocStringExtensions: TYPEDSIGNATURES
import ForwardDiff

using CTFlows: CTFlows
using CTFlows.Common: Common

# =============================================================================
# deepvalue and real_norm — ForwardDiff-specific implementations
# =============================================================================

"""
$(TYPEDSIGNATURES)

Recursively extract the primal (real) value from a ForwardDiff dual number.

Handles nested dual numbers for higher-order differentiation (e.g., second-order
derivatives where the partials themselves are dual numbers). This extends the
fallback `Common.deepvalue(x::Real)` to support ForwardDiff.

# Arguments
- `x::ForwardDiff.Dual`: A ForwardDiff dual number (possibly nested).

# Returns
- `Real`: The primal (Float64) part of the dual number.

# Example
```julia
julia> using ForwardDiff

julia> d1 = ForwardDiff.Dual{:Tag}(3.0, 1.0)
Dual{:Tag}(3.0, 1.0)

julia> CTFlowsForwardDiff.deepvalue(d1)
3.0

julia> d2 = ForwardDiff.Dual{:Tag2}(d1, d1)  # Nested dual
Dual{:Tag2}(Dual{:Tag}(3.0, 1.0), Dual{:Tag}(3.0, 1.0))

julia> CTFlowsForwardDiff.deepvalue(d2)
3.0
```

See also: [`Common.deepvalue`](@ref), [`real_norm`](@ref)
"""
Common.deepvalue(x::ForwardDiff.Dual) = Common.deepvalue(ForwardDiff.value(x))

"""
$(TYPEDSIGNATURES)

Compute the internal norm for a scalar ForwardDiff dual number using only its primal part.

This extends the fallback `Common.real_norm(u::Real, t)` to support ForwardDiff dual numbers,
ensuring grid invariance (IND) when integrating ODEs with dual numbers.

# Arguments
- `u::ForwardDiff.Dual`: A scalar dual number.
- `t`: Time parameter (unused but required by SciML interface).

# Returns
- `Real`: The absolute value of the primal part.

See also: [`Common.real_norm`](@ref), [`deepvalue`](@ref)
"""
Common.real_norm(u::ForwardDiff.Dual, t) = Common.real_norm(Common.deepvalue(u), t)

end # module CTFlowsForwardDiff
