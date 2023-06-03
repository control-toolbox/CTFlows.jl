# ---------------------------------------------------------------------------------------------------
struct VectorFieldFlow <: AbstractFlow{DState, State}
    f::Function     # f(args..., rhs): compute the flow
    rhs::Function  # OrdinaryDiffEq rhs
    tstops::Times   # stopping times
    jumps::Vector{Tuple{Time, State}} # specific jumps the integrator must perform
    function VectorFieldFlow(f, rhs, 
        tstops::Times=Vector{Time}(),
        jumps::Vector{Tuple{Time, State}}=Vector{Tuple{Time, State}}())
        return new(f, rhs, tstops, jumps)
    end
end

# call F.f
(F::VectorFieldFlow)(args...; kwargs...) = begin
    F.f(args...; jumps=F.jumps, _t_stops_interne=F.tstops, DiffEqRHS=F.rhs, kwargs...)
end

"""
$(TYPEDSIGNATURES)

Returns a function that solves ODE problem associated to classical vector field.
"""
function vector_field_usage(alg, abstol, reltol, saveat; kwargs_Flow...)

    # kwargs has priority wrt kwargs_flow
    function f(tspan::Tuple{Time,Time}, x0::State, v::Variable=__variable(); 
        jumps, _t_stops_interne, DiffEqRHS, tstops=__tstops(), callback=__callback(), kwargs...)

        # ode
        ode = OrdinaryDiffEq.ODEProblem(DiffEqRHS, x0, tspan, v)

        # jumps and callbacks
        cb, t_stops_all = __callbacks(callback, jumps, nothing, _t_stops_interne, tstops)

        # solve
        sol = OrdinaryDiffEq.solve(ode, 
            alg=alg, abstol=abstol, reltol=reltol, saveat=saveat, tstops=t_stops_all, callback=cb; 
            kwargs_Flow..., kwargs...)

        return sol

    end

    function f(t0::Time, x0::State, t::Time, v::Variable=__variable(); kwargs...)
        sol = f((t0, t), x0, v; kwargs...)
        return sol.u[end]
    end

    return f

end

# --------------------------------------------------------------------------------------------
# Flow of a vector field
function Flow(vf::VectorField; alg=__alg(), abstol=__abstol(), reltol=__reltol(), saveat=__saveat(), kwargs_Flow...)
    f = vector_field_usage(alg, abstol, reltol, saveat; kwargs_Flow...)
    rhs = (x::State, v::Variable, t::Time) -> vf(t, x, v)
    return VectorFieldFlow(f, rhs)
end
