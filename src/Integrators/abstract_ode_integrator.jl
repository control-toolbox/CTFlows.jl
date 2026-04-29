"""
$(TYPEDEF)

Abstract strategy for solving ODE Cauchy problems.

An `AbstractODEIntegrator` is a strategy that solves an ODE problem over a time span.

This type inherits the full CTSolvers strategy contract:
- `id(::Type{<:S}) → Symbol`
- `metadata(::Type{<:S}) → StrategyMetadata`
- `options(s::S) → StrategyOptions`
- `Base.show` (tree + compact, automatic)
- `describe(::Type{<:S})`

# Contract

All subtypes must implement:
- `(integrator)(ode_problem, tspan)`: Solve the ODE problem over the given time span.

# Throws
- `CTBase.Exceptions.NotImplemented`: If the callable is not implemented by the concrete type.

See also: [`AbstractFlow`](@ref).
"""
abstract type AbstractODEIntegrator <: CTSolvers.Strategies.AbstractStrategy end

"""
$(TYPEDSIGNATURES)

Solve the ODE problem over the given time span.

# Arguments
- `integrator::AbstractODEIntegrator`: The integrator strategy.
- `ode_problem`: The ODE problem to solve (type varies by concrete integrator).
- `tspan`: The time span `(t0, tf)` over which to solve.

# Returns
- The ODE solution (type varies by concrete integrator).

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`AbstractODEIntegrator`](@ref).
"""
function (integrator::AbstractODEIntegrator)(ode_problem, tspan)
    throw(Exceptions.NotImplemented(
        "AbstractODEIntegrator callable not implemented";
        required_method = "(integrator::$(typeof(integrator)))(ode_problem, tspan)",
        suggestion = "Implement (i::YourIntegrator)(prob, tspan) returning an ODE solution.",
        context = "AbstractODEIntegrator call - required method implementation",
    ))
end
