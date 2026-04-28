"""
$(TYPEDSIGNATURES)

Integrate a flow from initial state `x0` at time `t0` to final time `tf`.

This is a thin wrapper over the callable protocol of `AbstractFlow`. It is useful
when one wants to spell out the action by name rather than calling the flow directly.

# Arguments
- `flow::Flows.AbstractFlow`: The flow to integrate.
- `t0`: Initial time.
- `x0`: Initial state.
- `tf`: Final time.

# Returns
- The integrated trajectory (type varies by flow implementation).

See also: [`Flows.AbstractFlow`](@ref), [`solve`](@ref).
"""
function integrate(flow::Flows.AbstractFlow, t0, x0, tf)
    return flow(t0, x0, tf)
end

"""
$(TYPEDSIGNATURES)

Integrate a flow from initial state `x0` and costate `p0` at time `t0` to final time `tf`.

This is a thin wrapper over the callable protocol of `AbstractFlow`. It is useful
when one wants to spell out the action by name rather than calling the flow directly.

# Arguments
- `flow::Flows.AbstractFlow`: The flow to integrate.
- `t0`: Initial time.
- `x0`: Initial state.
- `p0`: Initial costate.
- `tf`: Final time.

# Returns
- The integrated trajectory (type varies by flow implementation).

See also: [`Flows.AbstractFlow`](@ref), [`solve`](@ref).
"""
function integrate(flow::Flows.AbstractFlow, t0, x0, p0, tf)
    return flow(t0, x0, p0, tf)
end
