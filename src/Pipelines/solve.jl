"""
$(TYPEDSIGNATURES)

Solve an ODE problem using a flow.

This is an alias for `integrate` — the Flow callable already builds solutions
internally, so `solve` is provided for convenience and semantic clarity.

# Arguments
- `flow::Flows.AbstractFlow`: The flow to solve.
- `config`: The integration configuration (`PointConfig` or `TrajectoryConfig`).

# Returns
- The packaged solution (type varies by flow implementation).

# Example
\`\`\`julia-repl
julia> using CTFlows.Pipelines, CTFlows.Core

julia> config = Core.TrajectoryConfig((0.0, 1.0), [1.0, 0.0])
TrajectoryConfig(...)

julia> sol = solve(flow, config)
...
\`\`\`

See also: [`integrate`](@ref), [`Flows.AbstractFlow`](@ref).
"""
function solve(flow::Flows.AbstractFlow, config)
    return integrate(flow, config)
end
