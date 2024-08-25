function __concat_rhs(
    F::AbstractFlow{D,U},
    G::AbstractFlow{D,U},
    t_switch::Time,
) where {D,U}
    function rhs!(du::D, u::U, p::Variable, t::Time)
        t < t_switch ? F.rhs!(du, u, p, t) : G.rhs!(du, u, p, t)
    end
    return rhs!
end

function __concat_rhs(F::VectorFieldFlow, G::VectorFieldFlow, t_switch::Time)
    return (x::State, v::Variable, t::Time) ->
        (t < t_switch ? F.rhs(x, v, t) : G.rhs(x, v, t))
end

function __concat_rhs(F::ODEFlow, G::ODEFlow, t_switch::Time)
    return (x, v, t::Time) -> (t < t_switch ? F.rhs(x, v, t) : G.rhs(x, v, t))
end

function __concat_tstops(F::AbstractFlow, G::AbstractFlow, t_switch::Time)
    tstops = F.tstops
    append!(tstops, G.tstops)
    append!(tstops, t_switch)
    tstops = unique(sort(tstops))
    return tstops
end

function __concat_feedback_control(F::AbstractFlow, G::AbstractFlow, t_switch::Time)
    function _feedback_control(t, x, u, v)
        t < t_switch ? F.feedback_control(t, x, u, v) : G.feedback_control(t, x, u, v)
    end
    feedback_control = ControlLaw(_feedback_control, NonAutonomous, NonFixed)
    return feedback_control
end

function __concat_jumps(
    F::AbstractFlow,
    G::AbstractFlow,
    jump::Union{Nothing,Tuple{Time,Any}} = nothing,
)
    jumps = F.jumps
    append!(jumps, G.jumps)
    !isnothing(jump) && push!(jumps, jump)
    return jumps
end

# --------------------------------------------------------------------------------------------
# concatenate two flows with a prescribed switching time
function concatenate(F::TF, g::Tuple{ctNumber,TF})::TF where {TF<:AbstractFlow}

    t_switch, G = g
    rhs! = __concat_rhs(F, G, t_switch)       # concatenation of the right and sides
    tstops = __concat_tstops(F, G, t_switch)    # times to break integration
    jumps = __concat_jumps(F, G) # jumps
    return TF(F.f, rhs!, tstops, jumps)  # we choose default values and options of F

end

function concatenate(F::TF, g::Tuple{ctNumber,Any,TF})::TF where {TF<:AbstractFlow}

    t_switch, η_switch, G = g
    rhs! = __concat_rhs(F, G, t_switch)       # concatenation of the right and sides
    tstops = __concat_tstops(F, G, t_switch)    # times to break integration
    jumps = __concat_jumps(F, G, (t_switch, η_switch)) # jumps
    return TF(F.f, rhs!, tstops, jumps)  # we choose default values and options of F

end

# --------------------------------------------------------------------------------------------
# concatenate two flows with a prescribed switching time
function concatenate(F::TF, g::Tuple{ctNumber,TF})::TF where {TF<:OptimalControlFlow}

    t_switch, G = g
    rhs! = __concat_rhs(F, G, t_switch)               # concatenation of the right and sides
    tstops = __concat_tstops(F, G, t_switch)            # times to break integration
    feedback_u = __concat_feedback_control(F, G, t_switch)  # concatenation of the feedback control
    jumps = __concat_jumps(F, G) # jumps
    return OptimalControlFlow(F.f, rhs!, feedback_u, F.ocp, F.kwargs_Flow, tstops, jumps) # we choose default values and options of F

end

function concatenate(F::TF, g::Tuple{ctNumber,Any,TF})::TF where {TF<:OptimalControlFlow}

    t_switch, η_switch, G = g
    rhs! = __concat_rhs(F, G, t_switch)               # concatenation of the right and sides
    tstops = __concat_tstops(F, G, t_switch)            # times to break integration
    feedback_u = __concat_feedback_control(F, G, t_switch)  # concatenation of the feedback control
    jumps = __concat_jumps(F, G, (t_switch, η_switch)) # jumps
    return OptimalControlFlow(F.f, rhs!, feedback_u, F.ocp, F.kwargs_Flow, tstops, jumps)  # we choose default values and options of F

end

# --------------------------------------------------------------------------------------------
*(F::TF, g::Tuple{ctNumber,TF}) where {TF<:AbstractFlow} = concatenate(F, g)
*(F::TF, g::Tuple{ctNumber,Any,TF}) where {TF<:AbstractFlow} = concatenate(F, g)
