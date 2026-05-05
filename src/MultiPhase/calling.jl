# ==============================================================================
# Generic Multiphase Evaluation Loop
# ==============================================================================

_extract_initial_state(config::Common.PointConfig) = Common.initial_state(config)
_extract_initial_state(config::Common.TrajectoryConfig) = Common.initial_state(config)
_extract_initial_state(config::Common.HamiltonianPointConfig) = (Common.initial_state(config), Common.initial_costate(config))
_extract_initial_state(config::Common.HamiltonianTrajectoryConfig) = (Common.initial_state(config), Common.initial_costate(config))

function _evaluate_multiphase(mpf, config::Common.AbstractPointConfig; variable, unsafe)
    t0, tf = Common.tspan(config)
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

function _evaluate_multiphase(mpf, config::Common.AbstractTrajectoryConfig; variable, unsafe)
    t0, tf = Common.tspan(config)
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

function _evaluate_phase(flow::Flows.StateFlow, t0, tf, x, ::Common.AbstractPointConfig; variable, unsafe)
    return flow(t0, x, tf; variable=variable, unsafe=unsafe)
end

function _evaluate_phase(flow::Flows.StateFlow, t0, tf, x, ::Common.AbstractTrajectoryConfig; variable, unsafe)
    return flow((t0, tf), x; variable=variable, unsafe=unsafe)
end

function _evaluate_phase(flow::Flows.HamiltonianFlow, t0, tf, state_tuple, ::Common.AbstractPointConfig; variable, unsafe)
    x, p = state_tuple
    xfpf = flow(t0, x, p, tf; variable=variable, unsafe=unsafe)
    nx = length(x)
    return (xfpf[1:nx], xfpf[nx+1:end])
end

function _evaluate_phase(flow::Flows.HamiltonianFlow, t0, tf, state_tuple, ::Common.AbstractTrajectoryConfig; variable, unsafe)
    x, p = state_tuple
    return flow((t0, tf), x, p; variable=variable, unsafe=unsafe)
end

function _extract_final_state(::MultiPhaseStateFlow, segment, current_state)
    return Solutions.final_state(segment)
end

function _extract_final_state(::MultiPhaseHamiltonianFlow, segment, current_state)
    final = Solutions.final_state(segment)
    nx = length(current_state[1])
    return (final[1:nx], final[nx+1:end])
end

function _apply_jump(mpf::MultiPhaseStateFlow, i, state)
    jump = get_jump(mpf, i)
    return state + jump
end

function _apply_jump(mpf::MultiPhaseHamiltonianFlow, i, state_tuple)
    jump = get_jump(mpf, i)
    return _apply_hamiltonian_jump(state_tuple, jump)
end

function _apply_hamiltonian_jump(state_tuple::Tuple, jump::Tuple)
    x, p = state_tuple
    return (x + jump[1], p + jump[2])
end

function _apply_hamiltonian_jump(state_tuple::Tuple, jump)
    x, p = state_tuple
    return (x, p + jump)
end

function _format_final_output(::MultiPhaseStateFlow, x)
    return x
end

function _format_final_output(::MultiPhaseHamiltonianFlow, state_tuple)
    x, p = state_tuple
    return vcat(x, p)
end

# ==============================================================================
# Public Callable Interfaces
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Convenience call for `MultiPhaseStateFlow` with point configuration.

Builds a `PointConfig` internally and evaluates the multi-phase flow.

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

See also: [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@ref), [`CTFlows.Common.PointConfig`](@ref).
"""
function (mpf::MultiPhaseStateFlow)(
    t0::Real,
    x0,
    tf::Real;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
)
    config = Common.PointConfig(t0, x0, tf)
    return _evaluate_multiphase(mpf, config; variable=variable, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Convenience call for `MultiPhaseStateFlow` with trajectory configuration.

Builds a `TrajectoryConfig` internally and evaluates the multi-phase flow,
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

See also: [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@ref), [`CTFlows.Common.TrajectoryConfig`](@ref).
"""
function (mpf::MultiPhaseStateFlow)(
    tspan::Tuple{Real, Real},
    x0;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
)
    config = Common.TrajectoryConfig(tspan, x0)
    return _evaluate_multiphase(mpf, config; variable=variable, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Convenience call for `MultiPhaseHamiltonianFlow` with point configuration.

Builds a `HamiltonianPointConfig` internally and evaluates the multi-phase flow.

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

See also: [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref), [`CTFlows.Common.HamiltonianPointConfig`](@ref).
"""
function (mpf::MultiPhaseHamiltonianFlow)(
    t0::Real,
    x0,
    p0,
    tf::Real;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
)
    config = Common.HamiltonianPointConfig(t0, x0, p0, tf)
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

See also: [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref), [`CTFlows.Common.HamiltonianTrajectoryConfig`](@ref).
"""
function (mpf::MultiPhaseHamiltonianFlow)(
    tspan::Tuple{Real, Real},
    x0,
    p0;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
)
    config = Common.HamiltonianTrajectoryConfig(tspan, x0, p0)
    return _evaluate_multiphase(mpf, config; variable=variable, unsafe=unsafe)
end
