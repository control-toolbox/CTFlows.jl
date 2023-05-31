# --------------------------------------------------------------------------------------------
#
# concatenate two flows with a prescribed switching time
function concatenate(F::AbstractFlow{D, U, T}, g::Tuple{ctNumber, AbstractFlow{D, U, T}}) where {D, U, T}

    # concatenation of the right and sides
    t_switch, G = g
    function rhs!(du::D, u::U, p, t::T)
        t < t_switch ? F.rhs!(du, u, p, t) : G.rhs!(du, u, p, t)
    end

    # times to break integration 
    tstops = F.tstops
    append!(tstops, G.tstops)
    append!(tstops, t_switch)
    tstops = unique(sort(tstops))
    
    # we choose default values and options of F
    return AbstractFlow(typeof(F), F.f, rhs!, tstops)

end

*(F::AbstractFlow{D, U, T}, g::Tuple{ctNumber, AbstractFlow{D, U, T}}) where {D, U, T} = concatenate(F, g)

# --------------------------------------------------------------------------------------------
#
# concatenate two flows with a prescribed switching time
function concatenate(F::OptimalControlFlow{D, U, T}, g::Tuple{ctNumber, OptimalControlFlow{D, U, T}}) where {D, U, T}

    # concatenation of the right and sides
    t_switch, G = g
    function rhs!(du::D, u::U, p, t::T)
        t < t_switch ? F.rhs!(du, u, p, t) : G.rhs!(du, u, p, t)
    end

    # times to break integration 
    tstops = F.tstops
    append!(tstops, G.tstops)
    append!(tstops, t_switch)
    tstops = unique(sort(tstops))

    # control law in feedback form: must be a ControlLaw
    # nonautonomous and vectorial usage for this function which only redirect the call
    function _feedback_control(t, x, u)
        t < t_switch ? F.feedback_control(t, x, u) : G.feedback_control(t, x, u)
    end
    feedback_control = ControlLaw(_feedback_control, NonAutonomous, Fixed)

    # we choose default values and options of F
    return OptimalControlFlow{D, U, T}(F.f, rhs!, feedback_control, F.ocp, tstops)

end

*(F:: OptimalControlFlow{D, U, T}, g::Tuple{ctNumber, OptimalControlFlow{D, U, T}}) where {D, U, T} = concatenate(F, g)