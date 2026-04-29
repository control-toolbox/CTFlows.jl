"""
$(TYPEDSIGNATURES)

Solve an ODE problem using a system and an integrator.

This is a convenience method that builds a flow from the system and integrator,
then delegates to `solve(flow, config)`.

# Arguments
- `system::AbstractSystem`: The system to integrate.
- `config`: The integration configuration (`PointConfig` or `TrajectoryConfig`).
- `integrator::Integrators.AbstractODEIntegrator`: The integrator to use.
- `kwargs`: Additional keyword arguments (e.g., `variable` for NonFixed systems).

# Returns
- The packaged solution (type varies by config type).

# Example
\`\`\`julia-repl
julia> using CTFlows.Pipelines, CTFlows.Systems, CTFlows.Integrators

julia> config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
PointConfig(...)

julia> integrator = Integrators.SciMLIntegrator()
SciMLIntegrator(...)

julia> sol = solve(system, config, integrator)
...
\`\`\`

See also: [`solve(flow, config)`](@ref), [`solve(vf, config, integrator)`](@ref), [`build_flow`](@ref).
"""
function solve(
    system::Systems.AbstractSystem,
    config,
    integrator::Integrators.AbstractODEIntegrator;
    kwargs...,
)
    flow = build_flow(system, integrator)
    return solve(flow, config; kwargs...)
end
