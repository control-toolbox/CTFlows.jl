"""
$(TYPEDSIGNATURES)

Solve an ODE problem using a flow.

This performs the integration and builds the solution.

# Arguments
- `flow::CTFlows.Flows.AbstractFlow`: The flow to solve.
- `config::CTFlows.Common.AbstractConfig`: The integration configuration (e.g., `PointConfig`, `TrajectoryConfig`).
- `variable=nothing`: The variable parameter value (required for NonFixed systems, optional for Fixed systems).
- `unsafe=Common.__unsafe()`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The packaged solution (type varies by config type).

# Example
\`\`\`julia
# Conceptual usage pattern
flow = Flow(system, integrator)
config = CTFlows.Common.TrajectoryConfig((0.0, 1.0), [1.0, 0.0])
sol = call(flow, config)
\`\`\`

See also: [`CTFlows.Flows.AbstractFlow`](@ref), [`CTFlows.Integrators.build_problem`](@ref), [`CTFlows.Integrators.solve_problem`](@ref), [`CTFlows.Solutions.build_solution`](@ref).
"""
function call(flow::Flows.AbstractFlow{TD, VD}, config::Common.AbstractConfig; variable=nothing, unsafe=Common.__unsafe()) where {TD<:Common.TimeDependence, VD<:Common.VariableDependence}

    # get system and integrator
    sys = system(flow)
    int = integrator(flow)

    # build ode problem
    prob = Integrators.build_problem(int, sys, config; variable=variable)

    # integrate ode problem
    result = Integrators.solve_problem(int, prob; unsafe=unsafe)

    # build flow solution
    flow_sol = Solutions.build_solution(result, sys, config)

    return flow_sol
end