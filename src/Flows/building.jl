"""
$(TYPEDSIGNATURES)

High-level constructor for `Flow` from vector field data and integrator identifier.

This constructor builds a complete flow by:
1. Building a `VectorFieldSystem` from the vector field data
2. Building an integrator by identifier (default `:sciml`)
3. Routing options through the integrator's CTSolvers strategy
4. Combining them into a callable `Flow`

# Arguments
- `data::CTFlows.Data.VectorField`: The vector field defining the system dynamics.
- `id::Symbol`: The integrator identifier (default `:sciml`).
- `opts...`: Keyword options passed to the integrator's strategy.

# Returns
- `CTFlows.Flows.Flow`: The complete flow ready for integration.

# Example
\`\`\`julia
using CTFlows.Data, CTFlows.Flows, CTFlows.Common

vf = Data.VectorField((t, x, v) -> x, Common.Autonomous(), Common.Fixed())
flow = Flows.Flow(vf, :sciml; reltol=1e-8)
\`\`\`

See also: [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Systems.build_system`](@ref), [`CTFlows.Integrators.build_integrator`](@ref).
"""
function Flow(data::Data.VectorField, id::Symbol=:sciml; opts...)
    system = Systems.build_system(data)
    integrator = Integrators.build_integrator(id; opts...)
    return Flow(system, integrator)
end
