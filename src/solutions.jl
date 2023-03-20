# ---------------------------------------------------------------------------------------------------
#
struct OptimalControlFlowSolution
    # 
    ode_sol
    feedback_control::ControlFunction # the control law in feedback form, that is u(t, x, p)
    control_dimension::Dimension
    control_labels::Vector{String}
    state_dimension::Dimension
    state_labels::Vector{String}
    time_label::String
end

# ---------------------------------------------------------------------------------------------------
#
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
    sol.time_label = ocfs.time_label
    sol.state = t -> x(t)
    sol.state_labels = ocfs.state_labels
    sol.adjoint = t -> p(t)
    sol.control = t -> u(t)
    sol.control_labels = ocfs.control_labels
    return sol
end

