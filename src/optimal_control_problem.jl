
"""
$(TYPEDEF)

Type of an optimal control flow solution.

**Fields**

$(TYPEDFIELDS)

"""
struct OptimalControlFlowSolution
    # 
    ode_sol
    feedback_control::ControlLaw # the control law in state-costate feedback form, that is u(t, x, p, v)
    ocp::OptimalControlModel
    variable::Variable
end

(OCFS::OptimalControlFlowSolution)(args...; kwargs...) = OCFS.ode_sol(args...; kwargs...)

"""
$(TYPEDSIGNATURES)

Construct an `OptimalControlSolution` from an `OptimalControlFlowSolution`.

"""
function CTFlows.OptimalControlSolution(ocfs::OptimalControlFlowSolution)
    n = ocfs.ocp.state_dimension
    T = ocfs.ode_sol.t
    v = ocfs.variable
    x(t) = ocfs.ode_sol(t)[rg(1,n)]
    p(t) = ocfs.ode_sol(t)[rg(n+1,2n)]
    u(t) = ocfs.feedback_control(t, x(t), p(t), v)
    sol = CTBase.OptimalControlSolution()
    copy!(sol, ocfs.ocp)
    sol.times   = T
    sol.state   = t -> x(t)
    sol.costate = t -> p(t)
    sol.control = t -> u(t)
    sol.variable = v
    return sol
end

# ---------------------------------------------------------------------------------------------------
function CTFlows.plot(sol::OptimalControlFlowSolution; style::Symbol=:ocp, kwargs...)
    ocp_sol = CTFlows.OptimalControlSolution(sol) # from a flow (from ocp and control) solution to an OptimalControlSolution
    if style==:ocp
        CTBase.plot(ocp_sol; kwargs...)
    else
        Plots.plot(sol.ode_sol; kwargs...)
    end
end

function CTFlows.plot!(p::Plots.Plot, sol::OptimalControlFlowSolution; style::Symbol=:ocp, kwargs...)
    ocp_sol = CTFlows.OptimalControlSolution(sol) # from a flow (from ocp and control) solution to an OptimalControlSolution
    if style==:ocp
        CTBase.plot!(p, ocp_sol; kwargs...)
    else
        Plots.plot!(p, sol.ode_sol; kwargs...)
    end
end

function CTFlows.plot(sol::OptimalControlFlowSolution, args...; kwargs...)
    Plots.plot(sol.ode_sol, args...; kwargs...)
end

function CTFlows.plot!(p::Plots.Plot, sol::OptimalControlFlowSolution, args...; kwargs...)
    Plots.plot!(p, sol.ode_sol, args...; kwargs...)
end

# ---------------------------------------------------------------------------------------------------
struct OptimalControlFlow <: AbstractFlow{DCoTangent, CoTangent}
    # 
    f::Function      # the mere function which depends on the kind of flow (Hamiltonian or classical) 
                     # this function takes a right and side as input
    rhs!::Function   # the right and side of the form: rhs!(du::D, u::U, p::V, t::T)
    tstops::Times    # specific times  the integrator must stop
                     # useful when the rhs is not smooth at such times
    jumps::Vector{Tuple{Time, Costate}} # specific jumps the integrator must perform
    feedback_control::ControlLaw # the control law in feedback form, that is u(t, x, p, v)
    ocp::OptimalControlModel # the optimal control problem

    # constructor
    function OptimalControlFlow(f::Function, rhs!::Function, u::ControlLaw, 
        ocp::OptimalControlModel, 
        tstops::Times=Vector{Time}(),
        jumps::Vector{Tuple{Time, Costate}}=Vector{Tuple{Time, Costate}}())
        return new(f, rhs!, tstops, jumps, u, ocp)
    end

end

# call F.f
(F::OptimalControlFlow)(args...; kwargs...) = begin
    F.f(args...; jumps=F.jumps, _t_stops_interne=F.tstops, DiffEqRHS=F.rhs!, kwargs...)
end

# call F.f and then, construct a solution which contains all the need information for plotting
# it is a Hamiltonian usage
function (F::OptimalControlFlow)(tspan::Tuple{Time,Time}, x0::State, p0::Costate, v::Variable=__variable(); kwargs...) 
    ode_sol = F.f(tspan, x0, p0, v; jumps=F.jumps, _t_stops_interne=F.tstops, DiffEqRHS=F.rhs!, kwargs...)
    return OptimalControlFlowSolution(ode_sol, F.feedback_control, F.ocp, v)
end

# ---------------------------------------------------------------------------------------------------
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
function Flow(ocp::OptimalControlModel{T, V}, u_::Union{Function, ControlLaw{T, V}}; alg=__alg(), abstol=__abstol(), 
    reltol=__reltol(), saveat=__saveat(), kwargs_Flow...) where {T, V}
    #
    h, u = __create_hamiltonian(ocp, u_) # construction of the Hamiltonian
    return __ocp_Flow(ocp, h, u, alg, abstol, reltol, saveat; kwargs_Flow...)
end

# ---------------------------------------------------------------------------------------------------
function __create_hamiltonian(ocp::OptimalControlModel{T, V}, u::ControlLaw{T, V}) where {T, V}
    f, f⁰, p⁰, s = __get_data_for_ocp_flow(ocp) # data
    @assert f ≠ nothing "no dynamics in ocp"
    h = Hamiltonian(f⁰ ≠ nothing ? makeH(f, u, f⁰, p⁰, s) : makeH(f, u), NonAutonomous, NonFixed)
    return h, u
