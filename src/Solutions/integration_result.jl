"""
    integration_result.jl

Provides the `AbstractIntegrationResult` abstraction for ODE integration output.
"""

"""
$(TYPEDEF)

Abstract supertype for integration results produced by integrators.

This abstraction decouples the `Solutions` layer from the concrete types of the underlying
ODE solvers (e.g. SciML). Integrators must produce a subtype of `AbstractIntegrationResult`
which provides semantic accessors.

# Interface Requirements

Subtypes must implement:
- `final_state(r::SubType)`: Return the final state vector.
- `times(r::SubType)`: Return the vector of time points.
- `evaluate_at(r::SubType, t::Real)`: Evaluate the continuous solution at time `t`.

See also: [`CTFlows.Solutions.final_state`](@ref), [`CTFlows.Solutions.times`](@ref), [`CTFlows.Solutions.evaluate_at`](@ref).
"""
abstract type AbstractIntegrationResult end

"""
$(TYPEDSIGNATURES)

Return the final state vector from the integration result.

# Arguments
- `r::AbstractIntegrationResult`: The integration result.

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`CTFlows.Solutions.AbstractIntegrationResult`](@ref), [`CTFlows.Solutions.times`](@ref), [`CTFlows.Solutions.evaluate_at`](@ref).
"""
function final_state(r::AbstractIntegrationResult)
    throw(Exceptions.NotImplemented(
        "final_state not implemented";
        required_method = "final_state(r::$(typeof(r)))",
        suggestion = "Implement final_state(r) for your integration result type.",
        context = "AbstractIntegrationResult - final_state implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Return the vector of time points from the integration result.

# Arguments
- `r::AbstractIntegrationResult`: The integration result.

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`CTFlows.Solutions.AbstractIntegrationResult`](@ref), [`CTFlows.Solutions.final_state`](@ref), [`CTFlows.Solutions.evaluate_at`](@ref).
"""
function times(r::AbstractIntegrationResult)
    throw(Exceptions.NotImplemented(
        "times not implemented";
        required_method = "times(r::$(typeof(r)))",
        suggestion = "Implement times(r) for your integration result type.",
        context = "AbstractIntegrationResult - times implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Evaluate the integration result at a specific time `t`.

# Arguments
- `r::AbstractIntegrationResult`: The integration result.
- `t::Real`: The time at which to evaluate the solution.

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`CTFlows.Solutions.AbstractIntegrationResult`](@ref), [`CTFlows.Solutions.final_state`](@ref), [`CTFlows.Solutions.times`](@ref).
"""
function evaluate_at(r::AbstractIntegrationResult, t::Real)
    throw(Exceptions.NotImplemented(
        "evaluate_at not implemented";
        required_method = "evaluate_at(r::$(typeof(r)), t::Real)",
        suggestion = "Implement evaluate_at(r, t) for your integration result type.",
        context = "AbstractIntegrationResult - evaluate_at implementation",
    ))
end
