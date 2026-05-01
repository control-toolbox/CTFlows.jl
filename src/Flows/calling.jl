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
\`\`\`julia
# Conceptual usage pattern
flow = Flow(system, integrator)
config = Common.TrajectoryConfig((0.0, 1.0), [1.0, 0.0])
sol = call(flow, config)
\`\`\`

See also: [`CTFlows.Flows.AbstractFlow`](@ref), [`CTFlows.Flows.build_ode_problem`](@ref).
"""
function call(flow::Flows.AbstractFlow{TD, VD}, config::Common.AbstractConfig; variable=nothing) where {TD<:Common.TimeDependence, VD<:Common.VariableDependence}

    # get system and integrator
    sys = system(flow)
    int = integrator(flow)

    # build ode problem
    prob = build_ode_problem(sys, config, int; variable=variable)

    # integrate ode problem
    ode_sol = integrate(prob, int)

    # build flow solution
    flow_sol = build_flow_solution(ode_sol, sys, config, int)

    return flow_sol
end

"""
$(TYPEDSIGNATURES)

Build an ODE problem from a system and configuration using the integrator.

This is an internal helper function that delegates problem construction to the
integrator strategy, allowing each integrator to define its own problem representation.

# Arguments
- `system::Systems.AbstractSystem`: The system to build a problem for.
- `config::Common.AbstractConfig`: The integration configuration.
- `integrator::Integrators.AbstractIntegrator`: The integrator strategy to use.
- `variable`: The variable parameter value (required for NonFixed systems).

# Returns
- The ODE problem representation (type depends on integrator strategy).

See also: [`CTFlows.Flows.call`](@ref), [`CTFlows.Integrators.AbstractIntegrator`](@ref).
"""
function build_ode_problem(system::Systems.AbstractSystem, config::Common.AbstractConfig, integrator::Integrators.AbstractIntegrator; variable)
    return integrator(system, config; variable=variable)
end

"""
$(TYPEDSIGNATURES)

Integrate an ODE problem using the integrator strategy.

This is an internal helper function that delegates integration to the integrator
strategy, allowing each integrator to use its own integration algorithm.

# Arguments
- `prob`: The ODE problem to integrate.
- `integrator::Integrators.AbstractIntegrator`: The integrator strategy to use.

# Returns
- The ODE solution (type depends on integrator strategy).

See also: [`CTFlows.Flows.call`](@ref), [`CTFlows.Flows.build_ode_problem`](@ref).
"""
function integrate(prob, integrator::Integrators.AbstractIntegrator)
    return integrator(prob)
end

"""
$(TYPEDSIGNATURES)

Build a flow solution from an ODE solution using the integrator strategy.

This is an internal helper function that delegates solution packaging to the
integrator strategy, allowing each integrator to define its own solution format.

# Arguments
- `ode_sol`: The ODE solution to package.
- `sys::Systems.AbstractSystem`: The system that was integrated.
- `config::Common.AbstractConfig`: The integration configuration used.
- `integrator::Integrators.AbstractIntegrator`: The integrator strategy to use.

# Returns
- The packaged flow solution (type depends on integrator strategy).

See also: [`CTFlows.Flows.call`](@ref), [`CTFlows.Flows.integrate`](@ref).
"""
function build_flow_solution(ode_sol, sys::Systems.AbstractSystem, config::Common.AbstractConfig, integrator::Integrators.AbstractIntegrator)
    return integrator(ode_sol, sys, config)
end