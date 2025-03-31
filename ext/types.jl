const ctNumber = CTModels.ctNumber
const ctVector = Union{ctNumber,CTModels.ctVector}
const Time     = ctNumber
const Times    = AbstractVector{<:Time}
const State    = ctVector
const Costate  = ctVector
const Control  = ctVector
const Variable = ctVector
const DState   = ctVector
const DCostate = ctVector

# ---------------------------------------------------------------------------------------------------
# This is the flow returned by the function Flow
# The call to the flow is given after.
struct HamiltonianFlow <: AbstractFlow{DCoTangent,CoTangent}
    f::Function      # f(args..., rhs): compute the flow
    rhs!::Function   # DifferentialEquations rhs
    tstops::Times    # stopping times
    jumps::Vector{Tuple{Time,Costate}} # specific jumps the integrator must perform
    function HamiltonianFlow(
        f,
        rhs!,
        tstops::Times=Vector{Time}(),
        jumps::Vector{Tuple{Time,Costate}}=Vector{Tuple{Time,Costate}}(),
    )
        return new(f, rhs!, tstops, jumps)
    end
end

# call F.f
function (F::HamiltonianFlow)(args...; kwargs...)
    return F.f(
        args...; jumps=F.jumps, _t_stops_interne=F.tstops, DiffEqRHS=F.rhs!, kwargs...
    )
end

# ---------------------------------------------------------------------------------------------------
struct VectorFieldFlow <: AbstractFlow{DState,State}
    f::Function     # f(args..., rhs): compute the flow
    rhs::Function  # DifferentialEquations rhs
    tstops::Times   # stopping times
    jumps::Vector{Tuple{Time,State}} # specific jumps the integrator must perform
    function VectorFieldFlow(
        f,
        rhs,
        tstops::Times=Vector{Time}(),
        jumps::Vector{Tuple{Time,State}}=Vector{Tuple{Time,State}}(),
    )
        return new(f, rhs, tstops, jumps)
    end
end

# call F.f
function (F::VectorFieldFlow)(args...; kwargs...)
    return F.f(
        args...; jumps=F.jumps, _t_stops_interne=F.tstops, DiffEqRHS=F.rhs, kwargs...
    )
end

# ---------------------------------------------------------------------------------------------------
struct ODEFlow <: AbstractFlow{Any,Any}
    f::Function     # f(args..., rhs): compute the flow
    rhs::Function   # DifferentialEquations rhs
    tstops::Times   # stopping times
    jumps::Vector{Tuple{Time,Any}} # specific jumps the integrator must perform
    function ODEFlow(
        f,
        rhs!,
        tstops::Times=Vector{Time}(),
        jumps::Vector{Tuple{Time,Any}}=Vector{Tuple{Time,Any}}(),
    )
        return new(f, rhs!, tstops, jumps)
    end
end

function (F::ODEFlow)(args...; kwargs...)
    return F.f(
        args...; jumps=F.jumps, _t_stops_interne=F.tstops, DiffEqRHS=F.rhs, kwargs...
    )
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
    ode_sol::Any
    feedback_control::CTFlows.ControlLaw # the control law in state-costate feedback form, that is u(t, x, p, v)
    ocp::CTModels.Model
    variable::Variable
end

(OCFS::OptimalControlFlowSolution)(args...; kwargs...) = OCFS.ode_sol(args...; kwargs...)

"""
$(TYPEDSIGNATURES)

Construct an `OptimalControlSolution` from an `OptimalControlFlowSolution`.

"""
function CTModels.Solution(ocfs::OptimalControlFlowSolution; kwargs...)
    ocp = ocfs.ocp
    n = CTModels.state_dimension(ocp)
    T = ocfs.ode_sol.t

    println("time grid = ", T)

    v = ocfs.variable
    x(t) = ocfs.ode_sol(t)[rg(1, n)]
    p(t) = ocfs.ode_sol(t)[rg(n + 1, 2n)]
    u(t) = ocfs.feedback_control(t, x(t), p(t), v)

    # the obj must be computed and pass to OptimalControlSolution
    t0 = T[1]
    tf = T[end]

    may = CTFlows.__mayer(ocp)
    lag = CTFlows.__lagrange(ocp)

    obj = CTModels.has_mayer_cost(ocp) ? may(x(t0), x(tf), v) : 0
    if CTModels.has_lagrange_cost(ocp)
        try
            ϕ(_, _, t) = [lag(t, x(t), u(t), v)]
            tspan = (t0, tf)
            x0 = [0.0]
            prob = ODEProblem(ϕ, x0, tspan)
            alg = :alg ∈ keys(kwargs) ? kwargs[:alg] : __alg()
            ode_sol = solve(prob, alg; kwargs...)
            obj += ode_sol(tf)[1]
        catch e
            obj = NaN
        end
    end

    #
    N = length(T)
    X = zeros(N, n)
    for i in 1:N
        t = T[i]
        X[i, :] .= x(t)
    end
    P = zeros(N-1, n)
    for i in 1:N-1
        t = T[i]
        P[i, :] .= p(t)
    end
    m = CTModels.control_dimension(ocp)
    U = zeros(N, m)
    for i in 1:N
        t = T[i]
        U[i, :] .= u(t)
    end
    v = v isa Number ? Float64[v] : v
    kwargs_OCS = obj==NaN ? () : (objective=obj,)

    sol = CTModels.build_solution(
        ocp,
        Vector{Float64}(T), #::Vector{Float64},
        X, #::Matrix{Float64},
        U, #::Matrix{Float64},
        Float64.(v), #::Vector{Float64},
        P; #::Matrix{Float64};
        iterations=-1,
        constraints_violation=-1.0,
        message="no message",
        stopping=:nostoppingmessage,
        success=true,    
        kwargs_OCS...
    )

    return sol
