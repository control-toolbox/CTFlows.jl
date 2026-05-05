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
        
        jump = get_jump(mpf, i)
        if i < n_ph && !isnothing(jump)
            current_state = _apply_jump(mpf, i, current_state)
        end
    end
    
    return _format_final_output(mpf, current_state)
end

function _evaluate_multiphase(mpf, config::Common.AbstractTrajectoryConfig; variable, unsafe)
    t0, tf = Common.tspan(config)
    current_state = _extract_initial_state(config)
    current_t = t0
    n_ph = n_phases(mpf)
    
    results = []
    
    for i in 1:n_ph
        t_end = (i < n_ph) ? get_switching_time(mpf, i) : tf
        
        segment_result = _evaluate_phase(get_flow(mpf, i), current_t, t_end, current_state, config; variable=variable, unsafe=unsafe)
        push!(results, segment_result)
        
        current_state = _extract_final_state(mpf, segment_result, current_state)
        current_t = t_end
        
        jump = get_jump(mpf, i)
        if i < n_ph && !isnothing(jump)
            current_state = _apply_jump(mpf, i, current_state)
        end
    end
    
    return _merge_segments(mpf, results) # Placeholder
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

function _merge_segments(mpf, results)
    # TODO: merge segments using SciMLBase extension
    return results[1] # Placeholder
end

# ==============================================================================
# Public Callable Interfaces
# ==============================================================================

# TODO: docstring
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

# TODO: docstring
function (mpf::MultiPhaseStateFlow)(
    tspan::Tuple{Real, Real},
    x0;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
)
    config = Common.TrajectoryConfig(tspan, x0)
    return _evaluate_multiphase(mpf, config; variable=variable, unsafe=unsafe)
end

# TODO: docstring
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

# TODO: docstring
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
