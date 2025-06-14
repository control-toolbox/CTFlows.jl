"""
$(TYPEDSIGNATURES)

Constructs the combined callback and stopping times for flow integration.

This internal utility assembles a `CallbackSet` for the ODE integrator, handling both:
- discrete **jumps** in the state or costate (via `VectorContinuousCallback`), and
- user-defined callbacks.

Additionally, it merges stopping times into a sorted, unique list used for `tstops`.

# Arguments
- `callback`: A user-defined callback (e.g. for logging or monitoring).
- `jumps`: A vector of tuples `(t, η)` representing discrete updates at time `t`.
- `_rg`: An optional index range where the jump `η` should be applied (e.g. only to `p` in `(x, p)`).
- `_t_stops_interne`: Internal list of event times (mutable, extended in place).
- `tstops`: Additional stopping times from the outer solver context.

# Returns
- `cb`: A `CallbackSet` combining jumps and user callback.
- `t_stops_all`: Sorted and deduplicated list of all stopping times.

# Example
```julia-repl
julia> cb, tstops = __callbacks(mycb, [(1.0, [0.0, -1.0])], 3:4, [], [2.0])
```
"""
function __callbacks(callback, jumps, _rg, _t_stops_interne, tstops)

    # jumps and callbacks
    cb = nothing
    if size(jumps, 1) > 0
        t_jumps = [t for (t, _) in jumps]
        η_jumps = [η for (_, η) in jumps]

        # add the jump η from η_jumps on p with z = (x, p) at time t from t_jumps
        function condition(out, u, t, integrator)
            return out[:] = t_jumps .- t
        end

        function affect!(integrator, event_index)
            return if isnothing(_rg)
                integrator.u += η_jumps[event_index]
            else
                integrator.u[_rg] += η_jumps[event_index]
            end
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
