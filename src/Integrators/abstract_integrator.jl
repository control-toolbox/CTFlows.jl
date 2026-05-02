"""
$(TYPEDEF)

Abstract strategy for solving ODE Cauchy problems.

An `AbstractIntegrator` is a strategy that solves an ODE problem over a time span.

This type inherits the CTSolvers strategy contract:

# Type-Level Contract (Static Metadata)

Methods defined on the **type** that describe what the integrator can do:
- `id(::Type{<:S}) → Symbol`: Unique identifier for routing and introspection
- `metadata(::Type{<:S}) → StrategyMetadata`: Option specifications and validation rules

# Instance-Level Contract (Configured State)

Methods defined on **instances** that provide the actual configuration:
- `options(s::S) → StrategyOptions`: Current option values with provenance tracking

# Concrete Implementation

All subtypes must implement three callable signatures:

- `(integrator)(system::Systems.AbstractSystem, config::Common.AbstractConfig; variable)`: Build the ODE problem representation from a system and configuration.
- `(integrator)(prob)`: Solve the given ODE problem (tspan is embedded in `prob`).
- `(integrator)(ode_sol, sys::Systems.AbstractSystem, config::Common.AbstractConfig)`: Build the flow solution from an ODE solution.

# Throws
- `CTBase.Exceptions.NotImplemented`: If the callable is not implemented by the concrete type.

See also: [`AbstractFlow`](@ref).
"""
abstract type AbstractIntegrator <: CTSolvers.Strategies.AbstractStrategy end

"""
$(TYPEDSIGNATURES)

Build the ODE problem representation from a system and configuration.

# Arguments
- `integrator::AbstractIntegrator`: The integrator strategy.
- `system::Systems.AbstractSystem`: The system to build a problem for.
- `config::Common.AbstractConfig`: The integration configuration.
- `variable`: The variable parameter value (required for NonFixed systems).

# Returns
- The ODE problem representation (type varies by concrete integrator).

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`AbstractIntegrator`](@ref), [`(integrator)(prob)`](@ref).
"""
function (integrator::AbstractIntegrator)(system::Systems.AbstractSystem, config::Common.AbstractConfig; variable)
    throw(Exceptions.NotImplemented(
        "AbstractIntegrator problem building not implemented";
        required_method = "(integrator::$(typeof(integrator)))(system::Systems.AbstractSystem, config::Common.AbstractConfig; variable)",
        suggestion = "Implement (i::YourIntegrator)(system, config; variable) returning an ODE problem representation.",
        context = "AbstractIntegrator problem building - required method implementation",
    ))
end

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

See also: [`AbstractIntegrator`](@ref), [`(integrator)(system, config; variable)`](@ref).
"""
function (integrator::AbstractIntegrator)(prob)
    throw(Exceptions.NotImplemented(
        "AbstractIntegrator callable not implemented";
        required_method = "(integrator::$(typeof(integrator)))(prob)",
        suggestion = "Implement (i::YourIntegrator)(prob) returning an ODE solution.",
        context = "AbstractIntegrator call - required method implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Build the flow solution from an ODE solution.

# Arguments
- `integrator::AbstractIntegrator`: The integrator strategy.
- `ode_sol`: The ODE solution to package.
- `sys::Systems.AbstractSystem`: The system that was integrated.
- `config::Common.AbstractConfig`: The integration configuration used.

# Returns
- The packaged flow solution (type varies by concrete integrator).

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`AbstractIntegrator`](@ref), [`(integrator)(prob)`](@ref).
"""
function (integrator::AbstractIntegrator)(ode_sol, sys::Systems.AbstractSystem, config::Common.AbstractConfig)
    throw(Exceptions.NotImplemented(
        "AbstractIntegrator solution building not implemented";
        required_method = "(integrator::$(typeof(integrator)))(ode_sol, sys::Systems.AbstractSystem, config::Common.AbstractConfig)",
        suggestion = "Implement (i::YourIntegrator)(ode_sol, sys, config) returning a flow solution.",
        context = "AbstractIntegrator solution building - required method implementation",
    ))
end
