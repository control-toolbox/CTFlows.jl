# =============================================================================
# Private helper: switching times validation
# =============================================================================

"""
$(TYPEDSIGNATURES)

Validate that switching times are strictly increasing.

Throws a [`CTBase.Exceptions.PreconditionError`](@extref) if the switching times are not in strictly
increasing order (i.e., if any `switches[i] >= switches[i+1]`).

# Arguments
- `switches::Vector{<:Real}`: Vector of switching times to validate.

# Throws
- [`CTBase.Exceptions.PreconditionError`](@extref): If switching times are not strictly increasing.

# Notes
- This is a private helper function used internally by concatenation operators.
- Strictly increasing means each time must be greater than the previous one.
"""
function _check_switching_times_order(switches::Vector{<:Real})
    for i in 1:(length(switches) - 1)
        if switches[i] >= switches[i + 1]
            throw(Exceptions.PreconditionError(
                "Switching times must be strictly increasing";
                context = "flow concatenation",
                reason = "found non-increasing sequence: $switches",
                suggestion = "ensure all switching times are in strictly increasing order",
            ))
        end
    end
end

"""
$(TYPEDSIGNATURES)

Concatenate two state flows with a switching time using the `*` operator.

Creates a multi-phase flow with no jump at the switching time.

# Arguments
- `f1::AbstractStateFlow`: First flow (phase 1).
- `(t_switch, f2)::Tuple{Real, AbstractStateFlow}`: Tuple of switching time and second flow (phase 2).

# Returns
- `MultiPhaseStateFlow`: Multi-phase flow.

# Example
\`\`\`julia
using CTFlows.Flows, CTFlows.MultiPhase

mpf = flow1 * (1.0, flow2)
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@ref), [`CTFlows.MultiPhase.get_flows`](@ref).
"""
function Base.:*(f1::Flows.AbstractStateFlow, (t_switch, f2)::Tuple{Real, Flows.AbstractStateFlow})
    flows = vcat(get_flows(f1), get_flows(f2))
    switches = vcat(get_switching_times(f1), [t_switch], get_switching_times(f2))
    _check_switching_times_order(switches)
    jumps = vcat(get_jumps(f1), [nothing], get_jumps(f2))
    return MultiPhaseStateFlow(flows, switches, jumps)
end

"""
$(TYPEDSIGNATURES)

Concatenate two state flows with a switching time and jump using the `*` operator.

Creates a multi-phase flow with a jump function applied at the switching time.

# Arguments
- `f1::AbstractStateFlow`: First flow (phase 1).
- `(t_switch, jump, f2)::Tuple{Real, Any, AbstractStateFlow}`: Tuple of switching time, jump function, and second flow (phase 2).

# Returns
- `MultiPhaseStateFlow`: Multi-phase flow with a jump.

# Example
\`\`\`julia
using CTFlows.Flows, CTFlows.MultiPhase

jump = x -> 2 * x
mpf = flow1 * (1.0, jump, flow2)
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@ref), [`CTFlows.MultiPhase.get_flows`](@ref).
"""
function Base.:*(f1::Flows.AbstractStateFlow, (t_switch, jump, f2)::Tuple{Real, Any, Flows.AbstractStateFlow})
    flows = vcat(get_flows(f1), get_flows(f2))
    switches = vcat(get_switching_times(f1), [t_switch], get_switching_times(f2))
    _check_switching_times_order(switches)
    jumps = vcat(get_jumps(f1), [jump], get_jumps(f2))
    return MultiPhaseStateFlow(flows, switches, jumps)
end

"""
$(TYPEDSIGNATURES)

Concatenate two Hamiltonian flows with a switching time using the `*` operator.

Creates a multi-phase Hamiltonian flow with no jump at the switching time.

# Arguments
- `f1::AbstractHamiltonianFlow`: First flow (phase 1).
- `(t_switch, f2)::Tuple{Real, AbstractHamiltonianFlow}`: Tuple of switching time and second flow (phase 2).

# Returns
- `MultiPhaseHamiltonianFlow`: Multi-phase Hamiltonian flow.

# Example
\`\`\`julia
using CTFlows.Flows, CTFlows.MultiPhase

mpf = flow1 * (1.0, flow2)
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref), [`CTFlows.MultiPhase.get_flows`](@ref).
"""
function Base.:*(f1::Flows.AbstractHamiltonianFlow, (t_switch, f2)::Tuple{Real, Flows.AbstractHamiltonianFlow})
    flows = vcat(get_flows(f1), get_flows(f2))
    switches = vcat(get_switching_times(f1), [t_switch], get_switching_times(f2))
    _check_switching_times_order(switches)
    jumps = vcat(get_jumps(f1), [nothing], get_jumps(f2))
    return MultiPhaseHamiltonianFlow(flows, switches, jumps)
end

"""
$(TYPEDSIGNATURES)

Concatenate two Hamiltonian flows with a switching time and jump using the `*` operator.

Creates a multi-phase Hamiltonian flow with a jump function applied at the switching time.

# Arguments
- `f1::AbstractHamiltonianFlow`: First flow (phase 1).
- `(t_switch, jump, f2)::Tuple{Real, Any, AbstractHamiltonianFlow}`: Tuple of switching time, jump function, and second flow (phase 2).

# Returns
- `MultiPhaseHamiltonianFlow`: Multi-phase Hamiltonian flow with a jump.

# Example
\`\`\`julia
using CTFlows.Flows, CTFlows.MultiPhase

jump = x -> 2 * x
mpf = flow1 * (1.0, jump, flow2)
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref), [`CTFlows.MultiPhase.get_flows`](@ref).
"""
function Base.:*(f1::Flows.AbstractHamiltonianFlow, (t_switch, jump, f2)::Tuple{Real, Any, Flows.AbstractHamiltonianFlow})
    flows = vcat(get_flows(f1), get_flows(f2))
    switches = vcat(get_switching_times(f1), [t_switch], get_switching_times(f2))
    _check_switching_times_order(switches)
    jumps = vcat(get_jumps(f1), [jump], get_jumps(f2))
    return MultiPhaseHamiltonianFlow(flows, switches, jumps)
end

"""
$(TYPEDSIGNATURES)

Concatenate two Hamiltonian flows with a switching time and separate state/costate jumps using the `*` operator.

Creates a multi-phase Hamiltonian flow with separate jump functions for state and costate applied at the switching time.

# Arguments
- `f1::AbstractHamiltonianFlow`: First flow (phase 1).
- `(t_switch, jump_x, jump_p, f2)::Tuple{Real, Any, Any, AbstractHamiltonianFlow}`: Tuple of switching time, state jump, costate jump, and second flow (phase 2).

# Returns
- `MultiPhaseHamiltonianFlow`: Multi-phase Hamiltonian flow with separate jumps.

# Example
\`\`\`julia
using CTFlows.Flows, CTFlows.MultiPhase

jump_x = x -> 2 * x
jump_p = p -> 3 * p
mpf = flow1 * (1.0, jump_x, jump_p, flow2)
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref), [`CTFlows.MultiPhase.get_flows`](@ref).
"""
function Base.:*(f1::Flows.AbstractHamiltonianFlow, (t_switch, jump_x, jump_p, f2)::Tuple{Real, Any, Any, Flows.AbstractHamiltonianFlow})
    flows = vcat(get_flows(f1), get_flows(f2))
    switches = vcat(get_switching_times(f1), [t_switch], get_switching_times(f2))
    _check_switching_times_order(switches)
    jumps = vcat(get_jumps(f1), [(jump_x, jump_p)], get_jumps(f2))
    return MultiPhaseHamiltonianFlow(flows, switches, jumps)
end
