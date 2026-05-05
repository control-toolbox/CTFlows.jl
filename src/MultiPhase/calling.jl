# TODO: docstring
function (mpf::MultiPhaseStateFlow)(
    t0::Real,
    x0,
    tf::Real;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
)
    n_phases = length(mpf.flows)
    current_x = x0
    current_t = t0
    
    for i in 1:n_phases
        if i < n_phases
            t_end = mpf.switching_times[i]
        else
            t_end = tf
        end
        
        flow = mpf.flows[i]
        current_x = flow(current_t, current_x, t_end; variable=variable, unsafe=unsafe)
        current_t = t_end
        
        if i < n_phases && !isnothing(mpf.jumps[i])
            current_x = current_x + mpf.jumps[i]
        end
    end
    
    return current_x
end

# TODO: docstring
function (mpf::MultiPhaseStateFlow)(
    tspan::Tuple{Real, Real},
    x0;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
)
    n_phases = length(mpf.flows)
    t0, tf = tspan
    current_x = x0
    current_t = t0
    
    # For trajectory config, collect all segments
    # TODO: implement progressive merging for memory efficiency
    results = []
    
    for i in 1:n_phases
        if i < n_phases
            t_end = mpf.switching_times[i]
        else
            t_end = tf
        end
        
        flow = mpf.flows[i]
        segment = flow((current_t, t_end), current_x; variable=variable, unsafe=unsafe)
        push!(results, segment)
        current_x = Solutions.final_state(segment)
        current_t = t_end
        
        if i < n_phases && !isnothing(mpf.jumps[i])
            current_x = current_x + mpf.jumps[i]
        end
    end
    
    # TODO: merge segments using SciMLBase extension
    return results[1]  # Placeholder
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
    n_phases = length(mpf.flows)
    current_x = x0
    current_p = p0
    current_t = t0
    
    for i in 1:n_phases
        if i < n_phases
            t_end = mpf.switching_times[i]
        else
            t_end = tf
        end
        
        flow = mpf.flows[i]
        result = flow(current_t, current_x, current_p, t_end; variable=variable, unsafe=unsafe)
        current_x = result[1:length(current_x)]
        current_p = result[(length(current_x)+1):end]
        current_t = t_end
        
        if i < n_phases && !isnothing(mpf.jumps[i])
            jump = mpf.jumps[i]
            if jump isa Tuple
                current_x = current_x + jump[1]
                current_p = current_p + jump[2]
            else
                current_p = current_p + jump
            end
        end
    end
    
    return vcat(current_x, current_p)
end

# TODO: docstring
function (mpf::MultiPhaseHamiltonianFlow)(
    tspan::Tuple{Real, Real},
    x0,
    p0;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
)
    n_phases = length(mpf.flows)
    t0, tf = tspan
    current_x = x0
    current_p = p0
    current_t = t0
    
    # For trajectory config, collect all segments
    # TODO: implement progressive merging for memory efficiency
    results = []
    
    for i in 1:n_phases
        if i < n_phases
            t_end = mpf.switching_times[i]
        else
            t_end = tf
        end
        
        flow = mpf.flows[i]
        segment = flow((current_t, t_end), current_x, current_p; variable=variable, unsafe=unsafe)
        push!(results, segment)
        final = Solutions.final_state(segment)
        current_x = final[1:length(current_x)]
        current_p = final[(length(current_x)+1):end]
        current_t = t_end
        
        if i < n_phases && !isnothing(mpf.jumps[i])
            jump = mpf.jumps[i]
            if jump isa Tuple
                current_x = current_x + jump[1]
                current_p = current_p + jump[2]
            else
                current_p = current_p + jump
            end
        end
    end
    
    # TODO: merge segments using SciMLBase extension
    return results[1]  # Placeholder
end