end

function __create_hamiltonian(ocp::OptimalControlModel{T, V}, u::Function) where {T, V}
    return __create_hamiltonian(ocp, ControlLaw(u, T, V))
end

# ---------------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Flow from an optimal control problem, a control function in feedback form, a state constraint and its 
associated multiplier in feedback form.

# Example
```jldoctest
julia> ocp = Model(autonomous=false)
julia> f = Flow(ocp, (t, x, p) -> p[1], (t, x, u) -> x[1] - 1, (t, x, p) -> x[1]+p[1])
```

!!! warning

    The time dependence of the control function must be consistent with the time dependence of the optimal control problem.
    The dimension of the output of the control function must be consistent with the dimension usage of the control of the optimal control problem.
"""
function Flow(ocp::OptimalControlModel{T, V}, 
    u_::Union{Function, ControlLaw{T, V}, FeedbackControl{T, V}}, 
    g_::Union{Function, MixedConstraint{T, V}, StateConstraint{T, V}},
    μ_::Union{Function, Multiplier{T, V}}; 
    alg=__alg(), abstol=__abstol(),
    reltol=__reltol(), saveat=__saveat(), kwargs_Flow...) where {T, V}
    #
    h, u = __create_hamiltonian(ocp, u_, g_, μ_) # construction of the Hamiltonian
    return __ocp_Flow(ocp, h, u, alg, abstol, reltol, saveat; kwargs_Flow...)
end

# ---------------------------------------------------------------------------------------------------
function __create_hamiltonian(ocp::OptimalControlModel{T, V}, u::ControlLaw{T, V}, g::MixedConstraint{T, V}, μ::Multiplier{T, V}) where {T, V}
    f, f⁰, p⁰, s = __get_data_for_ocp_flow(ocp) # data
    @assert f ≠ nothing "no dynamics in ocp"
    h = Hamiltonian(f⁰ ≠ nothing ? makeH(f, u, f⁰, p⁰, s, g, μ) : makeH(f, u, g, μ), NonAutonomous, NonFixed)
    return h, u
end

function __create_hamiltonian(ocp::OptimalControlModel{T, V}, u::Function, g, μ) where {T, V}
    return __create_hamiltonian(ocp, ControlLaw(u, T, V), g, μ)
end

function __create_hamiltonian(ocp::OptimalControlModel{T, V}, u_::FeedbackControl{T, V}, g, μ) where {T, V}
    u = @match (T, V) begin
        (Autonomous, Fixed)       => ControlLaw((x, p) -> u_(x), T, V)
        (Autonomous, NonFixed)    => ControlLaw((x, p, v) -> u_(x, v), T, V)
        (NonAutonomous, Fixed)    => ControlLaw((t, p, x) -> u_(t, x), T, V)
        (NonAutonomous, NonFixed) => ControlLaw((t, x, p, v) -> u_(t, x, v), T, V)
    end
    return __create_hamiltonian(ocp, u, g, μ)
end

function __create_hamiltonian(ocp::OptimalControlModel{T, V}, u::ControlLaw{T, V}, g::Function, μ) where {T, V}
    return __create_hamiltonian(ocp, u, MixedConstraint(g, T, V), μ)
end

function __create_hamiltonian(ocp::OptimalControlModel{T, V}, u::ControlLaw{T, V}, g_::StateConstraint{T, V}, μ) where {T, V}
    g = @match (T, V) begin
        (Autonomous, Fixed)       => MixedConstraint((x, u) -> g_(x), T, V)
        (Autonomous, NonFixed)    => MixedConstraint((x, u, v) -> g_(x, v), T, V)
        (NonAutonomous, Fixed)    => MixedConstraint((t, x, u) -> g_(t, x), T, V)
        (NonAutonomous, NonFixed) => MixedConstraint((t, x, u, v) -> g_(t, x, v), T, V)
    end
    return __create_hamiltonian(ocp, u, g, μ)
end

function __create_hamiltonian(ocp::OptimalControlModel{T, V}, u::ControlLaw{T, V}, g::MixedConstraint{T, V}, μ::Function) where {T, V}
    return __create_hamiltonian(ocp, u, g, Multiplier(μ, T, V))
end

# ---------------------------------------------------------------------------------------------------
function __ocp_Flow(ocp::OptimalControlModel{T, V}, h::Hamiltonian, u::ControlLaw,
    alg, abstol, reltol, saveat; kwargs_Flow...) where {T, V}
    rhs! = rhs(h) # right and side: same as for a flow from a Hamiltonian
    f = hamiltonian_usage(alg, abstol, reltol, saveat; kwargs_Flow...) # flow function
    return OptimalControlFlow(f, rhs!, u, ocp)
end

# ---------------------------------------------------------------------------------------------------
function __get_data_for_ocp_flow(ocp::OptimalControlModel)
    f  = ocp.dynamics
    f⁰ = ocp.lagrange
    p⁰ = -1
    s  = is_min(ocp) ? 1.0 : -1.0
    return f, f⁰, p⁰, s
end

# ---------------------------------------------------------------------------------------------------
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