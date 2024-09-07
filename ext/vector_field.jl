"""
$(TYPEDSIGNATURES)

Returns a function that solves ODE problem associated to classical vector field.
"""
function vector_field_usage(alg, abstol, reltol, saveat; kwargs_Flow...)

    # kwargs has priority wrt kwargs_flow
    function f(
        tspan::Tuple{Time,Time},
        x0::State,
        v::Variable=__variable(x0);
        jumps,
        _t_stops_interne,
        DiffEqRHS,
        tstops=__tstops(),
        callback=__callback(),
        kwargs...,
    )

        # ode
        ode = OrdinaryDiffEq.ODEProblem(DiffEqRHS, x0, tspan, v)

        # jumps and callbacks
        cb, t_stops_all = __callbacks(callback, jumps, nothing, _t_stops_interne, tstops)

        # solve
        sol = OrdinaryDiffEq.solve(
            ode;
            alg=alg,
            abstol=abstol,
            reltol=reltol,
            saveat=saveat,
            tstops=t_stops_all,
            callback=cb,
            kwargs_Flow...,
            kwargs...,
        )

        return sol
    end

    function f(t0::Time, x0::State, t::Time, v::Variable=__variable(x0); kwargs...)
        sol = f((t0, t), x0, v; kwargs...)
        return sol.u[end]
    end

    return f
end

# --------------------------------------------------------------------------------------------
# Flow of a vector field
function CTFlows.Flow(
    vf::VectorField;
    alg=__alg(),
    abstol=__abstol(),
    reltol=__reltol(),
    saveat=__saveat(),
    kwargs_Flow...,
)
    f = vector_field_usage(alg, abstol, reltol, saveat; kwargs_Flow...)
    rhs = (x::State, v::Variable, t::Time) -> vf(t, x, v)
    return VectorFieldFlow(f, rhs)
end
