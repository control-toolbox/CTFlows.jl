"""
$(TYPEDEF)

Type that represents a solution to an optimal control flow.

**Fields**

$(TYPEDFIELDS)

"""
struct OptimalControlFlowSolution
    # 
    ode_sol
    feedback_control::ControlFunction # the control law in feedback form, that is u(t, x, p)
    control_dimension::Dimension
    control_names::Vector{String}
    state_dimension::Dimension
    state_names::Vector{String}
    time_name::String
end

"""
$(TYPEDSIGNATURES)

Construct an `OptimalControlSolution` from an `OptimalControlFlowSolution`.

"""
function CTFlows.OptimalControlSolution(ocfs::OptimalControlFlowSolution)
    n = ocfs.state_dimension
    T = ocfs.ode_sol.t
    x(t) = ocfs.ode_sol(t)[1:n]
    p(t) = ocfs.ode_sol(t)[1+n:2n]
    u(t) = ocfs.feedback_control(t, x(t), p(t))
    sol = CTBase.OptimalControlSolution()
    sol.state_dimension = n
    sol.control_dimension = ocfs.control_dimension
    sol.times = T
    sol.time_name = ocfs.time_name
    sol.state = t -> x(t)
    sol.state_names = ocfs.state_names
    sol.adjoint = t -> p(t)
    sol.control = t -> u(t)
    sol.control_names = ocfs.control_names
    return sol
end

