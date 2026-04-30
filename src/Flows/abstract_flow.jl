"""
$(TYPEDEF)

Abstract type for all flows in CTFlows.

An `AbstractFlow` is a callable object that combines an `AbstractSystem` with an
`AbstractODEIntegrator`. It carries no business logic of its own — its job is
to expose the integration protocol and delegate trait queries to its system.

# Interface Requirements

All subtypes must implement:
- `system(flow::AbstractFlow)`: Return the associated `AbstractSystem`.
- `integrator(flow::AbstractFlow)`: Return the associated `AbstractODEIntegrator`.

# Traits

All `AbstractFlow` subtypes automatically support time-dependence and variable-dependence
trait queries by delegating to their associated system:
- `time_dependence(flow)`: Returns the time-dependence trait of the system.
- `variable_dependence(flow)`: Returns the variable-dependence trait of the system.
- `is_autonomous(flow)`, `is_nonautonomous(flow)`: Time-dependence predicates.
- `is_variable(flow)`, `is_nonvariable(flow)`, `has_variable(flow)`: Variable-dependence predicates.

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows

julia> MyFlow <: Flows.AbstractFlow
true
\`\`\`

See also: [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Systems.AbstractSystem`](@ref), [`CTFlows.Integrators.AbstractODEIntegrator`](@ref).
"""
abstract type AbstractFlow end

"""
$(TYPEDSIGNATURES)

Indicate that `AbstractFlow` has the time-dependence trait.

# Returns
- `Bool`: Always `true` for `AbstractFlow`.

See also: [`CTFlows.Common.TimeDependence`](@ref), [`CTFlows.Common.time_dependence`](@ref).
"""
Common.has_time_dependence_trait(::AbstractFlow) = true

"""
$(TYPEDSIGNATURES)

Indicate that `AbstractFlow` has the variable-dependence trait.

# Returns
- `Bool`: Always `true` for `AbstractFlow`.

See also: [`CTFlows.Common.VariableDependence`](@ref), [`CTFlows.Common.variable_dependence`](@ref).
"""
Common.has_variable_dependence_trait(::AbstractFlow) = true

"""
$(TYPEDSIGNATURES)

Return the time-dependence trait of the flow (delegates to its system).

# Arguments
- `flow::AbstractFlow`: The flow to query.

# Returns
- `CTFlows.Common.Autonomous` or `CTFlows.Common.NonAutonomous`: The time-dependence trait of the associated system.

See also: [`CTFlows.Common.TimeDependence`](@ref), [`CTFlows.Common.variable_dependence`](@ref), [`CTFlows.Flows.system`](@ref).
"""
Common.time_dependence(flow::AbstractFlow) = Common.time_dependence(system(flow))

"""
$(TYPEDSIGNATURES)

Return the variable-dependence trait of the flow (delegates to its system).

# Arguments
- `flow::AbstractFlow`: The flow to query.

# Returns
- `CTFlows.Common.Fixed` or `CTFlows.Common.NonFixed`: The variable-dependence trait of the associated system.

See also: [`CTFlows.Common.VariableDependence`](@ref), [`CTFlows.Common.time_dependence`](@ref), [`CTFlows.Flows.system`](@ref).
"""
Common.variable_dependence(flow::AbstractFlow) = Common.variable_dependence(system(flow))

"""
$(TYPEDSIGNATURES)

Return the associated `AbstractSystem` for the flow.

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`CTFlows.Flows.AbstractFlow`](@ref), [`CTFlows.Systems.AbstractSystem`](@ref).
"""
function system(flow::AbstractFlow)
    throw(Exceptions.NotImplemented(
        "AbstractFlow system method not implemented";
        required_method = "system(flow::$(typeof(flow)))",
        suggestion = "Return the AbstractSystem associated with this flow.",
        context = "AbstractFlow.system - required method implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Return the associated `AbstractODEIntegrator` for the flow.

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`CTFlows.Flows.AbstractFlow`](@ref), [`CTFlows.Integrators.AbstractODEIntegrator`](@ref).
"""
function integrator(flow::AbstractFlow)
    throw(Exceptions.NotImplemented(
        "AbstractFlow integrator method not implemented";
        required_method = "integrator(flow::$(typeof(flow)))",
        suggestion = "Return the AbstractODEIntegrator associated with this flow.",
        context = "AbstractFlow.integrator - required method implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Display the flow in tree-style format.

# Example
```julia-repl
julia> using CTFlows.Flows

julia> flow = Flow(system, integrator)
Flow
  system: FakeSystem(n_x=2, n_p=2)
  integrator: FakeIntegrator
```
"""
function Base.show(io::IO, ::MIME"text/plain", flow::AbstractFlow)
    print(io, typeof(flow).name)
    sys = system(flow)
    integ = integrator(flow)
    print(io, "\n  system: ", sys)
    print(io, "\n  integrator: ", typeof(integ).name)
end

"""
$(TYPEDSIGNATURES)

Compact display of the flow.

# Example
```julia-repl
julia> using CTFlows.Flows

julia> flow = Flow(system, integrator)
Flow(system=FakeSystem(n_x=2, n_p=2), integrator=FakeIntegrator)
```
"""
function Base.show(io::IO, flow::AbstractFlow)
    sys = system(flow)
    integ = integrator(flow)
    print(io, typeof(flow).name, "(")
    parts = String[]
    push!(parts, "system=$(sys)")
    push!(parts, "integrator=$(typeof(integ).name)")
    print(io, join(parts, ", "))
    print(io, ")")
end
