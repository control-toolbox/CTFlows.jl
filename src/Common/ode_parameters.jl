"""
$(TYPEDEF)

Wrapper type for parameters passed through SciML's `p` slot.

This type formalizes the contract for what transits in the ODE problem's
parameter slot. For CTFlows, the primary content is the variable parameter
for `NonFixed` systems (or `nothing` for `Fixed` systems). For systems with
automatic differentiation support, the cache field stores pre-allocated buffers
and prepared differentiation plans.

The wrapper makes the contract explicit and extensible — additional fields
can be added later (callbacks, extra data) without breaking existing code.

# Fields
- `variable::V`: The variable parameter (or `nothing` for `Fixed` systems).
- `cache::C`: The AD cache (or `nothing` for systems without AD support).

# Constructor Validation

- `V` can be `Nothing` (for `Fixed` systems) or any concrete type (for `NonFixed`).
- `C` can be `Nothing` (for systems without AD) or a concrete `AbstractCache` subtype.
- No validation is performed at construction — the system's `VariableDependence`
  and `ADTrait` determine whether `variable` and `cache` should be used.

# Example
\`\`\`julia
using CTFlows.Common

# Fixed system: variable is nothing, cache is nothing
params_fixed = ODEParameters(nothing)

# NonFixed system: variable is a value, cache is nothing
params_nonfixed = ODEParameters(0.5)

# WithAD system: variable is a value, cache is a concrete cache
cache = MyCache()
params_with_ad = ODEParameters(0.5, cache)
\`\`\`

# Notes
- This type is used exclusively by the SciML extension to wrap the variable
  before passing it to `ODEProblem`.
- The RHS closure reads `variable(p)` to access the actual variable value.
- The RHS closure reads `cache(p)` to access the prepared AD cache.
- A single-argument constructor `ODEParameters(variable)` defaults `cache` to `nothing`
  for backward compatibility.

See also: [`CTFlows.Common.VariableDependence`](@ref), [`CTFlows.Common.Fixed`](@ref), [`CTFlows.Common.NonFixed`](@ref),
[`CTFlows.Common.AbstractCache`](@ref), [`CTFlows.Common.AbstractADTrait`](@ref).
"""
struct ODEParameters{V, C<:Union{AbstractCache, Nothing}}
    variable::V
    cache::C
end

# Backward compatibility constructor for single-argument calls
function ODEParameters(variable)
    return ODEParameters(variable, nothing)
end

"""
$(TYPEDSIGNATURES)

Accessor for the cache field of `ODEParameters`.

Returns the AD cache stored in the `ODEParameters` wrapper.
For systems without AD support, this is `nothing`. For systems with AD support,
this is a concrete `AbstractCache` subtype containing pre-allocated buffers and
prepared differentiation plans.

# Arguments
- `p::ODEParameters`: The ODEParameters instance.

# Returns
- The cache value (or `nothing` for systems without AD).

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> params_fixed = ODEParameters(nothing)
ODEParameters{Nothing, Nothing}(nothing, nothing)

julia> cache(params_fixed)
nothing

julia> params_with_ad = ODEParameters(0.5, MyCache())
ODEParameters{Float64, MyCache}(0.5, MyCache())

julia> cache(params_with_ad)
MyCache()
\`\`\`

See also: [`CTFlows.Common.ODEParameters`](@ref), [`CTFlows.Common.AbstractCache`](@ref).
"""
function cache(p::ODEParameters)
    return p.cache
end

"""
$(TYPEDSIGNATURES)

Accessor for the variable field of `ODEParameters`.

Returns the variable parameter stored in the `ODEParameters` wrapper.
For `Fixed` systems, this is `nothing`. For `NonFixed` systems, this is
the actual variable value (scalar or vector).

# Arguments
- `p::ODEParameters`: The ODEParameters instance.

# Returns
- The variable value (or `nothing` for Fixed systems).

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> params_fixed = ODEParameters(nothing)
ODEParameters{Nothing}(nothing)

julia> variable(params_fixed)
nothing

julia> params_nonfixed = ODEParameters(0.5)
ODEParameters{Float64}(0.5)

julia> variable(params_nonfixed)
0.5
\`\`\`

See also: [`CTFlows.Common.ODEParameters`](@ref), [`CTFlows.Common.VariableDependence`](@ref).
"""
function variable(p::ODEParameters)
    return p.variable
end
