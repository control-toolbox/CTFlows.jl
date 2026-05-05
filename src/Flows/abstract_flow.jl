"""
$(TYPEDEF)

Abstract type for all flows in CTFlows.

An `AbstractFlow` is a callable object that combines an `AbstractSystem` with an
`AbstractIntegrator`. It carries no business logic of its own — its job is
to expose the integration protocol.

# Interface Requirements

All subtypes must implement:
- `system(flow::AbstractFlow)`: Return the associated `AbstractSystem`.
- `integrator(flow::AbstractFlow)`: Return the associated `AbstractIntegrator`.

# Traits

All `AbstractFlow` subtypes automatically support time-dependence and variable-dependence
trait queries encoded in their type parameters:
- `time_dependence(flow)`: Returns the time-dependence trait type.
- `variable_dependence(flow)`: Returns the variable-dependence trait type.
- `is_autonomous(flow)`, `is_nonautonomous(flow)`: Time-dependence predicates.
- `is_variable(flow)`, `is_nonvariable(flow)`, `has_variable(flow)`: Variable-dependence predicates.

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows

julia> MyFlow <: Flows.AbstractFlow
true
\`\`\`

See also: [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Systems.AbstractSystem`](@ref), [`CTFlows.Integrators.AbstractIntegrator`](@ref).
"""
abstract type AbstractFlow{TD<:Common.TimeDependence, VD<:Common.VariableDependence} end

"""
$(TYPEDEF)

Abstract type for state flows.

Subtype of `AbstractFlow` specialized for state systems (not Hamiltonian systems).
Carries the system type parameter `S` which must be an `AbstractStateSystem`.

# Type Parameters
- `TD <: TimeDependence`: Time dependence trait (Autonomous or NonAutonomous)
- `VD <: VariableDependence`: Variable dependence trait (Fixed or NonFixed)
- `S <: AbstractStateSystem{TD, VD}`: The state system type

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows

julia> MyStateFlow <: Flows.AbstractStateFlow
true
\`\`\`

See also: [`CTFlows.Flows.AbstractFlow`](@ref), [`CTFlows.Flows.AbstractHamiltonianFlow`](@ref), [`CTFlows.Systems.AbstractStateSystem`](@ref).
"""
abstract type AbstractStateFlow{TD, VD, S<:Systems.AbstractStateSystem{TD,VD}} <: AbstractFlow{TD, VD} end

"""
$(TYPEDEF)

Abstract type for Hamiltonian flows.

Subtype of `AbstractFlow` specialized for Hamiltonian systems.
Carries the system type parameter `S` which must be an `AbstractHamiltonianSystem`.

# Type Parameters
- `TD <: TimeDependence`: Time dependence trait (Autonomous or NonAutonomous)
- `VD <: VariableDependence`: Variable dependence trait (Fixed or NonFixed)
- `S <: AbstractHamiltonianSystem{TD, VD}`: The Hamiltonian system type

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows

julia> MyHamiltonianFlow <: Flows.AbstractHamiltonianFlow
true
\`\`\`

See also: [`CTFlows.Flows.AbstractFlow`](@ref), [`CTFlows.Flows.AbstractStateFlow`](@ref), [`CTFlows.Systems.AbstractHamiltonianSystem`](@ref).
"""
abstract type AbstractHamiltonianFlow{TD, VD, S<:Systems.AbstractHamiltonianSystem{TD,VD}} <: AbstractFlow{TD, VD} end

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

Extract the time dependence trait from an `AbstractFlow`.

# Returns
- `Type{<:TimeDependence}`: The time dependence trait type (Autonomous or NonAutonomous).

# Example
\`\`\`julia
using CTFlows.Flows
using CTFlows.Common

struct MyFlow <: Flows.AbstractFlow{Common.Autonomous, Common.Fixed}
    data::Vector{Float64}
end

Common.time_dependence(MyFlow)  # Returns Autonomous
\`\`\`

See also: [`CTFlows.Common.has_time_dependence_trait`](@ref), [`CTFlows.Common.is_autonomous`](@ref), [`CTFlows.Flows.AbstractFlow`](@ref).
"""
function Common.time_dependence(flow::AbstractFlow{TD, <:VariableDependence}) where {TD <: TimeDependence}
    return TD
end

"""
$(TYPEDSIGNATURES)

Extract the variable dependence trait from an `AbstractFlow`.

# Returns
- `Type{<:VariableDependence}`: The variable dependence trait type (Fixed or NonFixed).

# Example
\`\`\`julia
using CTFlows.Flows
using CTFlows.Common

struct MyFlow <: Flows.AbstractFlow{Common.Autonomous, Common.Fixed}
    data::Vector{Float64}
end

Common.variable_dependence(MyFlow)  # Returns Fixed
\`\`\`

See also: [`CTFlows.Common.has_variable_dependence_trait`](@ref), [`CTFlows.Common.is_variable`](@ref), [`CTFlows.Flows.AbstractFlow`](@ref).
"""
function Common.variable_dependence(flow::AbstractFlow{<:TimeDependence, VD}) where {VD <: VariableDependence}
    return VD
end

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

Return the associated `AbstractIntegrator` for the flow.

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`CTFlows.Flows.AbstractFlow`](@ref), [`CTFlows.Integrators.AbstractIntegrator`](@ref).
"""
function integrator(flow::AbstractFlow)
    throw(Exceptions.NotImplemented(
        "AbstractFlow integrator method not implemented";
        required_method = "integrator(flow::$(typeof(flow)))",
        suggestion = "Return the AbstractIntegrator associated with this flow.",
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
    print(io, nameof(typeof(flow)))
    sys = system(flow)
    integ = integrator(flow)
    print(io, "\n  system: ", sys)
    print(io, "\n  integrator: ", nameof(typeof(integ)))
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
    print(io, nameof(typeof(flow)), "(")
    parts = String[]
    push!(parts, "system=$(sys)")
    push!(parts, "integrator=$(nameof(typeof(integ)))")
    print(io, join(parts, ", "))
    print(io, ")")
end
