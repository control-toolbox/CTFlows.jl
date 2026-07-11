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
            throw(
                Exceptions.PreconditionError(
                    "Switching times must be strictly increasing";
                    context="flow concatenation",
                    reason="found non-increasing sequence: $switches",
                    suggestion="ensure all switching times are in strictly increasing order",
                ),
            )
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
function Base.:*(
    f1::Flows.AbstractStateFlow, (t_switch, f2)::Tuple{Real,Flows.AbstractStateFlow}
)
    flows = (get_flows(f1)..., get_flows(f2)...)
    switches = vcat(get_switching_times(f1), [t_switch], get_switching_times(f2))
    _check_switching_times_order(switches)
    jumps = vcat(get_jumps(f1), [nothing], get_jumps(f2))
    return MultiPhaseStateFlow(flows, switches, jumps)
end

"""
$(TYPEDSIGNATURES)

Concatenate two state flows with a switching time and an additive state jump using the `*`
operator.

Creates a multi-phase flow that adds `jump` to the state at the switching time
(`x ← x + jump`). The jump follows the "1-D is a scalar" convention: a scalar for a 1-D state,
a vector for an n-D state — its shape must match the state.

# Arguments
- `f1::AbstractStateFlow`: First flow (phase 1).
- `(t_switch, jump, f2)::Tuple{Real, Any, AbstractStateFlow}`: Tuple of switching time, additive
  state jump, and second flow (phase 2).

# Returns
- `MultiPhaseStateFlow`: Multi-phase flow with a jump.

# Example
\`\`\`julia
using CTFlows.Flows, CTFlows.MultiPhase

mpf = flow1 * (1.0, [0.1, 0.2], flow2)   # x ← x + [0.1, 0.2] at t = 1.0
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@ref), [`CTFlows.MultiPhase.get_flows`](@ref).
"""
function Base.:*(
    f1::Flows.AbstractStateFlow,
    (t_switch, jump, f2)::Tuple{Real,Any,Flows.AbstractStateFlow},
)
    flows = (get_flows(f1)..., get_flows(f2)...)
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
function Base.:*(
    f1::Flows.AbstractHamiltonianFlow,
    (t_switch, f2)::Tuple{Real,Flows.AbstractHamiltonianFlow},
)
    flows = (get_flows(f1)..., get_flows(f2)...)
    switches = vcat(get_switching_times(f1), [t_switch], get_switching_times(f2))
    _check_switching_times_order(switches)
    jumps = vcat(get_jumps(f1), [nothing], get_jumps(f2))
    return MultiPhaseHamiltonianFlow(flows, switches, jumps)
end

"""
$(TYPEDSIGNATURES)

Concatenate two Hamiltonian flows with a switching time and an additive costate jump using the
`*` operator.

Creates a multi-phase Hamiltonian flow that adds `jump` to the costate at the switching time
(`p ← p + jump`; the state is unchanged). The jump follows the "1-D is a scalar" convention: a
scalar for a 1-D costate, a vector for an n-D costate — its shape must match the costate.

# Arguments
- `f1::AbstractHamiltonianFlow`: First flow (phase 1).
- `(t_switch, jump, f2)::Tuple{Real, Any, AbstractHamiltonianFlow}`: Tuple of switching time,
  additive costate jump, and second flow (phase 2).

# Returns
- `MultiPhaseHamiltonianFlow`: Multi-phase Hamiltonian flow with a jump.

# Example
\`\`\`julia
using CTFlows.Flows, CTFlows.MultiPhase

mpf = flow1 * (1.0, [0.5, 0.0], flow2)   # p ← p + [0.5, 0.0] at t = 1.0
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref), [`CTFlows.MultiPhase.get_flows`](@ref).
"""
function Base.:*(
    f1::Flows.AbstractHamiltonianFlow,
    (t_switch, jump, f2)::Tuple{Real,Any,Flows.AbstractHamiltonianFlow},
)
    flows = (get_flows(f1)..., get_flows(f2)...)
    switches = vcat(get_switching_times(f1), [t_switch], get_switching_times(f2))
    _check_switching_times_order(switches)
    jumps = vcat(get_jumps(f1), [jump], get_jumps(f2))
    return MultiPhaseHamiltonianFlow(flows, switches, jumps)
end

