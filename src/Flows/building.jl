"""
$(TYPEDSIGNATURES)

High-level constructor for `Flow` from vector field data.

This constructor builds a complete flow by:
1. Building a `VectorFieldSystem` from the vector field data
2. Building a `SciML` integrator with the given options
3. Routing options through the integrator's CTSolvers strategy
4. Combining them into a callable `Flow`

# Arguments
- `data::CTFlows.Data.VectorField`: The vector field defining the system dynamics.
- `opts...`: Keyword options passed to the integrator's strategy.

# Returns
- `CTFlows.Flows.Flow`: The complete flow ready for integration.

# Example
\`\`\`julia
using CTFlows.Data, CTFlows.Flows, CTFlows.Common

vf = Data.VectorField((t, x, v) -> x, Common.Autonomous(), Common.Fixed())
flow = Flows.Flow(vf; reltol=1e-8)
\`\`\`

See also: [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Systems.build_system`](@ref), [`CTFlows.Integrators.build_integrator`](@ref).
"""
function Flow(data::Data.VectorField; opts...)
    system = Systems.build_system(data)
    integrator = Integrators.build_integrator(; opts...)
    return build_flow(system, integrator)
end

"""
$(TYPEDSIGNATURES)

High-level constructor for `HamiltonianFlow` from Hamiltonian vector field data.

This constructor builds a complete Hamiltonian flow by:
1. Building a `HamiltonianVectorFieldSystem` from the Hamiltonian vector field data
2. Building a `SciML` integrator with the given options
3. Routing options through the integrator's CTSolvers strategy
4. Combining them into a callable `HamiltonianFlow`

# Arguments
- `data::CTFlows.Data.HamiltonianVectorField`: The Hamiltonian vector field defining the system dynamics.
- `state_dimension::Union{Int, Nothing}`: The state dimension (number of state variables, not including costates). Defaults to `nothing`.
- `opts...`: Keyword options passed to the integrator's strategy.

# Returns
- `CTFlows.Flows.HamiltonianFlow`: The complete Hamiltonian flow ready for integration.

# Example
```julia
using CTFlows.Data, CTFlows.Flows, CTFlows.Common

hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); autonomous=true, variable=false)
flow = Flows.Flow(hvf; reltol=1e-8)
flow_with_dim = Flows.Flow(hvf; state_dimension=3, reltol=1e-8)
```

See also: [`CTFlows.Flows.HamiltonianFlow`](@ref), [`CTFlows.Systems.build_system`](@ref), [`CTFlows.Integrators.build_integrator`](@ref).
"""
function Flow(data::Data.HamiltonianVectorField; state_dimension::Union{Int, Nothing}=Common.__state_dimension(), opts...)
    system = Systems.build_system(data; state_dimension=state_dimension)
    integrator = Integrators.build_integrator(; opts...)
    return build_flow(system, integrator)
end

