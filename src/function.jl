# ---------------------------------------------------------------------------------------------------
struct ODEFlow <: AbstractFlow{Any, Any, Any, Any}
    f::Function     # f(args..., rhs): compute the flow
    rhs::Function   # OrdinaryDiffEq rhs
    tstops::Times   # stopping times
    ODEFlow(f, rhs)         = new(f, rhs, Vector{Time}())
    ODEFlow(f, rhs, tstops) = new(f, rhs, tstops)
end

(F::ODEFlow)(args...; kwargs...) = F.f(args...; _t_stops_interne=F.tstops, DiffEqRHS=F.rhs, kwargs...)

"""
$(TYPEDSIGNATURES)

Returns a function that solves any ODE problem with OrdinaryDiffEq.
"""
function ode_usage(alg, abstol, reltol, saveat; kwargs_Flow...)

    # kwargs has priority wrt kwargs_flow
    function f(tspan::Tuple{Time,Time}, x0, v=nothing; _t_stops_interne, DiffEqRHS, tstops=__tstops(), kwargs...)
        ode = OrdinaryDiffEq.ODEProblem(DiffEqRHS, x0, tspan, v===nothing ? () : v)
        append!(_t_stops_interne, tstops); t_stops_all = unique(sort(_t_stops_interne))
        sol = OrdinaryDiffEq.solve(ode, alg=alg, abstol=abstol, reltol=reltol, saveat=saveat, tstops=t_stops_all; kwargs_Flow..., kwargs...)
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
        (true, true)  => ((x, v, t) -> dyn(t, x, v))
        (true, false) => ((x, v, t) -> dyn(t, x))
        (false, true) => ((x, v, t) -> dyn(x, v))
        (false, false)=> ((x, v, t) -> dyn(x))
    end
    #
    return ODEFlow(f, rhs)
end
