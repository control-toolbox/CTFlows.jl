"""
$(TYPEDEF)

Abstract base type for automatic differentiation caches.

Caches store pre-allocated buffers and prepared differentiation plans to avoid
repeated allocation during ODE integration. Concrete cache types are extension-specific
(e.g., `_DifferentiationInterfaceCache` from the `CTFlowsDifferentiationInterface` extension).

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> isabstracttype(Common.AbstractCache)
true
\`\`\`

# Notes
- Caches are passed through `ODEParameters` during ODE integration
- The cache field defaults to `nothing` for systems that don't require AD
- Concrete cache types are defined in extensions that provide AD backends
- The RHS closure reads `cache(p)` to access the prepared cache

See also: [`CTFlows.Common.ODEParameters`](@ref), [`CTFlows.Traits.AbstractADTrait`](@ref).
"""
abstract type AbstractCache end
