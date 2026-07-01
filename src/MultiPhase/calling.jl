# ==============================================================================
# Generic Multiphase Evaluation Loop
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Extract the initial state from a state configuration.

# Arguments
- `config::Configs.AbstractStateConfig`: The state configuration (StateEndPointConfig or StateTrajectoryConfig).

# Returns
- Initial state vector.

See also: [`CTFlows.Configs.initial_state`](@ref), [`CTFlows.Configs.AbstractStateConfig`](@ref).
"""
function _extract_initial_state(config::Configs.AbstractStateConfig)
    return Configs.initial_state(config)
end

"""
$(TYPEDSIGNATURES)

Extract the initial state and costate from a Hamiltonian configuration.

# Arguments
- `config::Configs.AbstractHamiltonianConfig`: The Hamiltonian configuration (HamiltonianEndPointConfig or HamiltonianTrajectoryConfig).

# Returns
- Tuple of (initial_state, initial_costate).

See also: [`CTFlows.Configs.initial_state`](@ref), [`CTFlows.Configs.initial_costate`](@ref), [`CTFlows.Configs.AbstractHamiltonianConfig`](@ref).
"""
function _extract_initial_state(config::Configs.AbstractHamiltonianConfig)
    return (Configs.initial_state(config), Configs.initial_costate(config))
end

"""
$(TYPEDSIGNATURES)

Evaluate a multi-phase flow for a point configuration, returning only the final state.

Iterates through all phases sequentially, applying jumps at switching times.

# Arguments
- `mpf`: The multi-phase flow to evaluate.
- `config::Configs.AbstractEndPointConfig`: The point configuration with time span and initial conditions.
- `variable`: The variable parameter value (for NonFixed systems).
- `unsafe`: If true, bypass ODE solver retcode checking.

# Returns
- Final state after all phases.

See also: [`CTFlows.MultiPhase._evaluate_phase`](@ref), [`CTFlows.MultiPhase._apply_jump`](@ref).
"""
function _evaluate_multiphase(mpf, config::Configs.AbstractEndPointConfig; variable, unsafe)
    t0, tf = Configs.tspan(config)
    current_state = _extract_initial_state(config)
    current_t = t0
    n_ph = n_phases(mpf)
    
    for i in 1:n_ph
        t_end = (i < n_ph) ? get_switching_time(mpf, i) : tf
        
        current_state = _evaluate_phase(get_flow(mpf, i), current_t, t_end, current_state, config; variable=variable, unsafe=unsafe)
        
        current_t = t_end
        
        if i < n_ph
            jump = get_jump(mpf, i)
            if !isnothing(jump)
                current_state = _apply_jump(mpf, i, current_state)
            end
        end
    end
    
    return _format_final_output(mpf, current_state)
end

"""
$(TYPEDSIGNATURES)

Evaluate a multi-phase flow for a trajectory configuration, returning the full trajectory.

Iterates through all phases sequentially, collecting segment results and applying jumps at switching times.

# Arguments
- `mpf`: The multi-phase flow to evaluate.
- `config::Configs.AbstractTrajectoryConfig`: The trajectory configuration with time span and initial conditions.
- `variable`: The variable parameter value (for NonFixed systems).
- `unsafe`: If true, bypass ODE solver retcode checking.

# Returns
- Merged trajectory solution after all phases.

