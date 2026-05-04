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

All subtypes must implement two named functions:

- `build_problem(integrator::AbstractIntegrator, system::CTFlows.Systems.AbstractSystem, config::CTFlows.Common.AbstractConfig; variable)`: Build the ODE problem representation from a system and configuration.
- `solve_problem(integrator::AbstractIntegrator, prob)`: Solve the given ODE problem (tspan is embedded in `prob`).

# Throws
- `CTBase.Exceptions.NotImplemented`: If the methods are not implemented by the concrete type.

See also: [`CTFlows.Flows.AbstractFlow`](@ref).
"""
abstract type AbstractIntegrator <: CTSolvers.Strategies.AbstractStrategy end

"""
$(TYPEDSIGNATURES)

Build the ODE problem representation from a system and configuration.

# Arguments
- `integrator::AbstractIntegrator`: The integrator strategy.
- `system::CTFlows.Systems.AbstractSystem`: The system to build a problem for.
- `config::CTFlows.Common.AbstractConfig`: The integration configuration.
- `variable`: The variable parameter value (required for NonFixed systems).

# Returns
- The ODE problem representation (type varies by concrete integrator).

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`CTFlows.Integrators.AbstractIntegrator`](@ref), [`CTFlows.Integrators.solve_problem`](@ref).
"""
function build_problem(integrator::AbstractIntegrator, system::Systems.AbstractSystem, config::Common.AbstractConfig; variable)
    throw(Exceptions.NotImplemented(
        "AbstractIntegrator problem building not implemented";
        required_method = "build_problem(integrator::$(typeof(integrator)), system::Systems.AbstractSystem, config::Common.AbstractConfig; variable)",
        suggestion = "Implement build_problem(i::YourIntegrator, system, config; variable) returning an ODE problem representation.",
        context = "AbstractIntegrator problem building - required method implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Solve the given ODE problem.

# Arguments
- `integrator::AbstractIntegrator`: The integrator strategy.
- `prob`: The ODE problem to solve (type varies by concrete integrator; tspan is embedded).
- `unsafe=Common.__unsafe()`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The ODE integration result, as a subtype of `CTFlows.Solutions.AbstractIntegrationResult`.

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`CTFlows.Integrators.AbstractIntegrator`](@ref), [`CTFlows.Integrators.build_problem`](@ref).
"""
function solve_problem(integrator::AbstractIntegrator, prob; unsafe=Common.__unsafe())
    throw(Exceptions.NotImplemented(
        "AbstractIntegrator solve_problem not implemented";
        required_method = "solve_problem(integrator::$(typeof(integrator)), prob; unsafe=false)",
        suggestion = "Implement solve_problem(i::YourIntegrator, prob; unsafe=false) returning an AbstractIntegrationResult.",
        context = "AbstractIntegrator solve_problem - required method implementation",
    ))
end
