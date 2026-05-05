"""
$(TYPEDSIGNATURES)

Concatenate two state flows with a switching time using the `*` operator.

Creates a two-phase multi-phase flow with no jump at the switching time.

# Arguments
- `f1::StateFlow`: First flow (phase 1).
- `(t_switch, f2)::Tuple{Real, StateFlow}`: Tuple of switching time and second flow (phase 2).

# Returns
- `MultiPhaseStateFlow`: Multi-phase flow with two phases.

# Example
\`\`\`julia
using CTFlows.Flows, CTFlows.MultiPhase

mpf = flow1 * (1.0, flow2)
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@ref).
"""
function Base.:*(f1::Flows.StateFlow, (t_switch, f2)::Tuple{Real, Flows.StateFlow})
    return MultiPhaseStateFlow([f1, f2], [t_switch], [nothing])
end

"""
$(TYPEDSIGNATURES)

Concatenate two state flows with a switching time and jump using the `*` operator.

Creates a two-phase multi-phase flow with a jump function applied at the switching time.

# Arguments
- `f1::StateFlow`: First flow (phase 1).
- `(t_switch, jump, f2)::Tuple{Real, Any, StateFlow}`: Tuple of switching time, jump function, and second flow (phase 2).

# Returns
- `MultiPhaseStateFlow`: Multi-phase flow with two phases and a jump.

# Example
\`\`\`julia
using CTFlows.Flows, CTFlows.MultiPhase

jump = x -> 2 * x
mpf = flow1 * (1.0, jump, flow2)
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@ref).
"""
function Base.:*(f1::Flows.StateFlow, (t_switch, jump, f2)::Tuple{Real, Any, Flows.StateFlow})
    return MultiPhaseStateFlow([f1, f2], [t_switch], [jump])
end

"""
$(TYPEDSIGNATURES)

Concatenate two Hamiltonian flows with a switching time using the `*` operator.

Creates a two-phase multi-phase Hamiltonian flow with no jump at the switching time.

# Arguments
- `f1::HamiltonianFlow`: First flow (phase 1).
- `(t_switch, f2)::Tuple{Real, HamiltonianFlow}`: Tuple of switching time and second flow (phase 2).

# Returns
- `MultiPhaseHamiltonianFlow`: Multi-phase Hamiltonian flow with two phases.

# Example
\`\`\`julia
using CTFlows.Flows, CTFlows.MultiPhase

mpf = flow1 * (1.0, flow2)
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref).
"""
function Base.:*(f1::Flows.HamiltonianFlow, (t_switch, f2)::Tuple{Real, Flows.HamiltonianFlow})
    return MultiPhaseHamiltonianFlow([f1, f2], [t_switch], [nothing])
end

"""
$(TYPEDSIGNATURES)

Concatenate two Hamiltonian flows with a switching time and jump using the `*` operator.

Creates a two-phase multi-phase Hamiltonian flow with a jump function applied at the switching time.

# Arguments
- `f1::HamiltonianFlow`: First flow (phase 1).
- `(t_switch, jump, f2)::Tuple{Real, Any, HamiltonianFlow}`: Tuple of switching time, jump function, and second flow (phase 2).

# Returns
- `MultiPhaseHamiltonianFlow`: Multi-phase Hamiltonian flow with two phases and a jump.

# Example
\`\`\`julia
using CTFlows.Flows, CTFlows.MultiPhase

jump = x -> 2 * x
mpf = flow1 * (1.0, jump, flow2)
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref).
"""
function Base.:*(f1::Flows.HamiltonianFlow, (t_switch, jump, f2)::Tuple{Real, Any, Flows.HamiltonianFlow})
    return MultiPhaseHamiltonianFlow([f1, f2], [t_switch], [jump])
end

"""
$(TYPEDSIGNATURES)

Concatenate two Hamiltonian flows with a switching time and separate state/costate jumps using the `*` operator.

Creates a two-phase multi-phase Hamiltonian flow with separate jump functions for state and costate applied at the switching time.

# Arguments
- `f1::HamiltonianFlow`: First flow (phase 1).
- `(t_switch, jump_x, jump_p, f2)::Tuple{Real, Any, Any, HamiltonianFlow}`: Tuple of switching time, state jump, costate jump, and second flow (phase 2).

# Returns
- `MultiPhaseHamiltonianFlow`: Multi-phase Hamiltonian flow with two phases and separate jumps.

# Example
\`\`\`julia
using CTFlows.Flows, CTFlows.MultiPhase

jump_x = x -> 2 * x
jump_p = p -> 3 * p
mpf = flow1 * (1.0, jump_x, jump_p, flow2)
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref).
"""
function Base.:*(f1::Flows.HamiltonianFlow, (t_switch, jump_x, jump_p, f2)::Tuple{Real, Any, Any, Flows.HamiltonianFlow})
    return MultiPhaseHamiltonianFlow([f1, f2], [t_switch], [(jump_x, jump_p)])
