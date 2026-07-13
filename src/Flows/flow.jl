"""
$(TYPEDEF)

Concrete flow combining an `AbstractSystem` with an `AbstractIntegrator`.

The dynamics axis is encoded in the type parameter `D`:
- `D = StateDynamics` → state flow (access via `StateFlow` alias)
- `D = HamiltonianDynamics` → Hamiltonian flow (access via `HamiltonianFlow` alias)

# Type Parameters
- `TD <: TimeDependence`: Time dependence trait (Autonomous or NonAutonomous)
- `VD <: VariableDependence`: Variable dependence trait (Fixed or NonFixed)
- `D <: AbstractDynamicsTrait`: Dynamics trait (`StateDynamics` or `HamiltonianDynamics`)
- `S <: AbstractSystem{TD, VD, D}`: The system type
- `I <: AbstractIntegrator`: The integrator type

# Fields
- `system::S`: The system to integrate
- `integrator::I`: The integrator to use for integration

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows, CTFlows.Systems, CTFlows.Integrators

julia> system = VectorFieldSystem(VectorField(x -> -x))

julia> integrator = SciML()

julia> flow = StateFlow(system, integrator)
StateFlow{...}
\`\`\`

See also: [`CTFlows.Flows.AbstractFlow`](@ref), [`CTFlows.Flows.StateFlow`](@ref), [`CTFlows.Flows.HamiltonianFlow`](@ref).
"""
struct Flow{
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    D<:Traits.AbstractDynamicsTrait,
    S<:Systems.AbstractSystem{TD,VD,D},
    I<:Integrators.AbstractIntegrator,
} <: AbstractFlow{TD,VD,D}
    system::S
    integrator::I
end

"""
$(TYPEDEF)

Alias for state flows: `Flow{TD, VD, StateDynamics, S, I}`.

See also: [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Flows.HamiltonianFlow`](@ref).
"""
const StateFlow{TD<:Traits.TimeDependence,VD<:Traits.VariableDependence,S<:Systems.AbstractSystem{TD,VD,Traits.StateDynamics},I<:Integrators.AbstractIntegrator} = Flow{
    TD,VD,Traits.StateDynamics,S,I
}

function StateFlow(
    system::S, integrator::I
) where {TD,VD,S<:Systems.AbstractStateSystem{TD,VD},I<:Integrators.AbstractIntegrator}
    return Flow{TD,VD,Traits.StateDynamics,S,I}(system, integrator)
end

"""
$(TYPEDEF)

Alias for Hamiltonian flows: `Flow{TD, VD, HamiltonianDynamics, S, I}`.

See also: [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Flows.StateFlow`](@ref).
"""
const HamiltonianFlow{TD<:Traits.TimeDependence,VD<:Traits.VariableDependence,S<:Systems.AbstractSystem{TD,VD,Traits.HamiltonianDynamics},I<:Integrators.AbstractIntegrator} = Flow{
    TD,VD,Traits.HamiltonianDynamics,S,I
}

function HamiltonianFlow(
    system::S, integrator::I
) where {
    TD,VD,S<:Systems.AbstractHamiltonianSystem{TD,VD},I<:Integrators.AbstractIntegrator
}
    return Flow{TD,VD,Traits.HamiltonianDynamics,S,I}(system, integrator)
end

"""
$(TYPEDSIGNATURES)

Build a `Flow` from a system and an integrator.

See also: [`CTFlows.Flows.Flow`](@ref).
"""
function build_flow(
    system::S, integrator::I
) where {S<:Systems.AbstractSystem,I<:Integrators.AbstractIntegrator}
    return Flow(system, integrator)
end

"""
$(TYPEDSIGNATURES)

Return the system associated with a `Flow`.

See also: [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Flows.integrator`](@ref).
"""
function system(
    f::Flow{TD,VD,D,S,I}
)::S where {
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    D<:Traits.AbstractDynamicsTrait,
    S<:Systems.AbstractSystem{TD,VD,D},
    I<:Integrators.AbstractIntegrator,
}
    return f.system
end

"""
$(TYPEDSIGNATURES)

Return the integrator associated with a `Flow`.

See also: [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Flows.system`](@ref).
"""
function integrator(
    f::Flow{TD,VD,D,S,I}
)::I where {
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    D<:Traits.AbstractDynamicsTrait,
    S<:Systems.AbstractSystem{TD,VD,D},
    I<:Integrators.AbstractIntegrator,
}
    return f.integrator
end

# ==============================================================================
# hamiltonian_vector_field getter — Flow-level delegation
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Get the Hamiltonian vector field from a HamiltonianFlow with an AD-backed system.

Delegates to the system-level getter. The `inplace` parameter controls whether
the returned closure writes results in-place.

See also: [`CTFlows.Flows.HamiltonianFlow`](@ref), [`CTFlows.Systems.HamiltonianSystem`](@ref), [`CTFlows.Systems.hamiltonian_vector_field`](@ref)
"""
function Systems.hamiltonian_vector_field(
    flow::HamiltonianFlow{
        TD,VD,<:Systems.HamiltonianSystem{TD,VD},<:Integrators.AbstractIntegrator
    };
    inplace::Bool=Systems.__hvf_inplace(),
) where {TD<:Traits.TimeDependence,VD<:Traits.VariableDependence}
    return Systems.hamiltonian_vector_field(flow.system; inplace=inplace)
end

"""
$(TYPEDSIGNATURES)

Get the Hamiltonian vector field from a HamiltonianFlow with an HVF-backed system.

Returns the pre-stored vector field from the `HamiltonianVectorFieldSystem` without
any recomputation.

See also: [`CTFlows.Flows.HamiltonianFlow`](@ref), [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref), [`CTFlows.Systems.hamiltonian_vector_field`](@ref)
"""
function Systems.hamiltonian_vector_field(
    flow::HamiltonianFlow{
        TD,
        VD,
        <:Systems.HamiltonianVectorFieldSystem{<:Function,TD,VD},
        <:Integrators.AbstractIntegrator,
    },
) where {TD<:Traits.TimeDependence,VD<:Traits.VariableDependence}
    return Systems.hamiltonian_vector_field(flow.system)
end
