"""
$(TYPEDEF)

Abstract strategy for solving ODE Cauchy problems.

An `AbstractIntegrator` is a strategy that solves an ODE problem over a time span.

This type inherits the full CTSolvers strategy contract:
- `id(::Type{<:S}) → Symbol`
- `metadata(::Type{<:S}) → StrategyMetadata`
- `options(s::S) → StrategyOptions`
- `Base.show` (tree + compact, automatic)
- `describe(::Type{<:S})`

# Contract

All subtypes must implement:
- `(integrator)(prob)`: Solve the given ODE problem (tspan is embedded in `prob`).

# Throws
- `CTBase.Exceptions.NotImplemented`: If the callable is not implemented by the concrete type.

See also: [`AbstractFlow`](@ref).
"""
abstract type AbstractIntegrator <: CTSolvers.Strategies.AbstractStrategy end

"""
$(TYPEDSIGNATURES)

Solve the given ODE problem.

# Arguments
- `integrator::AbstractIntegrator`: The integrator strategy.
- `prob`: The ODE problem to solve (type varies by concrete integrator; tspan is embedded).

# Returns
- The ODE solution (type varies by concrete integrator).

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`AbstractIntegrator`](@ref).
"""
function (integrator::AbstractIntegrator)(prob)
    throw(Exceptions.NotImplemented(
        "AbstractIntegrator callable not implemented";
        required_method = "(integrator::$(typeof(integrator)))(prob)",
        suggestion = "Implement (i::YourIntegrator)(prob) returning an ODE solution.",
        context = "AbstractIntegrator call - required method implementation",
    ))
end