end

"""
$(TYPEDSIGNATURES)

Append a state flow to a multi-phase state flow using the `*` operator.

Extends the multi-phase flow with an additional phase and no jump.

# Arguments
- `mpf::MultiPhaseStateFlow`: Existing multi-phase state flow.
- `(t_switch, f2)::Tuple{Real, StateFlow}`: Tuple of switching time and new flow to append.

# Returns
- `MultiPhaseStateFlow`: Extended multi-phase flow with an additional phase.

# Example
\`\`\`julia
using CTFlows.Flows, CTFlows.MultiPhase

mpf = mpf * (2.0, flow3)
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@ref).
"""
function Base.:*(mpf::MultiPhaseStateFlow, (t_switch, f2)::Tuple{Real, Flows.StateFlow})
    return MultiPhaseStateFlow([mpf.flows..., f2], [mpf.switching_times..., t_switch], [mpf.jumps..., nothing])
end

"""
$(TYPEDSIGNATURES)

Append a state flow with a jump to a multi-phase state flow using the `*` operator.

Extends the multi-phase flow with an additional phase and a jump function.

# Arguments
- `mpf::MultiPhaseStateFlow`: Existing multi-phase state flow.
- `(t_switch, jump, f2)::Tuple{Real, Any, StateFlow}`: Tuple of switching time, jump function, and new flow to append.

# Returns
- `MultiPhaseStateFlow`: Extended multi-phase flow with an additional phase and jump.

# Example
\`\`\`julia
using CTFlows.Flows, CTFlows.MultiPhase

jump = x -> 2 * x
mpf = mpf * (2.0, jump, flow3)
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@ref).
"""
function Base.:*(mpf::MultiPhaseStateFlow, (t_switch, jump, f2)::Tuple{Real, Any, Flows.StateFlow})
    return MultiPhaseStateFlow([mpf.flows..., f2], [mpf.switching_times..., t_switch], [mpf.jumps..., jump])
end

"""
$(TYPEDSIGNATURES)

Append a Hamiltonian flow to a multi-phase Hamiltonian flow using the `*` operator.

Extends the multi-phase Hamiltonian flow with an additional phase and no jump.

# Arguments
- `mpf::MultiPhaseHamiltonianFlow`: Existing multi-phase Hamiltonian flow.
- `(t_switch, f2)::Tuple{Real, HamiltonianFlow}`: Tuple of switching time and new flow to append.

# Returns
- `MultiPhaseHamiltonianFlow`: Extended multi-phase Hamiltonian flow with an additional phase.

# Example
\`\`\`julia
using CTFlows.Flows, CTFlows.MultiPhase

mpf = mpf * (2.0, flow3)
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref).
"""
function Base.:*(mpf::MultiPhaseHamiltonianFlow, (t_switch, f2)::Tuple{Real, Flows.HamiltonianFlow})
    return MultiPhaseHamiltonianFlow([mpf.flows..., f2], [mpf.switching_times..., t_switch], [mpf.jumps..., nothing])
end

"""
$(TYPEDSIGNATURES)

Append a Hamiltonian flow with a jump to a multi-phase Hamiltonian flow using the `*` operator.

Extends the multi-phase Hamiltonian flow with an additional phase and a jump function.

# Arguments
- `mpf::MultiPhaseHamiltonianFlow`: Existing multi-phase Hamiltonian flow.
- `(t_switch, jump, f2)::Tuple{Real, Any, HamiltonianFlow}`: Tuple of switching time, jump function, and new flow to append.

# Returns
- `MultiPhaseHamiltonianFlow`: Extended multi-phase Hamiltonian flow with an additional phase and jump.

# Example
\`\`\`julia
using CTFlows.Flows, CTFlows.MultiPhase

jump = x -> 2 * x
mpf = mpf * (2.0, jump, flow3)
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref).
"""
function Base.:*(mpf::MultiPhaseHamiltonianFlow, (t_switch, jump, f2)::Tuple{Real, Any, Flows.HamiltonianFlow})
    return MultiPhaseHamiltonianFlow([mpf.flows..., f2], [mpf.switching_times..., t_switch], [mpf.jumps..., jump])
end
