
# ---------------------------------------------------------------------------------------------------
function __callbacks(callback, jumps, _rg, _t_stops_interne, tstops)

    # jumps and callbacks
    cb = nothing
    if size(jumps, 1) > 0

        t_jumps = [t for (t, _) in jumps]
        η_jumps = [η for (_, η) in jumps]
        
        # add the jump η from η_jumps on p with z = (x, p) at time t from t_jumps
        function condition(out, u, t, integrator)
            out[:] = t_jumps.-t
        end

        function affect!(integrator, event_index)
            isnothing(_rg) ? integrator.u += η_jumps[event_index] : integrator.u[_rg] += η_jumps[event_index] 
        end

        cbjumps = VectorContinuousCallback(condition, affect!, size(jumps, 1))

        # add callback
        cb = CallbackSet(cbjumps, callback)

    else

        cb = callback

    end

    # tstops
    append!(_t_stops_interne, tstops)
    t_stops_all = unique(sort(_t_stops_interne))

    return cb, t_stops_all

end