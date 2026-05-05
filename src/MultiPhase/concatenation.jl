# TODO: docstring
function Base.:*(f1::Flows.StateFlow, (t_switch, f2)::Tuple{Real, Flows.StateFlow})
    return MultiPhaseStateFlow([f1, f2], [t_switch], [nothing])
end

# TODO: docstring
function Base.:*(f1::Flows.StateFlow, (t_switch, jump, f2)::Tuple{Real, Any, Flows.StateFlow})
    return MultiPhaseStateFlow([f1, f2], [t_switch], [jump])
end

# TODO: docstring
function Base.:*(f1::Flows.HamiltonianFlow, (t_switch, f2)::Tuple{Real, Flows.HamiltonianFlow})
    return MultiPhaseHamiltonianFlow([f1, f2], [t_switch], [nothing])
end

# TODO: docstring
function Base.:*(f1::Flows.HamiltonianFlow, (t_switch, jump, f2)::Tuple{Real, Any, Flows.HamiltonianFlow})
    return MultiPhaseHamiltonianFlow([f1, f2], [t_switch], [jump])
end

# TODO: docstring
function Base.:*(f1::Flows.HamiltonianFlow, (t_switch, jump_x, jump_p, f2)::Tuple{Real, Any, Any, Flows.HamiltonianFlow})
    return MultiPhaseHamiltonianFlow([f1, f2], [t_switch], [(jump_x, jump_p)])
end

# TODO: docstring
function Base.:*(mpf::MultiPhaseStateFlow, (t_switch, f2)::Tuple{Real, Flows.StateFlow})
    return MultiPhaseStateFlow([mpf.flows..., f2], [mpf.switching_times..., t_switch], [mpf.jumps..., nothing])
end

# TODO: docstring
function Base.:*(mpf::MultiPhaseStateFlow, (t_switch, jump, f2)::Tuple{Real, Any, Flows.StateFlow})
    return MultiPhaseStateFlow([mpf.flows..., f2], [mpf.switching_times..., t_switch], [mpf.jumps..., jump])
end

# TODO: docstring
function Base.:*(mpf::MultiPhaseHamiltonianFlow, (t_switch, f2)::Tuple{Real, Flows.HamiltonianFlow})
    return MultiPhaseHamiltonianFlow([mpf.flows..., f2], [mpf.switching_times..., t_switch], [mpf.jumps..., nothing])
end

# TODO: docstring
function Base.:*(mpf::MultiPhaseHamiltonianFlow, (t_switch, jump, f2)::Tuple{Real, Any, Flows.HamiltonianFlow})
    return MultiPhaseHamiltonianFlow([mpf.flows..., f2], [mpf.switching_times..., t_switch], [mpf.jumps..., jump])
end
