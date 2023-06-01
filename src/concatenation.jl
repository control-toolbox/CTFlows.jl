function __concat_rhs(F::AbstractFlow{D, U, V, T}, G::AbstractFlow{D, U, V, T}, t_switch) where {D, U, V, T}
    function rhs!(du::D, u::U, p::V, t::T)
        t < t_switch ? F.rhs!(du, u, p, t) : G.rhs!(du, u, p, t)
    end
    return rhs!
end

function __concat_rhs(F::ODEFlow, G::ODEFlow, t_switch)
    return (x, v, t) -> (t < t_switch ? F.rhs(x, v, t) : G.rhs(x, v, t))
end

function __concat_tstops(F::AbstractFlow, G::AbstractFlow, t_switch)
    tstops = F.tstops
    append!(tstops, G.tstops)
    append!(tstops, t_switch)
    tstops = unique(sort(tstops))
    return tstops
end

function __concat_feedback_control(F::AbstractFlow, G::AbstractFlow, t_switch)
    function _feedback_control(t, x, u, v)
        t < t_switch ? F.feedback_control(t, x, u, v) : G.feedback_control(t, x, u, v)
    end
    feedback_control = ControlLaw(_feedback_control, NonAutonomous, NonFixed)
    return feedback_control
end

# --------------------------------------------------------------------------------------------
# concatenate two flows with a prescribed switching time
function concatenate(F::TF, g::Tuple{ctNumber, TF}) where {TF<:AbstractFlow}

    t_switch, G = g
    rhs!   = __concat_rhs(F, G, t_switch)       # concatenation of the right and sides
    tstops = __concat_tstops(F, G, t_switch)    # times to break integration
    return TF(F.f, rhs!, tstops)  # we choose default values and options of F

end

*(F::TF, g::Tuple{ctNumber, TF}) where {TF<:AbstractFlow} = concatenate(F, g)

# --------------------------------------------------------------------------------------------
# concatenate two flows with a prescribed switching time
function concatenate(F::TF, g::Tuple{ctNumber, TF}) where {TF<:OptimalControlFlow}

    t_switch, G = g
    rhs!       = __concat_rhs(F, G, t_switch)               # concatenation of the right and sides
    tstops     = __concat_tstops(F, G, t_switch)            # times to break integration
    feedback_u = __concat_feedback_control(F, G, t_switch)  # concatenation of the feedback control
    return TF(F.f, rhs!, feedback_u, F.ocp, tstops) # we choose default values and options of F

end

*(F::TF, g::Tuple{ctNumber, TF}) where {TF<:OptimalControlFlow} = concatenate(F, g)