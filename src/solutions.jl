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
    x(t) = ocfs.ode_sol(t)[1:n]
    p(t) = ocfs.ode_sol(t)[1+n:2n]
    u(t) = ocfs.feedback_control(t, x(t), p(t))
    sol = CTBase.OptimalControlSolution()
    copy!(sol, ocfs.ocp)
    sol.times   = T
    sol.state   = t -> x(t)
    sol.costate = t -> p(t)
    sol.control = t -> u(t)
    return sol
end