end

# ---------------------------------------------------------------------------------------------------
struct OptimalControlFlow{VD} <: AbstractFlow{DCoTangent,CoTangent}
    # 
    f::Function      # the mere function which depends on the kind of flow (Hamiltonian or classical) 
    # this function takes a right and side as input
    rhs!::Function   # the right and side of the form: rhs!(du::D, u::U, p::V, t::T)
    tstops::Times    # specific times  the integrator must stop
    # useful when the rhs is not smooth at such times
    jumps::Vector{Tuple{Time,Costate}} # specific jumps the integrator must perform
    feedback_control::CTFlows.ControlLaw # the control law in feedback form, that is u(t, x, p, v)
    ocp::CTModels.Model # the optimal control problem
    kwargs_Flow::Any     #

    # constructor
    function OptimalControlFlow(
        f::Function,
        rhs!::Function,
        u::CTFlows.ControlLaw,
        ocp::CTModels.Model,
        kwargs_Flow,
        tstops::Times=Vector{Time}(),
        jumps::Vector{Tuple{Time,Costate}}=Vector{Tuple{Time,Costate}}(),
    )
        VD = if CTModels.variable_dimension(ocp)==0
            CTFlows.Fixed
        else
            CTFlows.NonFixed
        end
        return new{VD}(f, rhs!, tstops, jumps, u, ocp, kwargs_Flow)
    end
end

# call F.f
function (F::OptimalControlFlow{CTFlows.Fixed})(
    t0::Time, x0::State, p0::Costate, tf::Time; kwargs...
)
    return F.f(
        t0,
        x0,
        p0,
        tf;
        jumps=F.jumps,
        _t_stops_interne=F.tstops,
        DiffEqRHS=F.rhs!,
        kwargs...,
    )
end

function (F::OptimalControlFlow{CTFlows.NonFixed})(
    t0::Time,
    x0::State,
    p0::Costate,
    tf::Time,
    v::Variable=__thevariable(t0, x0, p0, tf, F.ocp);
    kwargs...,
)
    return F.f(
        t0,
        x0,
        p0,
        tf,
        v;
        jumps=F.jumps,
        _t_stops_interne=F.tstops,
        DiffEqRHS=F.rhs!,
        kwargs...,
    )
end

# call F.f and then, construct an optimal control solution
function (F::OptimalControlFlow{CTFlows.Fixed})(
    tspan::Tuple{Time,Time}, x0::State, p0::Costate; kwargs...
)
    ode_sol = F.f(
        tspan, x0, p0; jumps=F.jumps, _t_stops_interne=F.tstops, DiffEqRHS=F.rhs!, kwargs...
    )
    flow_sol = OptimalControlFlowSolution(
        ode_sol, F.feedback_control, F.ocp, __thevariable(x0, p0)
    )
    return CTModels.Solution(flow_sol; F.kwargs_Flow..., kwargs...)
end

function (F::OptimalControlFlow{CTFlows.NonFixed})(
    tspan::Tuple{Time,Time},
    x0::State,
    p0::Costate,
    v::Variable=__thevariable(tspan[1], x0, p0, tspan[2], F.ocp);
    kwargs...,
)
    ode_sol = F.f(
        tspan,
        x0,
        p0,
        v;
        jumps=F.jumps,
        _t_stops_interne=F.tstops,
        DiffEqRHS=F.rhs!,
        kwargs...,
    )
    flow_sol = OptimalControlFlowSolution(ode_sol, F.feedback_control, F.ocp, v)
    return CTModels.Solution(flow_sol; F.kwargs_Flow..., kwargs...)
end
