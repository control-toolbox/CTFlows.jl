"""
$(TYPEDSIGNATURES)

Build a `Flow` from a system and an integrator.

This is the atomic form that directly combines an `AbstractSystem` with an
`AbstractODEIntegrator` into a callable `Flow`.

# Arguments
- `system::Systems.AbstractSystem`: The system to integrate.
- `integrator::Integrators.AbstractODEIntegrator`: The integrator to use.

# Returns
- `Flows.Flow`: The flow combining system and integrator.

See also: [`Flows.Flow`](@ref), [`build_flow(input, modeler, integrator, ad_backend)`](@ref).
"""
function build_flow(system::Systems.AbstractSystem, integrator::Integrators.AbstractODEIntegrator)
    return Flows.Flow(system, integrator)
end

"""
$(TYPEDSIGNATURES)

Build a flow from an input, modeler, integrator, and AD backend.

This is a pipeline alias that combines `build_system` and the atomic `build_flow`.
It first builds a system from the input using the modeler and AD backend, then
wraps it with the integrator into a flow.

# Arguments
- `input`: The input to build a system from.
- `modeler::Modelers.AbstractFlowModeler`: The modeler strategy.
- `integrator::Integrators.AbstractODEIntegrator`: The integrator strategy.
- `ad_backend::ADBackends.AbstractADBackend`: The AD backend.

# Returns
- `Flows.Flow`: The complete flow ready for integration.

See also: [`build_system`](@ref), [`Flows.Flow`](@ref).
"""
function build_flow(input, modeler::Modelers.AbstractFlowModeler, integrator::Integrators.AbstractODEIntegrator, ad_backend::ADBackends.AbstractADBackend)
    system = build_system(input, modeler, ad_backend)
    return build_flow(system, integrator)
end
