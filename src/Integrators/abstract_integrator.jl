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

All subtypes must implement three named functions:

- `build_problem(integrator::AbstractIntegrator, system::CTFlows.Systems.AbstractSystem, config::CTFlows.Common.AbstractConfig; variable)`: Build the ODE problem representation from a system and configuration.
- `build_options(integrator::AbstractIntegrator, config::Union{CTFlows.Common.AbstractConfig, Nothing})`: Build solver options dict for the given configuration.
- `solve_problem(integrator::AbstractIntegrator, prob, options::Dict{Symbol,Any})`: Solve the given ODE problem with resolved options (tspan is embedded in `prob`).

Additionally, for multi-phase trajectory support, subtypes should implement:

- `merge(segments::AbstractVector{<:CTFlows.Integrators.AbstractIntegrationResult})`: Merge a sequence of integration results into a single result (used for concatenating multi-phase trajectories).

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

Solve the given ODE problem with resolved options.

# Arguments
- `integrator::AbstractIntegrator`: The integrator strategy.
- `prob`: The ODE problem to solve (type varies by concrete integrator; tspan is embedded).
- `options::Dict{Symbol,Any}`: Resolved solver options (typically from `build_options`).
- `unsafe=Common.__unsafe()`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The ODE integration result, as a subtype of `CTFlows.Integrators.AbstractIntegrationResult`.

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`CTFlows.Integrators.AbstractIntegrator`](@ref), [`CTFlows.Integrators.build_problem`](@ref), [`CTFlows.Integrators.build_options`](@ref).
"""
function solve_problem(integrator::AbstractIntegrator, prob, options::Dict{Symbol,<:Any}; unsafe=Common.__unsafe())
    throw(Exceptions.NotImplemented(
        "AbstractIntegrator solve_problem not implemented";
        required_method = "solve_problem(integrator::$(typeof(integrator)), prob, options::Dict{Symbol,Any}; unsafe=false)",
        suggestion = "Implement solve_problem(i::YourIntegrator, prob, options::Dict; unsafe=false) returning an AbstractIntegrationResult.",
        context = "AbstractIntegrator solve_problem - required method implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Build solver options dict for the given configuration.

# Arguments
- `integrator::AbstractIntegrator`: The integrator strategy.
- `config::Union{CTFlows.Common.AbstractConfig, Nothing}`: The integration configuration (or `Nothing` for fallback).

# Returns
- `Dict{Symbol,Any}`: Resolved solver options for the given configuration.

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`CTFlows.Integrators.AbstractIntegrator`](@ref), [`CTFlows.Integrators.build_problem`](@ref), [`CTFlows.Integrators.solve_problem`](@ref).
"""
function build_options(integrator::AbstractIntegrator, config::Union{Common.AbstractConfig, Nothing})
    throw(Exceptions.NotImplemented(
        "AbstractIntegrator build_options not implemented";
        required_method = "build_options(integrator::$(typeof(integrator)), config::Union{Common.AbstractConfig, Nothing})",
        suggestion = "Implement build_options(i::YourIntegrator, config) returning a Dict{Symbol,Any} of resolved solver options.",
        context = "AbstractIntegrator build_options - required method implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Merge a sequence of integration results into a single result.

This is used for concatenating multi-phase trajectories. Concrete integrator types
should implement this method for their specific result types.

# Arguments
- `segments::AbstractVector{T}`: Sequence of integration results to merge, where `T<:Integrators.AbstractIntegrationResult`.

# Returns
- A single `AbstractIntegrationResult` representing the merged trajectory.

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`CTFlows.Integrators.AbstractIntegrator`](@ref), [`CTFlows.Integrators.AbstractIntegrationResult`](@ref).
"""
function merge(segments::AbstractVector{T}) where {T<:Integrators.AbstractIntegrationResult}
    throw(Exceptions.NotImplemented(
        "AbstractIntegrator merge not implemented";
        required_method = "merge(segments::Vector{<:$(T)})",
        suggestion = "Implement merge(segments::Vector{<:YourIntegrationResult}) returning a merged YourIntegrationResult.",
        context = "AbstractIntegrator merge - required method implementation for multi-phase trajectories",
    ))
end
