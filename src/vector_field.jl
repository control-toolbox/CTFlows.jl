# ---------------------------------------------------------------------------------------------------
struct VectorFieldFlow{D, U, V, T} <: AbstractFlow{D, U, V, T}
    f::Function     # f(args..., rhs): compute the flow
    rhs!::Function  # OrdinaryDiffEq rhs
    tstops::Times   # stopping times
    VectorFieldFlow{D, U, V, T}(f, rhs!) where {D, U, V, T} = new{D, U, V, T}(f, rhs!, Vector{Time}())
    VectorFieldFlow{D, U, V, T}(f, rhs!, tstops) where {D, U, V, T} = new{D, U, V, T}(f, rhs!, tstops)
end

# call F.f
(F::VectorFieldFlow)(args...; kwargs...) = F.f(args...; _t_stops_interne=F.tstops, DiffEqRHS=F.rhs!, kwargs...)

"""
$(TYPEDSIGNATURES)

Returns a function that solves ODE problem associated to classical vector field.
"""
function vector_field_usage(alg, abstol, reltol, saveat; kwargs_Flow...)

    # kwargs has priority wrt kwargs_flow
    function f(tspan::Tuple{Time,Time}, x0::State, v::Variable=__variable(); _t_stops_interne, DiffEqRHS, tstops=__tstops(), kwargs...)
        ode = OrdinaryDiffEq.ODEProblem(DiffEqRHS, x0, tspan, v)
        append!(_t_stops_interne, tstops); t_stops_all = unique(sort(_t_stops_interne))
        sol = OrdinaryDiffEq.solve(ode, alg=alg, abstol=abstol, reltol=reltol, saveat=saveat, tstops=t_stops_all; kwargs_Flow..., kwargs...)
        return sol
    end

    function f(t0::Time, x0::State, t::Time, v::Variable=__variable(); kwargs...)
        sol = f((t0, t), x0, v; kwargs...)
        n = size(x0, 1)
        return sol[rg(1,n), end]
    end

    function f(tspan::Tuple{Time,Time}, x0::ctNumber, v::Variable=__variable(); kwargs...)
        return f(tspan, [x0], v; kwargs...)
    end

    function f(t0::Time, x0::ctNumber, tf::Time, v::Variable=__variable(); kwargs...)
        xf = f(t0, [x0], tf, v; kwargs...)
        return xf[1]
    end

    return f

end

# --------------------------------------------------------------------------------------------
# Flow of a vector field
function Flow(vf::VectorField; alg=__alg(), abstol=__abstol(), 
    reltol=__reltol(), saveat=__saveat(), kwargs_Flow...)
    #
    f = vector_field_usage(alg, abstol, reltol, saveat; kwargs_Flow...)

    function rhs!(dx::DState, x::State, v::Variable, t::Time)
        n = size(x, 1)
        dx[rg(1,n)] = vf(t, x[rg(1,n)], v)
    end

    return VectorFieldFlow{DState, State, Variable, Time}(f, rhs!)

end