"""
$(TYPEDSIGNATURES)

Concatenate two Hamiltonian flows with a switching time and separate additive state/costate
jumps using the `*` operator.

Creates a multi-phase Hamiltonian flow that adds `jump_x` to the state and `jump_p` to the
costate at the switching time (`x ← x + jump_x`, `p ← p + jump_p`). Each jump follows the
"1-D is a scalar" convention: a scalar for a 1-D quantity, a vector for an n-D one — its shape
must match the state/costate.

# Arguments
- `f1::AbstractHamiltonianFlow`: First flow (phase 1).
- `(t_switch, jump_x, jump_p, f2)::Tuple{Real, Any, Any, AbstractHamiltonianFlow}`: Tuple of
  switching time, additive state jump, additive costate jump, and second flow (phase 2).

# Returns
- `MultiPhaseHamiltonianFlow`: Multi-phase Hamiltonian flow with separate jumps.

# Example
\`\`\`julia
using CTFlows.Flows, CTFlows.MultiPhase

mpf = flow1 * (1.0, [0.1, 0.0], [0.0, 0.5], flow2)   # x ← x + [0.1,0.0], p ← p + [0.0,0.5]
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref), [`CTFlows.MultiPhase.get_flows`](@ref).
"""
function Base.:*(
    f1::Flows.AbstractHamiltonianFlow,
    (t_switch, jump_x, jump_p, f2)::Tuple{Real,Any,Any,Flows.AbstractHamiltonianFlow},
)
    flows = (get_flows(f1)..., get_flows(f2)...)
    switches = vcat(get_switching_times(f1), [t_switch], get_switching_times(f2))
    _check_switching_times_order(switches)
    jumps = vcat(get_jumps(f1), [(jump_x, jump_p)], get_jumps(f2))
    return MultiPhaseHamiltonianFlow(flows, switches, jumps)
end

# =============================================================================
# Cross-dynamics error: StateFlow * HamiltonianFlow and vice versa
# =============================================================================

"""
$(TYPEDSIGNATURES)

Error method for concatenating a state flow with a Hamiltonian flow.

This method is called when attempting to concatenate a state flow with a Hamiltonian flow
using the `*` operator, which is not allowed. Flows in a multi-phase sequence must all
have the same dynamics type.

# Throws
- `CTBase.Exceptions.PreconditionError`: Always, with message explaining that cross-dynamics concatenation is not allowed.

# Notes
This is an internal error method for type safety in flow concatenation.
"""
function Base.:*(::Flows.AbstractStateFlow, ::Tuple{Real,Flows.AbstractHamiltonianFlow})
    return throw(
        Exceptions.PreconditionError(
            "Cannot concatenate a state flow with a Hamiltonian flow";
            reason="both flows must have the same dynamics type (state or Hamiltonian)",
            suggestion="ensure all flows in a multi-phase sequence are of the same dynamics type",
            context="flow concatenation *",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Error method for concatenating a state flow with a Hamiltonian flow (with jump).

This method is called when attempting to concatenate a state flow with a Hamiltonian flow
and a jump function using the `*` operator, which is not allowed. Flows in a multi-phase
sequence must all have the same dynamics type.

# Throws
- `CTBase.Exceptions.PreconditionError`: Always, with message explaining that cross-dynamics concatenation is not allowed.

# Notes
This is an internal error method for type safety in flow concatenation.
"""
function Base.:*(::Flows.AbstractStateFlow, ::Tuple{Real,Any,Flows.AbstractHamiltonianFlow})
    return throw(
        Exceptions.PreconditionError(
            "Cannot concatenate a state flow with a Hamiltonian flow";
            reason="both flows must have the same dynamics type (state or Hamiltonian)",
            suggestion="ensure all flows in a multi-phase sequence are of the same dynamics type",
            context="flow concatenation *",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Error method for concatenating a Hamiltonian flow with a state flow.

This method is called when attempting to concatenate a Hamiltonian flow with a state flow
using the `*` operator, which is not allowed. Flows in a multi-phase sequence must all
have the same dynamics type.

# Throws
- `CTBase.Exceptions.PreconditionError`: Always, with message explaining that cross-dynamics concatenation is not allowed.

# Notes
This is an internal error method for type safety in flow concatenation.
"""
function Base.:*(::Flows.AbstractHamiltonianFlow, ::Tuple{Real,Flows.AbstractStateFlow})
    return throw(
        Exceptions.PreconditionError(
            "Cannot concatenate a Hamiltonian flow with a state flow";
            reason="both flows must have the same dynamics type (state or Hamiltonian)",
            suggestion="ensure all flows in a multi-phase sequence are of the same dynamics type",
            context="flow concatenation *",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Error method for concatenating a Hamiltonian flow with a state flow (with jump).

This method is called when attempting to concatenate a Hamiltonian flow with a state flow
and a jump function using the `*` operator, which is not allowed. Flows in a multi-phase
sequence must all have the same dynamics type.

# Throws
- `CTBase.Exceptions.PreconditionError`: Always, with message explaining that cross-dynamics concatenation is not allowed.

# Notes
This is an internal error method for type safety in flow concatenation.
"""
function Base.:*(::Flows.AbstractHamiltonianFlow, ::Tuple{Real,Any,Flows.AbstractStateFlow})
    return throw(
        Exceptions.PreconditionError(
            "Cannot concatenate a Hamiltonian flow with a state flow";
            reason="both flows must have the same dynamics type (state or Hamiltonian)",
            suggestion="ensure all flows in a multi-phase sequence are of the same dynamics type",
            context="flow concatenation *",
        ),
    )
end
