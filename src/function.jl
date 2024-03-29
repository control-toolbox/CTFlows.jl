# ---------------------------------------------------------------------------------------------------
struct ODEFlow <: AbstractFlow{Any, Any}
    f::Function     # f(args..., rhs): compute the flow
    rhs::Function   # OrdinaryDiffEq rhs
    tstops::Times   # stopping times
    jumps::Vector{Tuple{Time, Any}} # specific jumps the integrator must perform
    function ODEFlow(f, rhs!, 
        tstops::Times=Vector{Time}(),
        jumps::Vector{Tuple{Time, Any}}=Vector{Tuple{Time, Any}}())
        return new(f, rhs!, tstops, jumps)
    end
end

(F::ODEFlow)(args...; kwargs...) = begin
    F.f(args...; jumps=F.jumps, _t_stops_interne=F.tstops, DiffEqRHS=F.rhs, kwargs...)
end

"""
$(TYPEDSIGNATURES)

Returns a function that solves any ODE problem with OrdinaryDiffEq.
"""
function ode_usage(alg, abstol, reltol, saveat; kwargs_Flow...)

    # kwargs has priority wrt kwargs_flow
    function f(tspan::Tuple{Time,Time}, x0, v=nothing; 
        jumps, _t_stops_interne, DiffEqRHS, tstops=__tstops(), callback=__callback(), kwargs...)

        # ode
        ode = OrdinaryDiffEq.ODEProblem(DiffEqRHS, x0, tspan, v===nothing ? () : v)

        # jumps and callbacks
        cb, t_stops_all = __callbacks(callback, jumps, nothing, _t_stops_interne, tstops)

        # solve
        sol = OrdinaryDiffEq.solve(ode, 
            alg=alg, abstol=abstol, reltol=reltol, saveat=saveat, tstops=t_stops_all, callback=cb; 
            kwargs_Flow..., kwargs...)

        return sol
    end

    function f(t0::Time, x0, tf::Time, v=nothing; kwargs...)
        sol = f((t0, tf), x0, v; kwargs...)
        return sol.u[end]
    end

    return f

end

# --------------------------------------------------------------------------------------------
function Flow(dyn::Function; autonomous=true, variable=false,
    alg=__alg(), abstol=__abstol(), reltol=__reltol(), saveat=__saveat(), kwargs_Flow...)
    #
    f = ode_usage(alg, abstol, reltol, saveat; kwargs_Flow...)
    rhs = @match (!autonomous, variable) begin
        (true, true)  => ((x, v, t::Time) -> dyn(t, x, v))
        (true, false) => ((x, v, t::Time) -> dyn(t, x))
        (false, true) => ((x, v, t::Time) -> dyn(x, v))
        (false, false)=> ((x, v, t::Time) -> dyn(x))
    end
    #
    return ODEFlow(f, rhs)
end
