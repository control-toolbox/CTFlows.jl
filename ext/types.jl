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
        tstops::Times = Vector{Time}(),
        jumps::Vector{Tuple{Time,Costate}} = Vector{Tuple{Time,Costate}}(),
    )
        return new(f, rhs!, tstops, jumps)
    end
end

# call F.f
(F::HamiltonianFlow)(args...; kwargs...) = begin
    F.f(args...; jumps = F.jumps, _t_stops_interne = F.tstops, DiffEqRHS = F.rhs!, kwargs...)
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
        tstops::Times = Vector{Time}(),
        jumps::Vector{Tuple{Time,State}} = Vector{Tuple{Time,State}}(),
    )
        return new(f, rhs, tstops, jumps)
    end
end

# call F.f
(F::VectorFieldFlow)(args...; kwargs...) = begin
    F.f(args...; jumps = F.jumps, _t_stops_interne = F.tstops, DiffEqRHS = F.rhs, kwargs...)
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
        tstops::Times = Vector{Time}(),
        jumps::Vector{Tuple{Time,Any}} = Vector{Tuple{Time,Any}}(),
    )
        return new(f, rhs!, tstops, jumps)
    end
end

(F::ODEFlow)(args...; kwargs...) = begin
    F.f(args...; jumps = F.jumps, _t_stops_interne = F.tstops, DiffEqRHS = F.rhs, kwargs...)
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
    feedback_control::ControlLaw # the control law in state-costate feedback form, that is u(t, x, p, v)
    ocp::OptimalControlModel
    variable::Variable
end

(OCFS::OptimalControlFlowSolution)(args...; kwargs...) = OCFS.ode_sol(args...; kwargs...)

"""
$(TYPEDSIGNATURES)

Construct an `OptimalControlSolution` from an `OptimalControlFlowSolution`.

"""
function CTBase.OptimalControlSolution(ocfs::OptimalControlFlowSolution; kwargs...)

    ocp = ocfs.ocp
    n = state_dimension(ocp)
    T = ocfs.ode_sol.t
    v = ocfs.variable
    x(t) = ocfs.ode_sol(t)[rg(1, n)]
    p(t) = ocfs.ode_sol(t)[rg(n + 1, 2n)]
    u(t) = ocfs.feedback_control(t, x(t), p(t), v)

    # the objmust be computed and pass to OptimalControlSolution
    t0 = T[1]
    tf = T[end]
    obj = has_mayer_cost(ocp) ? mayer(ocp)(x(t0), x(tf), v) : 0
    if has_lagrange_cost(ocp)
        try
            ϕ(_, _, t) = [lagrange(ocp)(t, x(t), u(t), v)]
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

    # we provide the variable only if the problem is NonFixed
    kwargs_OCS = CTBase.is_fixed(ocp) ? () : (variable = v,)
    kwargs_OCS = (
        kwargs_OCS...,
        time_grid = T,
        state = t -> x(t),
        costate = t -> p(t),
        control = t -> u(t),
        objective = obj,
    )
    sol = CTBase.OptimalControlSolution(ocp; kwargs_OCS...)

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
    feedback_control::ControlLaw # the control law in feedback form, that is u(t, x, p, v)
    ocp::OptimalControlModel{<:TimeDependence,VD} # the optimal control problem
    kwargs_Flow::Any     #

    # constructor
    function OptimalControlFlow(
        f::Function,
        rhs!::Function,
        u::ControlLaw,
        ocp::OptimalControlModel{<:TimeDependence,VD},
        kwargs_Flow,
        tstops::Times = Vector{Time}(),
        jumps::Vector{Tuple{Time,Costate}} = Vector{Tuple{Time,Costate}}(),
    ) where {VD<:VariableDependence}

        return new{VD}(f, rhs!, tstops, jumps, u, ocp, kwargs_Flow)

    end

end

# call F.f
function (F::OptimalControlFlow{Fixed})(
    t0::Time,
    x0::State,
    p0::Costate,
    tf::Time;
    kwargs...,
)

    F.f(
        t0,
        x0,
        p0,
        tf;
        jumps = F.jumps,
        _t_stops_interne = F.tstops,
        DiffEqRHS = F.rhs!,
        kwargs...,
    )

end

function (F::OptimalControlFlow{NonFixed})(
    t0::Time,
    x0::State,
    p0::Costate,
    tf::Time,
    v::Variable = __variable(t0, x0, p0, tf, F.ocp);
    kwargs...,
)

    F.f(
        t0,
        x0,
        p0,
        tf,
        v;
        jumps = F.jumps,
        _t_stops_interne = F.tstops,
        DiffEqRHS = F.rhs!,
        kwargs...,
    )

end

# call F.f and then, construct an optimal control solution
function (F::OptimalControlFlow{Fixed})(
    tspan::Tuple{Time,Time},
    x0::State,
    p0::Costate;
    kwargs...,
)

    ode_sol = F.f(
        tspan,
        x0,
        p0;
        jumps = F.jumps,
        _t_stops_interne = F.tstops,
        DiffEqRHS = F.rhs!,
        kwargs...,
    )
    flow_sol =
        OptimalControlFlowSolution(ode_sol, F.feedback_control, F.ocp, __variable(x0, p0))
    return CTBase.OptimalControlSolution(flow_sol; F.kwargs_Flow..., kwargs...)

end

function (F::OptimalControlFlow{NonFixed})(
    tspan::Tuple{Time,Time},
    x0::State,
    p0::Costate,
    v::Variable = __variable(tspan[1], x0, p0, tspan[2], F.ocp);
    kwargs...,
)

    ode_sol = F.f(
        tspan,
        x0,
        p0,
        v;
        jumps = F.jumps,
        _t_stops_interne = F.tstops,
        DiffEqRHS = F.rhs!,
        kwargs...,
    )
    flow_sol = OptimalControlFlowSolution(ode_sol, F.feedback_control, F.ocp, v)
    return CTBase.OptimalControlSolution(flow_sol; F.kwargs_Flow..., kwargs...)

end
