"""
$(TYPEDEF)

Concrete flow for state systems (non-Hamiltonian).

Combines a state system with an integrator for integration. The type parameters
encode the time-dependence and variable-dependence traits for compile-time dispatch.

# Type Parameters
- `TD <: TimeDependence`: Time dependence trait (Autonomous or NonAutonomous)
- `VD <: VariableDependence`: Variable dependence trait (Fixed or NonFixed)
- `S <: AbstractStateSystem{TD, VD}`: The state system type
- `I <: AbstractIntegrator`: The integrator type

# Fields
- `system::S`: The state system to integrate
- `integrator::I`: The integrator to use for integration

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows, CTFlows.Systems, CTFlows.Integrators

julia> system = VectorFieldSystem(VectorField(x -> -x))

julia> integrator = SciML()

julia> flow = StateFlow(system, integrator)
StateFlow{...}
\`\`\`

See also: [`CTFlows.Flows.AbstractStateFlow`](@ref), [`CTFlows.Flows.HamiltonianFlow`](@ref).
"""
struct StateFlow{TD, VD, S<:Systems.AbstractStateSystem{TD, VD}, I<:Integrators.AbstractIntegrator} <: AbstractStateFlow{TD, VD, S}
    system::S
    integrator::I
end

"""
$(TYPEDEF)

Concrete flow for Hamiltonian systems.

Combines a Hamiltonian system with an integrator for integration. The type parameters
encode the time-dependence and variable-dependence traits for compile-time dispatch.

# Type Parameters
- `TD <: TimeDependence`: Time dependence trait (Autonomous or NonAutonomous)
- `VD <: VariableDependence`: Variable dependence trait (Fixed or NonFixed)
- `S <: AbstractHamiltonianSystem{TD, VD}`: The Hamiltonian system type
- `I <: AbstractIntegrator`: The integrator type

# Fields
- `system::S`: The Hamiltonian system to integrate
- `integrator::I`: The integrator to use for integration

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows, CTFlows.Systems, CTFlows.Integrators

julia> system = HamiltonianVectorFieldSystem(VectorField(x -> -x), VectorField(p -> -p))

julia> integrator = SciML()

julia> flow = HamiltonianFlow(system, integrator)
HamiltonianFlow{...}
\`\`\`

See also: [`CTFlows.Flows.AbstractHamiltonianFlow`](@ref), [`CTFlows.Flows.StateFlow`](@ref).
"""
struct HamiltonianFlow{TD, VD, S<:Systems.AbstractHamiltonianSystem{TD, VD}, I<:Integrators.AbstractIntegrator} <: AbstractHamiltonianFlow{TD, VD, S}
    system::S
    integrator::I
end

"""
$(TYPEDSIGNATURES)

Build a `StateFlow` from a state system and an integrator.

# Arguments
- `system::S`: The state system to integrate.
- `integrator::I`: The integrator to use for integration.

# Returns
- `StateFlow`: A concrete state flow combining the system and integrator.

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows, CTFlows.Systems, CTFlows.Integrators

julia> system = VectorFieldSystem(VectorField(x -> -x))

julia> integrator = SciML()

julia> flow = build_flow(system, integrator)
StateFlow{...}
\`\`\`

See also: [`CTFlows.Flows.StateFlow`](@ref), [`CTFlows.Flows.build_flow(::AbstractHamiltonianSystem, ::AbstractIntegrator)`](@ref).
"""
function build_flow(system::S, integrator::I) where {S<:Systems.AbstractStateSystem, I<:Integrators.AbstractIntegrator}
    return StateFlow(system, integrator)
end

"""
$(TYPEDSIGNATURES)

Build a `HamiltonianFlow` from a Hamiltonian system and an integrator.

# Arguments
- `system::S`: The Hamiltonian system to integrate.
- `integrator::I`: The integrator to use for integration.

# Returns
- `HamiltonianFlow`: A concrete Hamiltonian flow combining the system and integrator.

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows, CTFlows.Systems, CTFlows.Integrators

julia> system = HamiltonianVectorFieldSystem(VectorField(x -> -x), VectorField(p -> -p))

julia> integrator = SciML()

julia> flow = build_flow(system, integrator)
HamiltonianFlow{...}
\`\`\`

See also: [`CTFlows.Flows.HamiltonianFlow`](@ref), [`CTFlows.Flows.build_flow(::AbstractStateSystem, ::AbstractIntegrator)`](@ref).
"""
function build_flow(system::S, integrator::I) where {S<:Systems.AbstractHamiltonianSystem, I<:Integrators.AbstractIntegrator}
    return HamiltonianFlow(system, integrator)
end

"""
$(TYPEDSIGNATURES)

Return the system associated with a `StateFlow`.

# Arguments
- `f::StateFlow`: The state flow.

# Returns
- `S`: The state system stored in the flow.

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows

julia> flow = StateFlow(system, integrator)

julia> system(flow) === system
true
\`\`\`

See also: [`CTFlows.Flows.StateFlow`](@ref), [`CTFlows.Flows.integrator`](@ref).
"""
function system(f::StateFlow{TD, VD, S, I})::S where {TD, VD, S, I}
    return f.system
end

"""
$(TYPEDSIGNATURES)

Return the system associated with a `HamiltonianFlow`.

# Arguments
- `f::HamiltonianFlow`: The Hamiltonian flow.

# Returns
- `S`: The Hamiltonian system stored in the flow.

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows

julia> flow = HamiltonianFlow(system, integrator)

julia> system(flow) === system
true
\`\`\`

See also: [`CTFlows.Flows.HamiltonianFlow`](@ref), [`CTFlows.Flows.integrator`](@ref).
"""
function system(f::HamiltonianFlow{TD, VD, S, I})::S where {TD, VD, S, I}
    return f.system
end

"""
$(TYPEDSIGNATURES)

Return the integrator associated with a `StateFlow`.

# Arguments
- `f::StateFlow`: The state flow.

# Returns
- `I`: The integrator stored in the flow.

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows

julia> flow = StateFlow(system, integrator)

julia> integrator(flow) === integrator
true
\`\`\`

See also: [`CTFlows.Flows.StateFlow`](@ref), [`CTFlows.Flows.system`](@ref).
"""
function integrator(f::StateFlow{TD, VD, S, I})::I where {TD, VD, S, I}
    return f.integrator
end

"""
$(TYPEDSIGNATURES)

Return the integrator associated with a `HamiltonianFlow`.

# Arguments
- `f::HamiltonianFlow`: The Hamiltonian flow.

# Returns
- `I`: The integrator stored in the flow.

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows

julia> flow = HamiltonianFlow(system, integrator)

julia> integrator(flow) === integrator
true
\`\`\`

See also: [`CTFlows.Flows.HamiltonianFlow`](@ref), [`CTFlows.Flows.system`](@ref).
"""
function integrator(f::HamiltonianFlow{TD, VD, S, I})::I where {TD, VD, S, I}
    return f.integrator
end
