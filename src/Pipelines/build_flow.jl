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

# Example
\`\`\`julia-repl
julia> using CTFlows.Pipelines, CTFlows.Data, CTFlows.Systems, CTFlows.Integrators

julia> vf = Data.VectorField((t, x, v) -> x, Common.Autonomous(), Common.Fixed())
VectorField(...)

julia> system = build_system(vf)
VectorFieldSystem(...)

julia> integrator = Integrators.SciMLIntegrator()
SciMLIntegrator(...)

julia> flow = build_flow(system, integrator)
Flow(system=..., integrator=...)
\`\`\`

See also: [`Flows.Flow`](@ref), [`build_system`](@ref), [`Flow`](@ref).
"""
function build_flow(system::Systems.AbstractSystem, integrator::Integrators.AbstractODEIntegrator)
    return Flows.Flow(system, integrator)
end
