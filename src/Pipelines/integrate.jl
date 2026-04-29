"""
$(TYPEDSIGNATURES)

Integrate a flow using a configuration object.

This is a thin wrapper over the callable protocol of `AbstractFlow`. It is useful
when one wants to spell out the action by name rather than calling the flow directly.

# Arguments
- `flow::Flows.AbstractFlow`: The flow to integrate.
- `config`: The integration configuration (`PointConfig` or `TrajectoryConfig`).
- `kwargs`: Additional keyword arguments (e.g., `variable` for NonFixed systems).

# Returns
- The integrated solution (type varies by flow implementation).

# Example
\`\`\`julia-repl
julia> using CTFlows.Pipelines, CTFlows.Core, CTFlows.Systems

julia> config = Core.PointConfig(0.0, [1.0, 0.0], 1.0)
PointConfig(...)

julia> sol = integrate(flow, config)
...
\`\`\`

See also: [`Flows.AbstractFlow`](@ref), [`solve`](@ref), [`Core.PointConfig`](@ref), [`Core.TrajectoryConfig`](@ref).
"""
function integrate(flow::Flows.AbstractFlow, config; kwargs...)
    return flow(config; kwargs...)
end
