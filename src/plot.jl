# ---------------------------------------------------------------------------------------------------
#
function CTFlows.plot(sol::OptimalControlFlowSolution; kwargs...)
    ocp_sol = CTFlows.OptimalControlSolution(sol) # from a flow (from ocp and control) solution to an OptimalControlSolution
    CTBase.plot(ocp_sol)
end

# ---------------------------------------------------------------------------------------------------
#
function CTFlows.plot(sol::OptimalControlFlowSolution, args...; kwargs...)
    Plots.plot(sol.ode_sol, args...; kwargs...)
end