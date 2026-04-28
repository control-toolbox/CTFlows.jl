"""
$(TYPEDSIGNATURES)

Solve an ODE problem using a flow.

This is a two-step pipeline: integrate the flow over the time span, then package
the result using the system's solution builder.

# Arguments
- `flow::Flows.AbstractFlow`: The flow to solve.
- `tspan`: The time span `(t0, tf)` over which to solve.
- `x0`: Initial state.

# Returns
- The packaged solution (type varies by system implementation).

See also: [`integrate`](@ref), [`build_solution`](@ref).
"""
function solve(flow::Flows.AbstractFlow, tspan, x0)
    t0, tf = tspan
    ode_sol = integrate(flow, t0, x0, tf)
    return build_solution(Flows.system(flow), ode_sol)
end

"""
$(TYPEDSIGNATURES)

Solve an ODE problem with initial state and costate using a flow.

This is a two-step pipeline: integrate the flow over the time span, then package
the result using the system's solution builder.

# Arguments
- `flow::Flows.AbstractFlow`: The flow to solve.
- `tspan`: The time span `(t0, tf)` over which to solve.
- `x0`: Initial state.
- `p0`: Initial costate.

# Returns
- The packaged solution (type varies by system implementation).

See also: [`integrate`](@ref), [`build_solution`](@ref).
"""
function solve(flow::Flows.AbstractFlow, tspan, x0, p0)
    t0, tf = tspan
    ode_sol = integrate(flow, t0, x0, p0, tf)
    return build_solution(Flows.system(flow), ode_sol)
end
