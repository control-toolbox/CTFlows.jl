# ---------------------------------------------------------------------------------------------------
#
# to specify D, U and T is useful to insure consistency for instance when concatenating two flows
struct OptimalControlFlow{D, U, T} <: AbstractFlow{D, U, T}
    # 
    f::Function      # the mere function which depends on the kind of flow (Hamiltonian or classical) 
                     # this function takes a right and side as input
    rhs!::Function   # the right and side of the form: rhs!(du::D, u::U, p, t::T)
    tstops::Times    # specific times where the integrator must stop
                     # useful when the rhs is not smooth at such times
    feedback_control::ControlLaw # the control law in feedback form, that is u(t, x, p)
    ocp::OptimalControlModel # the optimal control problem

    # constructor
    function OptimalControlFlow{D, U, T}(f::Function, rhs!::Function, u::ControlLaw, ocp::OptimalControlModel, tstops::Times=Vector{Time}()) where {D, U, T} 
        return new{D, U, T}(f, rhs!, tstops, u, ocp)
    end

end

# call F.f
(F::OptimalControlFlow)(args...; kwargs...) = F.f(args...; _t_stops_interne=F.tstops, DiffEqRHS=F.rhs!, kwargs...)

# # call F.f and then, construct a solution which contains all the need information for plotting
function (F::OptimalControlFlow)(tspan::Tuple{Time,Time}, args...; kwargs...) 
    ode_sol = F.f(tspan, args...; _t_stops_interne=F.tstops, DiffEqRHS=F.rhs!, kwargs...)
    return OptimalControlFlowSolution(ode_sol, F.feedback_control, F.ocp)
end

"""
$(TYPEDSIGNATURES)

Constructs the Hamiltonian: 

H(t, x, p) = p f(t, x, u(t, x, p))
"""
function makeH(f::Dynamics, u::ControlLaw)
    return (t, x, p, v) -> p'*f(t, x, u(t, x, p, v), v)
end

"""
$(TYPEDSIGNATURES)

Constructs the Hamiltonian: 

H(t, x, p) = p ⋅ f(t, x, u(t, x, p)) + s p⁰ f⁰(t, x, u(t, x, p))
"""
function makeH(f::Dynamics, u::ControlLaw, f⁰::Lagrange, p⁰::ctNumber, s::ctNumber)
    function H(t, x, p, v)
        u_ = u(t, x, p, v)
        return p'*f(t, x, u_, v) + s*p⁰*f⁰(t, x, u_, v)
    end
    return H
end

"""
$(TYPEDSIGNATURES)

Constructs the Hamiltonian: 

H(t, x, p) = p ⋅ f(t, x, u(t, x, p)) + μ(t, x, p) ⋅ g(t, x, u(t, x, p))
"""
function makeH(f::Dynamics, u::ControlLaw, g::MixedConstraint, μ::Multiplier)
    function H(t, x, p, v)
        u_ = u(t, x, p, v)
        return p'*f(t, x, u_, v) + μ(t, x, p, v)'*g(t, x, u_, v)
    end
    return H
end

"""
$(TYPEDSIGNATURES)

Constructs the Hamiltonian: 

H(t, x, p) = p ⋅ f(t, x, u(t, x, p)) + s p⁰ f⁰(t, x, u(t, x, p)) + μ(t, x, p) ⋅ g(t, x, u(t, x, p))
"""
function makeH(f::Dynamics, u::ControlLaw, f⁰::Lagrange, p⁰::ctNumber, s::ctNumber, g::MixedConstraint, μ::Multiplier)
    function H(t, x, p, v)
        u_ = u(t, x, p, v)
        return p'*f(t, x, u_, v) + s*p⁰*f⁰(t, x, u_, v) + μ(t, x, p, v)'*g(t, x, u_, v)
    end
    return H
end

