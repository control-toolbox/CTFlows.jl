"""
$(TYPEDSIGNATURES)

Solve an ODE problem using a flow.

This performs the integration and builds the solution.

# Arguments
- `flow::Flows.AbstractFlow`: The flow to solve.
- `config::Common.AbstractConfig`: The integration configuration (e.g., `PointConfig`, `TrajectoryConfig`).
- `kwargs`: Additional keyword arguments (e.g., `variable` for NonFixed systems).

# Returns
- The packaged solution (type varies by config type).

# Example
\`\`\`julia-repl
julia> using CTFlows.Pipelines, CTFlows.Common

julia> config = Common.TrajectoryConfig((0.0, 1.0), [1.0, 0.0])
TrajectoryConfig(...)

julia> sol = solve(flow, config)
...
\`\`\`

See also: [`Flows.AbstractFlow`](@ref), [`Systems.build_solution`](@ref).
"""
function solve(flow::Flows.AbstractFlow, config::Common.AbstractConfig; kwargs...)
    prob = Systems.ode_problem(Flows.system(flow), config; kwargs...)
    raw = Flows.integrator(flow)(prob)
    return Systems.build_solution(Flows.system(flow), raw, flow, config)
end
