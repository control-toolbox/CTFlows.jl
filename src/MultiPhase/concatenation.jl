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
using CTFlows: Flows, MultiPhase

mpf = flow1 * (1.0, flow2)
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@extref), [`CTFlows.MultiPhase.get_flows`](@extref).
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

Concatenate two state flows with a switching time and a state jump using the `*` operator.

`jump` is applied to the state at the switching time. Two forms are accepted:
- **Additive** (vector or scalar): `x ← x + jump`.
- **Callable** (`f::Function`): `x ← f(x)`.

# Arguments
- `f1::AbstractStateFlow`: First flow (phase 1).
- `(t_switch, jump, f2)::Tuple{Real, Any, AbstractStateFlow}`: Tuple of switching time,
  state jump (vector/scalar or callable), and second flow (phase 2).

# Returns
- `MultiPhaseStateFlow`: Multi-phase flow with a jump.

# Example
\`\`\`julia
using CTFlows: Flows, MultiPhase

# additive jump
mpf = flow1 * (1.0, [0.1, 0.2], flow2)   # x ← x + [0.1, 0.2] at t = 1.0

# callable jump
mpf = flow1 * (1.0, x -> 2.0 .* x, flow2)   # x ← 2x at t = 1.0
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@extref),
  [`CTFlows.MultiPhase._apply_component_jump`](@extref).
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
using CTFlows: Flows, MultiPhase

mpf = flow1 * (1.0, flow2)
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@extref), [`CTFlows.MultiPhase.get_flows`](@extref).
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

Concatenate two Hamiltonian flows with a switching time and a jump using the `*` operator.

`jump` is applied at the switching time. Two forms are accepted:
- **Additive** (vector or scalar): `p ← p + jump`; the state is unchanged.
- **Callable** (`f::Function`): `(x, p) ← f(x, p)`; both components may change.

# Arguments
- `f1::AbstractHamiltonianFlow`: First flow (phase 1).
- `(t_switch, jump, f2)::Tuple{Real, Any, AbstractHamiltonianFlow}`: Tuple of switching time,
  jump (vector/scalar or callable), and second flow (phase 2).

# Returns
- `MultiPhaseHamiltonianFlow`: Multi-phase Hamiltonian flow with a jump.

# Example
\`\`\`julia
using CTFlows: Flows, MultiPhase

# additive costate jump
mpf = flow1 * (1.0, [0.5, 0.0], flow2)   # p ← p + [0.5, 0.0] at t = 1.0

# callable jump (both components)
mpf = flow1 * (1.0, (x, p) -> (x, 2.0 .* p), flow2)   # p ← 2p at t = 1.0
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@extref),
  [`CTFlows.MultiPhase._apply_hamiltonian_jump`](@extref).
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

Concatenate two Hamiltonian flows with a switching time and separate per-component jumps
using the `*` operator.

Each of `jump_x` and `jump_p` is applied to the state and costate independently at the
switching time. Three forms are accepted per component:
- **Additive** (vector or scalar): `component ← component + jump`.
- **Callable** (`f::Function`): `component ← f(component)`.
- **`nothing`**: component is left unchanged (state-only or costate-only jump).

# Arguments
- `f1::AbstractHamiltonianFlow`: First flow (phase 1).
- `(t_switch, jump_x, jump_p, f2)::Tuple{Real, Any, Any, AbstractHamiltonianFlow}`: Tuple of
  switching time, state jump, costate jump, and second flow (phase 2).

# Returns
- `MultiPhaseHamiltonianFlow`: Multi-phase Hamiltonian flow with per-component jumps.

# Example
\`\`\`julia
using CTFlows: Flows, MultiPhase

# additive on both
mpf = flow1 * (1.0, [0.1, 0.0], [0.0, 0.5], flow2)

# state-only additive jump (costate unchanged)
mpf = flow1 * (1.0, [0.1, 0.0], nothing, flow2)

# callable on state, nothing on costate
mpf = flow1 * (1.0, x -> 2.0 .* x, nothing, flow2)
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@extref),
  [`CTFlows.MultiPhase._apply_component_jump`](@extref).
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