"""
$(TYPEDSIGNATURES)

Flow from an optimal control problem and a control function in feedback form.

# Example
```jldoctest
julia> f = Flow(ocp, (x, p) -> p)
```

!!! warning

    The time dependence of the control function must be consistent with the time dependence of the optimal control problem.
    The dimension of the output of the control function must be consistent with the dimension usage of the control of the optimal control problem.
"""
function Flow(ocp::OptimalControlModel{T, V}, u_::Function; alg=__alg(), abstol=__abstol(), 
    reltol=__reltol(), saveat=__saveat(), kwargs_Flow...) where {T, V}

    #  data
    p⁰ = -1.
    f  = ocp.dynamics
    f⁰ = ocp.lagrange
    s  = is_min(ocp) ? 1.0 : -1.0 #

    # construction of the Hamiltonian
    if f ≠ nothing
        u = ControlLaw(u_, T, V) # consistency is needed
        h = Hamiltonian(f⁰ ≠ nothing ? makeH(f, u, f⁰, p⁰, s) : makeH(f, u), NonAutonomous, NonFixed)
    else 
        error("no dynamics in ocp")
    end

    # right and side: same as for a flow from a Hamiltonian
    rhs! = rhs(h)

    # flow function
    f = hamiltonian_usage(alg, abstol, reltol, saveat; kwargs_Flow...)

    # construction of the OptimalControlFlow
    return OptimalControlFlow{DCoTangent, CoTangent, Time}(f, rhs!, u, ocp)

end

"""
$(TYPEDSIGNATURES)

Flow from an optimal control problem, a control function in feedback form, a state constraint and its 
associated multiplier in feedback form.

# Example
```jldoctest
julia> ocp = Model(time_dependence=:nonautonomous)
julia> f = Flow(ocp, (t, x, p) -> p[1], (t, x) -> x[1] - 1, (t, x, p) -> x[1]+p[1])
```

!!! warning

    The time dependence of the control function must be consistent with the time dependence of the optimal control problem.
    The dimension of the output of the control function must be consistent with the dimension usage of the control of the optimal control problem.
"""
function Flow(ocp::OptimalControlModel{T, V}, u_::Function, g_::Function, μ_::Function; alg=__alg(), abstol=__abstol(),
    reltol=__reltol(), saveat=__saveat(), kwargs_Flow...) where {T, V}
    
    # data
    p⁰ = -1.
    f  = ocp.dynamics
    f⁰ = ocp.lagrange
    s  = is_min(ocp) ? 1.0 : -1.0 #

    # construction of the Hamiltonian
    if f ≠ nothing
        u = ControlLaw(u_, T, V) # consistency is needed
        g = MixedConstraint(g_, T, V) # consistency is needed
        μ = Multiplier(μ_, T, V) # consistency is needed
        h = Hamiltonian(f⁰ ≠ nothing ? makeH(f, u, f⁰, p⁰, s, g, μ) : makeH(f, u, g, μ), NonAutonomous, NonFixed)
    else 
        error("no dynamics in ocp")
    end

    # right and side: same as for a flow from a Hamiltonian
    rhs! = rhs(h)

    # flow function
    f = hamiltonian_usage(alg, abstol, reltol, saveat; kwargs_Flow...)

    # construction of the OptimalControlFlow
    return OptimalControlFlow{DCoTangent, CoTangent, Time}(f, rhs!, u, ocp)

end

"""
$(TYPEDEF)

Type that represents a solution to an optimal control flow.

**Fields**

$(TYPEDFIELDS)

"""
struct OptimalControlFlowSolution
    # 
    ode_sol
    feedback_control::ControlLaw # the control law in state-costate feedback form, that is u(t, x, p)
    ocp::OptimalControlModel
end

"""
$(TYPEDSIGNATURES)

Construct an `OptimalControlSolution` from an `OptimalControlFlowSolution`.

"""
function CTFlows.OptimalControlSolution(ocfs::OptimalControlFlowSolution)
    n = ocfs.ocp.state_dimension
    T = ocfs.ode_sol.t
    x(t) = ocfs.ode_sol(t)[rg(1,n)]
    p(t) = ocfs.ode_sol(t)[rg(n+1,2n)]
    u(t) = ocfs.feedback_control(t, x(t), p(t))
    sol = CTBase.OptimalControlSolution()
    copy!(sol, ocfs.ocp)
    sol.times   = T
    sol.state   = t -> x(t)
    sol.costate = t -> p(t)
    sol.control = t -> u(t)
    return sol
end

# ---------------------------------------------------------------------------------------------------
#
function CTFlows.plot(sol::OptimalControlFlowSolution; style::Symbol=:ocp, kwargs...)
    ocp_sol = CTFlows.OptimalControlSolution(sol) # from a flow (from ocp and control) solution to an OptimalControlSolution
    if style==:ocp
        CTBase.plot(ocp_sol; kwargs...)
    else
        Plots.plot(sol.ode_sol; kwargs...)
    end
end

# ---------------------------------------------------------------------------------------------------
#
function CTFlows.plot(sol::OptimalControlFlowSolution, args...; kwargs...)
    Plots.plot(sol.ode_sol, args...; kwargs...)
end