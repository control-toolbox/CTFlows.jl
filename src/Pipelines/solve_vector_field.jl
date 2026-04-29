"""
$(TYPEDSIGNATURES)

Solve an ODE problem using a vector field and an integrator.

This is a convenience method that builds a system from the vector field,
then delegates to `solve(system, config, integrator)`.

# Arguments
- `vf::Systems.VectorField`: The vector field to integrate.
- `config`: The integration configuration (`PointConfig` or `TrajectoryConfig`).
- `integrator::Integrators.AbstractODEIntegrator`: The integrator to use.
- `kwargs`: Additional keyword arguments (e.g., `variable` for NonFixed systems).

# Returns
- The packaged solution (type varies by config type).

# Example
\`\`\`julia-repl
julia> using CTFlows.Pipelines, CTFlows.Systems, CTFlows.Integrators

julia> vf = Systems.VectorField(x -> -x, Systems.Autonomous, Systems.Fixed)
VectorField(...)

julia> config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
PointConfig(...)

julia> integrator = Integrators.SciMLIntegrator()
SciMLIntegrator(...)

julia> sol = solve(vf, config, integrator)
...
\`\`\`

See also: [`solve(system, config, integrator)`](@ref), [`solve(flow, config)`](@ref), [`build_system`](@ref).
"""
function solve(
    vf::Systems.VectorField,
    config,
    integrator::Integrators.AbstractODEIntegrator;
    kwargs...,
)
    system = build_system(vf)
    return solve(system, config, integrator; kwargs...)
end
