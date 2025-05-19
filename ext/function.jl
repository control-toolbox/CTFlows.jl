"""
$(TYPEDSIGNATURES)

Returns a function that solves any ODE problem with OrdinaryDiffEq.
"""
function ode_usage(alg, abstol, reltol, saveat, internalnorm; kwargs_Flow...)

    # kwargs has priority wrt kwargs_flow
    function f(
        tspan::Tuple{Time,Time},
        x0,
        v=nothing;
        jumps,
        _t_stops_interne,
        DiffEqRHS,
        tstops=__tstops(),
        callback=__callback(),
        kwargs...,
    )

        # ode
        ode = if isnothing(v)
            OrdinaryDiffEq.ODEProblem(DiffEqRHS, x0, tspan)
        else
            OrdinaryDiffEq.ODEProblem(DiffEqRHS, x0, tspan, v)
        end

        # jumps and callbacks
        cb, t_stops_all = __callbacks(callback, jumps, nothing, _t_stops_interne, tstops)

        # solve
        sol = OrdinaryDiffEq.solve(
            ode;
            alg=alg,
            abstol=abstol,
            reltol=reltol,
            saveat=saveat,
            internalnorm=internalnorm,
            tstops=t_stops_all,
            callback=cb,
            kwargs_Flow...,
            kwargs...,
        )

        return sol
    end

    function f(t0::Time, x0, tf::Time, v=nothing; kwargs...)
        sol = f((t0, tf), x0, v; kwargs...)
        return sol.u[end]
    end

    return f
end

# --------------------------------------------------------------------------------------------
function CTFlows.Flow(
    dyn::Function;
    autonomous=__autonomous(),
    variable=__variable(),
    alg=__alg(),
    abstol=__abstol(),
    reltol=__reltol(),
    saveat=__saveat(),
    internalnorm=__internalnorm(),
    kwargs_Flow...,
)
    #
    f = ode_usage(alg, abstol, reltol, saveat, internalnorm; kwargs_Flow...)
    rhs = @match (!autonomous, variable) begin
        (true, true) => ((x, v, t::Time) -> dyn(t, x, v))
        (true, false) => ((x, v, t::Time) -> dyn(t, x))
        (false, true) => ((x, v, t::Time) -> dyn(x, v))
        (false, false) => ((x, v, t::Time) -> dyn(x))
    end
    #
    return ODEFlow(f, rhs)
end