See also: [`CTSolvers.Integrators.merge`](@extref), [`CTFlows.MultiPhase._evaluate_phase`](@ref), [`CTFlows.MultiPhase._apply_jump`](@ref).
"""
function _evaluate_multiphase(mpf, config::Configs.AbstractTrajectoryConfig; variable, unsafe)
    t0, tf = Configs.tspan(config)
    current_state = _extract_initial_state(config)
    current_t = t0
    n_ph = n_phases(mpf)
    
    results = nothing
    
    for i in 1:n_ph
        t_end = (i < n_ph) ? get_switching_time(mpf, i) : tf
        
        segment_result = _evaluate_phase(get_flow(mpf, i), current_t, t_end, current_state, config; variable=variable, unsafe=unsafe)
        results = isnothing(results) ? [segment_result] : push!(results, segment_result)
        
        current_state = _extract_final_state(mpf, segment_result, current_state)
        current_t = t_end
        
        if i < n_ph
            jump = get_jump(mpf, i)
            if !isnothing(jump)
                current_state = _apply_jump(mpf, i, current_state)
            end
        end
    end
    
    return Integrators.merge(results)
end

# ==============================================================================
# Phase Evaluation & Jump Delegation
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Evaluate a single phase for a state flow with point configuration.

# Arguments
- `flow::Flows.StateFlow`: The state flow to evaluate.
- `t0`: Start time.
- `tf`: End time.
- `x`: Initial state.
- `::Configs.AbstractEndPointConfig`: Point configuration type tag.
- `variable`: The variable parameter value (for NonFixed systems).
- `unsafe`: If true, bypass ODE solver retcode checking.

# Returns
- Final state at time tf.

See also: [`CTFlows.Flows.StateFlow`](@ref).
"""
function _evaluate_phase(flow::Flows.StateFlow, t0, tf, x, ::Configs.AbstractEndPointConfig; variable, unsafe)
    return flow(t0, x, tf; variable=variable, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Evaluate a single phase for a state flow with trajectory configuration.

# Arguments
- `flow::Flows.StateFlow`: The state flow to evaluate.
- `t0`: Start time.
- `tf`: End time.
- `x`: Initial state.
- `::Configs.AbstractTrajectoryConfig`: Trajectory configuration type tag.
- `variable`: The variable parameter value (for NonFixed systems).
- `unsafe`: If true, bypass ODE solver retcode checking.

# Returns
- Trajectory solution from t0 to tf.

See also: [`CTFlows.Flows.StateFlow`](@ref).
"""
function _evaluate_phase(flow::Flows.StateFlow, t0, tf, x, ::Configs.AbstractTrajectoryConfig; variable, unsafe)
    return flow((t0, tf), x; variable=variable, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Evaluate a single phase for a Hamiltonian flow with point configuration.

# Arguments
- `flow::Flows.HamiltonianFlow`: The Hamiltonian flow to evaluate.
- `t0`: Start time.
- `tf`: End time.
- `state_tuple`: Tuple of (initial_state, initial_costate).
- `::Configs.AbstractEndPointConfig`: Point configuration type tag.
- `variable`: The variable parameter value (for NonFixed systems).
- `unsafe`: If true, bypass ODE solver retcode checking.

# Returns
- Tuple of (final_state, final_costate) at time tf.

See also: [`CTFlows.Flows.HamiltonianFlow`](@ref).
"""
function _evaluate_phase(flow::Flows.HamiltonianFlow, t0, tf, state_tuple, ::Configs.AbstractEndPointConfig; variable, unsafe)
    x, p = state_tuple
    return flow(t0, x, p, tf; variable=variable, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Evaluate a single phase for a Hamiltonian flow with trajectory configuration.

# Arguments
- `flow::Flows.HamiltonianFlow`: The Hamiltonian flow to evaluate.
- `t0`: Start time.
- `tf`: End time.
- `state_tuple`: Tuple of (initial_state, initial_costate).
- `::Configs.AbstractTrajectoryConfig`: Trajectory configuration type tag.
- `variable`: The variable parameter value (for NonFixed systems).
- `unsafe`: If true, bypass ODE solver retcode checking.

# Returns
- Trajectory solution from t0 to tf.

See also: [`CTFlows.Flows.HamiltonianFlow`](@ref).
"""
function _evaluate_phase(flow::Flows.HamiltonianFlow, t0, tf, state_tuple, ::Configs.AbstractTrajectoryConfig; variable, unsafe)
    x, p = state_tuple
    return flow((t0, tf), x, p; variable=variable, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Extract the final state from a segment result for state flows.

# Arguments
- `::MultiPhaseStateFlow`: Multi-phase state flow type tag.
- `segment`: The segment solution.
- `current_state`: Current state (unused for state flows).

# Returns
- Final state from the segment.

See also: [`CTFlows.Integrators.final_state`]().
"""
function _extract_final_state(mpf::MultiPhaseFlow, segment, current_state)
    return _extract_final_state(Traits.dynamics_trait(mpf), segment, current_state)
end

"""
$(TYPEDSIGNATURES)

Extract the final state from a segment result for state dynamics.

# Arguments
- `::Type{Traits.StateDynamics}`: State dynamics trait tag.
- `segment`: The segment solution.
- `_`: Current state (unused for state dynamics).

# Returns
- Final state from the segment.

# Notes
This is an internal dispatch method for the `_extract_final_state` function.
"""
function _extract_final_state(::Type{Traits.StateDynamics}, segment, _)
    return Integrators.final_state(segment)
end

"""
$(TYPEDSIGNATURES)

Extract the final state and costate from a segment result for Hamiltonian dynamics.

# Arguments
- `::Type{Traits.HamiltonianDynamics}`: Hamiltonian dynamics trait tag.
- `segment`: The segment solution (concatenated state and costate).
- `current_state`: Current state tuple (state, costate) used to determine dimensions.

# Returns
- Tuple of (final_state, final_costate).

# Notes
This is an internal dispatch method for the `_extract_final_state` function.
"""
function _extract_final_state(::Type{Traits.HamiltonianDynamics}, segment, current_state)
    final = Integrators.final_state(segment)
    nx = length(current_state[1])
    return (final[1:nx], final[nx+1:end])
end

function _extract_final_state(::Type{Traits.HamiltonianDynamics}, segment::Trajectories.HamiltonianVectorFieldTrajectory, _)
    return Integrators.final_state(segment)
end

"""
$(TYPEDSIGNATURES)

Apply a jump to the state for state flows.

# Arguments
- `mpf::MultiPhaseStateFlow`: The multi-phase state flow.
- `i`: Phase index.
- `state`: Current state.

# Returns
- State after applying the jump.

See also: [`CTFlows.MultiPhase.get_jump`](@ref).
"""
function _apply_jump(mpf::MultiPhaseFlow, i, state)
    return _apply_jump(Traits.dynamics_trait(mpf), mpf, i, state)
end

"""
$(TYPEDSIGNATURES)

Apply a jump to the state for state dynamics.

# Arguments
- `::Type{Traits.StateDynamics}`: State dynamics trait tag.
- `mpf::MultiPhaseFlow`: The multi-phase flow.
- `i::Int`: Phase index.
- `state`: Current state.

# Returns
- State after applying the jump (element-wise addition).

# Notes
This is an internal dispatch method for the `_apply_jump` function.
"""
function _apply_jump(::Type{Traits.StateDynamics}, mpf, i, state)
    return state .+ get_jump(mpf, i)
end

"""
$(TYPEDSIGNATURES)

Apply a jump to the state and costate for Hamiltonian dynamics.

# Arguments
- `::Type{Traits.HamiltonianDynamics}`: Hamiltonian dynamics trait tag.
- `mpf::MultiPhaseFlow`: The multi-phase flow.
- `i::Int`: Phase index.
- `state_tuple`: Tuple of (state, costate).

# Returns
- Tuple of (state, costate) after applying the jump.

# Notes
This is an internal dispatch method for the `_apply_jump` function.
"""
function _apply_jump(::Type{Traits.HamiltonianDynamics}, mpf, i, state_tuple)
    return _apply_hamiltonian_jump(state_tuple, get_jump(mpf, i))
end

"""
$(TYPEDSIGNATURES)

Apply a tuple jump to a Hamiltonian state tuple.

# Arguments
- `state_tuple::Tuple`: Tuple of (state, costate).
- `jump::Tuple`: Tuple of (state_jump, costate_jump).

# Returns
- Tuple of (state + state_jump, costate + costate_jump).

See also: [`CTFlows.MultiPhase._apply_jump`](@ref).
"""
function _apply_hamiltonian_jump(state_tuple::Tuple, jump::Tuple)
    x, p = state_tuple
    return (x + jump[1], p + jump[2])
end

"""
$(TYPEDSIGNATURES)

Apply a scalar jump to the costate component of a Hamiltonian state tuple.

# Arguments
- `state_tuple::Tuple`: Tuple of (state, costate).
- `jump`: Costate jump value (scalar).

# Returns
- Tuple of (state, costate + jump).

See also: [`CTFlows.MultiPhase._apply_jump`](@ref).
"""
function _apply_hamiltonian_jump(state_tuple::Tuple, jump)
    x, p = state_tuple
    return (x, p + jump)
end

"""
$(TYPEDSIGNATURES)

Format the final output for state flows.

# Arguments
- `::MultiPhaseStateFlow`: Multi-phase state flow type tag.
- `x`: Final state.

# Returns
- The final state (no formatting needed).

See also: [`CTFlows.MultiPhase._evaluate_multiphase`](@ref).
"""
function _format_final_output(mpf::MultiPhaseFlow, state)
    return _format_final_output(Traits.dynamics_trait(mpf), state)
end

"""
$(TYPEDSIGNATURES)

Format the final output for state dynamics.

# Arguments
- `::Type{Traits.StateDynamics}`: State dynamics trait tag.
- `x`: Final state.

# Returns
- The final state (no formatting needed).

# Notes
This is an internal dispatch method for the `_format_final_output` function.
"""
function _format_final_output(::Type{Traits.StateDynamics}, x)
    return x
end

"""
$(TYPEDSIGNATURES)

Format the final output for Hamiltonian dynamics.

# Arguments
- `::Type{Traits.HamiltonianDynamics}`: Hamiltonian dynamics trait tag.
- `state_tuple`: Tuple of (state, costate).

# Returns
- Concatenated vector [state; costate].

# Notes
This is an internal dispatch method for the `_format_final_output` function.
"""
function _format_final_output(::Type{Traits.HamiltonianDynamics}, state_tuple)
    x, p = state_tuple
    return vcat(x, p)
end

# ==============================================================================
# Public Callable Interfaces
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Convenience call for `MultiPhaseStateFlow` with point configuration.

Builds a `StateEndPointConfig` internally and evaluates the multi-phase flow.

# Arguments
- `mpf::MultiPhaseStateFlow`: The multi-phase state flow to evaluate.
- `t0::Real`: Initial time.
- `x0`: Initial state vector.
- `tf::Real`: Final time.
- `variable`: The variable parameter value (required for NonFixed systems, optional for Fixed systems).
- `unsafe`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The final state after sequential integration through all phases.

# Example
\`\`\`julia
using CTFlows.MultiPhase

mpf = flow1 * (1.0, flow2) * (2.0, flow3)
sol = mpf(0.0, [1.0, 0.0], 3.0)
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@ref), [`CTFlows.Configs.StateEndPointConfig`](@ref).
"""
function (mpf::MultiPhaseFlow{TD, VD, Traits.StateDynamics})(
    t0::Real,
    x0,
    tf::Real;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
) where {TD, VD}
    config = Configs.StateEndPointConfig(t0, x0, tf)
    return _evaluate_multiphase(mpf, config; variable=variable, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Convenience call for `MultiPhaseStateFlow` with trajectory configuration.

Builds a `StateTrajectoryConfig` internally and evaluates the multi-phase flow,
returning a merged trajectory from all phases.

# Arguments
- `mpf::MultiPhaseStateFlow`: The multi-phase state flow to evaluate.
- `tspan::Tuple{Real, Real}`: Time span as a tuple (t0, tf).
- `x0`: Initial state vector.
- `variable`: The variable parameter value (required for NonFixed systems, optional for Fixed systems).
- `unsafe`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The merged trajectory solution after sequential integration through all phases.

# Example
\`\`\`julia
using CTFlows.MultiPhase

mpf = flow1 * (1.0, flow2) * (2.0, flow3)
sol = mpf((0.0, 3.0), [1.0, 0.0])
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@ref), [`CTFlows.Configs.StateTrajectoryConfig`](@ref).
"""
function (mpf::MultiPhaseFlow{TD, VD, Traits.StateDynamics})(
    tspan::Tuple{Real, Real},
    x0;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
) where {TD, VD}
    config = Configs.StateTrajectoryConfig(tspan, x0)
    return _evaluate_multiphase(mpf, config; variable=variable, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Convenience call for `MultiPhaseHamiltonianFlow` with point configuration.

Builds a `HamiltonianEndPointConfig` internally and evaluates the multi-phase flow.

# Arguments
- `mpf::MultiPhaseHamiltonianFlow`: The multi-phase Hamiltonian flow to evaluate.
- `t0::Real`: Initial time.
- `x0`: Initial state vector.
- `p0`: Initial costate vector.
- `tf::Real`: Final time.
- `variable`: The variable parameter value (required for NonFixed systems, optional for Fixed systems).
- `unsafe`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The final state and costate after sequential integration through all phases.

# Example
\`\`\`julia
using CTFlows.MultiPhase

mpf = flow1 * (1.0, flow2) * (2.0, flow3)
sol = mpf(0.0, [1.0, 0.0], [0.5, 0.3], 3.0)
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref), [`CTFlows.Configs.HamiltonianEndPointConfig`](@ref).
"""
function (mpf::MultiPhaseFlow{TD, VD, Traits.HamiltonianDynamics})(
    t0::Real,
    x0,
    p0,
    tf::Real;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
) where {TD, VD}
    config = Configs.HamiltonianEndPointConfig(t0, x0, p0, tf)
    return _evaluate_multiphase(mpf, config; variable=variable, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Convenience call for `MultiPhaseHamiltonianFlow` with trajectory configuration.

Builds a `HamiltonianTrajectoryConfig` internally and evaluates the multi-phase flow,
returning a merged trajectory from all phases.

# Arguments
- `mpf::MultiPhaseHamiltonianFlow`: The multi-phase Hamiltonian flow to evaluate.
- `tspan::Tuple{Real, Real}`: Time span as a tuple (t0, tf).
- `x0`: Initial state vector.
- `p0`: Initial costate vector.
- `variable`: The variable parameter value (required for NonFixed systems, optional for Fixed systems).
- `unsafe`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The merged trajectory solution after sequential integration through all phases.

# Example
\`\`\`julia
using CTFlows.MultiPhase

mpf = flow1 * (1.0, flow2) * (2.0, flow3)
sol = mpf((0.0, 3.0), [1.0, 0.0], [0.5, 0.3])
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref), [`CTFlows.Configs.HamiltonianTrajectoryConfig`](@ref).
"""
function (mpf::MultiPhaseFlow{TD, VD, Traits.HamiltonianDynamics})(
    tspan::Tuple{Real, Real},
    x0,
    p0;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
) where {TD, VD}
    config = Configs.HamiltonianTrajectoryConfig(tspan, x0, p0)
    return _evaluate_multiphase(mpf, config; variable=variable, unsafe=unsafe)
end
