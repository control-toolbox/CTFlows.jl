"""
$(TYPEDSIGNATURES)

Solve an ODE problem using a flow.

This performs the integration and builds the solution.

# Arguments
- `flow::Flows.AbstractFlow`: The flow to solve.
- `config::Common.AbstractConfig`: The integration configuration (e.g., `PointConfig`, `TrajectoryConfig`).
- `variable=nothing`: The variable parameter value (required for NonFixed systems, optional for Fixed systems).

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
function CommonSolve.solve(flow::Flows.AbstractFlow, config::Common.AbstractConfig; variable=nothing, kwargs...)
    prob = Systems.ode_problem(Flows.system(flow), config; variable=variable, kwargs...)
    raw = Flows.integrator(flow)(prob)
    return Systems.build_solution(Flows.system(flow), raw, flow, config)
end
