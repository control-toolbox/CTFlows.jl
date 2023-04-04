# ---------------------------------------------------------------------------------------------------
#
struct ClassicalFlow{D, U, T}
    f::Function     # f(args..., rhs)
    rhs!::Function   # OrdinaryDiffEq rhs
    tstops::Times
    ClassicalFlow{D, U, T}(f, rhs!) where {D, U, T} = new{D, U, T}(f, rhs!, Vector{Time}())
    ClassicalFlow{D, U, T}(f, rhs!, tstops) where {D, U, T} = new{D, U, T}(f, rhs!, tstops)
end

# call F.f
(F::ClassicalFlow)(args...; kwargs...) = F.f(args...; _t_stops_interne=F.tstops, DiffEqRHS=F.rhs!, kwargs...)

# ---------------------------------------------------------------------------------------------------
#
# to specify D, U and T is useful to insure coherence for instance when concatenating two flows
struct OptimalControlFlow{D, U, T}
    # 
    f::Function      # the mere function which depends on the kind of flow (Hamiltonian or classical) 
                     # this function takes a right and side as input
    rhs!::Function   # the right and side of the form: rhs!(du::D, u::U, p, t::T)
    tstops::Times    # specific times where the integrator must stop
                     # useful when the rhs is not smooth at such times
    feedback_control::ControlFunction # the control law in feedback form, that is u(t, x, p)
    control_dimension::Dimension
    control_names::Vector{String}
    state_dimension::Dimension
    state_names::Vector{String}
    time_name::String

    # constructor
    function OptimalControlFlow{D, U, T}(f::Function, rhs!::Function, u::Function, m::Dimension, 
        u_labels::Vector{String}, n::Dimension, x_labels::Vector{String}, time_name::String,
        tstops::Times=Vector{Time}()) where {D, U, T} 
        return new{D, U, T}(f, rhs!, tstops, u, m, u_labels, n, x_labels, time_name)
    end

end

# call F.f
(F::OptimalControlFlow)(args...; kwargs...) = F.f(args...; _t_stops_interne=F.tstops, DiffEqRHS=F.rhs!, kwargs...)

# # call F.f and then, construct a solution which contains all the need information for plotting
function (F::OptimalControlFlow)(tspan::Tuple{Time,Time}, args...; kwargs...) 
    ode_sol = F.f(tspan, args...; _t_stops_interne=F.tstops, DiffEqRHS=F.rhs!, kwargs...)
    ocfs = OptimalControlFlowSolution(ode_sol, F.feedback_control, F.control_dimension,
            F.control_names, F.state_dimension, F.state_names, F.time_name)
    return ocfs
end

"""
$(TYPEDSIGNATURES)

The right and side from a Hamiltonian is a Hamiltonian vector field.
"""
function rhs(h::Hamiltonian)
    function rhs!(dz::DCoTangent, z::CoTangent, λ, t::Time)
        n = size(z, 1) ÷ 2
        foo = isempty(λ) ? (z -> h(t, z[1:n], z[n+1:2*n])) : (z -> h(t, z[1:n], z[n+1:2*n], λ...))
        dh = ctgradient(foo, z)
        dz[1:n] = dh[n+1:2n]
        dz[n+1:2n] = -dh[1:n]
    end
    return rhs!
end

"""
$(TYPEDSIGNATURES)

Returns a function that solves ODE problem associated to Hamiltonian vector field.
"""
function hamiltonian_usage(alg, abstol, reltol, saveat; kwargs_Flow...)

    function f(tspan::Tuple{Time,Time}, x0::State, p0::Adjoint, λ...; _t_stops_interne, DiffEqRHS, tstops=__tstops(), kwargs...)
        z0 = [x0; p0]
        args = isempty(λ) ? (DiffEqRHS, z0, tspan) : (DiffEqRHS, z0, tspan, λ)
        ode = OrdinaryDiffEq.ODEProblem(args...)
        append!(_t_stops_interne, tstops); t_stops_all = unique(sort(_t_stops_interne))
        sol = OrdinaryDiffEq.solve(ode, alg=alg, abstol=abstol, reltol=reltol, saveat=saveat, tstops=t_stops_all; kwargs_Flow..., kwargs...)
        return sol
    end

    function f(t0::Time, x0::State, p0::Adjoint, tf::Time, λ...; _t_stops_interne, DiffEqRHS, tstops=__tstops(), kwargs...)
        sol = f((t0, tf), x0, p0, λ...; _t_stops_interne=_t_stops_interne, DiffEqRHS=DiffEqRHS, tstops=tstops, kwargs...)
        n = size(x0, 1)
        return sol[1:n, end], sol[n+1:2*n, end]
    end

    function f(tspan::Tuple{Time,Time}, x0::MyNumber, p0::MyNumber, λ...; _t_stops_interne, DiffEqRHS, tstops=__tstops(), kwargs...)
        return f(tspan, [x0], [p0], λ...; _t_stops_interne=_t_stops_interne, DiffEqRHS=DiffEqRHS, tstops=tstops, kwargs...)
    end

    function f(t0::Time, x0::MyNumber, p0::MyNumber, tf::Time, λ...; _t_stops_interne, DiffEqRHS, tstops=__tstops(), kwargs...)
        xf, pf = f(t0, [x0], [p0], tf, λ...; _t_stops_interne=_t_stops_interne, DiffEqRHS=DiffEqRHS, tstops=tstops, kwargs...)
        return xf[1], pf[1]
    end

    return f

end

"""
$(TYPEDSIGNATURES)

Returns a function that solves ODE problem associated to classical vector field.
"""
function classical_usage(alg, abstol, reltol, saveat; kwargs_Flow...)

    # kwargs has priority wrt kwargs_flow
    function f(tspan::Tuple{Time,Time}, x0::State, λ...; _t_stops_interne, DiffEqRHS, tstops=__tstops(), kwargs...)
        args = isempty(λ) ? (DiffEqRHS, x0, tspan) : (DiffEqRHS, x0, tspan, λ)
        ode = OrdinaryDiffEq.ODEProblem(args...)
        append!(_t_stops_interne, tstops); t_stops_all = unique(sort(_t_stops_interne))
        sol = OrdinaryDiffEq.solve(ode, alg=alg, abstol=abstol, reltol=reltol, saveat=saveat, tstops=t_stops_all; kwargs_Flow..., kwargs...)
        return sol
    end

    function f(t0::Time, x0::State, t::Time, λ...; _t_stops_interne, DiffEqRHS, tstops=__tstops(), kwargs...)
        sol = f((t0, t), x0, λ...; _t_stops_interne=_t_stops_interne, DiffEqRHS=DiffEqRHS, tstops=tstops, kwargs...)
        n = size(x0, 1)
        return sol[1:n, end]
    end

    function f(tspan::Tuple{Time,Time}, x0::MyNumber, λ...; _t_stops_interne, DiffEqRHS, tstops=__tstops(), kwargs...)
        return f(tspan, [x0], λ...; _t_stops_interne=_t_stops_interne, DiffEqRHS=DiffEqRHS, tstops=tstops, kwargs...)
    end

    function f(t0::Time, x0::MyNumber, tf::Time, λ...; _t_stops_interne, DiffEqRHS, tstops=__tstops(), kwargs...)
        xf = f(t0, [x0], tf, λ...; _t_stops_interne=_t_stops_interne, DiffEqRHS=DiffEqRHS, tstops=tstops, kwargs...)
        return xf[1]
    end

    return f

end