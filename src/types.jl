# ---------------------------------------------------------------------------------------------------
# This is the flow returned by the function Flow
# The call to the flow is given after.
struct HamiltonianFlow <: AbstractFlow{DCoTangent, CoTangent}
    f::Function      # f(args..., rhs): compute the flow
    rhs!::Function   # DifferentialEquations rhs
    tstops::Times    # stopping times
    jumps::Vector{Tuple{Time, Costate}} # specific jumps the integrator must perform
    function HamiltonianFlow(f, rhs!, 
        tstops::Times=Vector{Time}(), 
        jumps::Vector{Tuple{Time, Costate}}=Vector{Tuple{Time, Costate}}())
        return new(f, rhs!, tstops, jumps)
    end
end

# call F.f
(F::HamiltonianFlow)(args...; kwargs...) = begin
    F.f(args...; jumps=F.jumps, _t_stops_interne=F.tstops, DiffEqRHS=F.rhs!, kwargs...)
end

# ---------------------------------------------------------------------------------------------------
struct VectorFieldFlow <: AbstractFlow{DState, State}
    f::Function     # f(args..., rhs): compute the flow
    rhs::Function  # DifferentialEquations rhs
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

# ---------------------------------------------------------------------------------------------------
struct ODEFlow <: AbstractFlow{Any, Any}
    f::Function     # f(args..., rhs): compute the flow
    rhs::Function   # DifferentialEquations rhs
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

# ---------------------------------------------------------------------------------------------------
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

# call F.f and then, construct an optimal control solution
function (F::OptimalControlFlow)(tspan::Tuple{Time,Time}, x0::State, p0::Costate, v::Variable=__variable(); kwargs...) 
    ode_sol  = F.f(tspan, x0, p0, v; jumps=F.jumps, _t_stops_interne=F.tstops, DiffEqRHS=F.rhs!, kwargs...)
    flow_sol = OptimalControlFlowSolution(ode_sol, F.feedback_control, F.ocp, v)
    return CTFlows.OptimalControlSolution(flow_sol)
end
