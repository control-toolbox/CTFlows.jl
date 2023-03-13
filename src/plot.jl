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