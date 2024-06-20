module CTFlowsPlots

    using CTBase
    using CTFlows: CTFlows
    using Plots: plot, Plots
    #
    import Plots: plot, plot!

    # --------------------------------------------------------------------------------------------------
    # Aliases
    const OptimalControlFlowSolution = CTFlows.OptimalControlFlowSolution
    const OptimalControlSolution = CTFlows.OptimalControlSolution

    # --------------------------------------------------------------------------------------------------
    function Plots.plot(sol::OptimalControlFlowSolution; style::Symbol=:ocp, kwargs...)
        ocp_sol = OptimalControlSolution(sol) # from a flow (from ocp and control) solution to an OptimalControlSolution
        if style==:ocp
            Plots.plot(ocp_sol; kwargs...)
        else
            Plots.plot(sol.ode_sol; kwargs...)
        end
    end
    
    function Plots.plot!(p::Plots.Plot, sol::OptimalControlFlowSolution; style::Symbol=:ocp, kwargs...)
        ocp_sol = OptimalControlSolution(sol) # from a flow (from ocp and control) solution to an OptimalControlSolution
        if style==:ocp
            Plots.plot!(p, ocp_sol; kwargs...)
        else
            Plots.plot!(p, sol.ode_sol; kwargs...)
        end
    end
    
    function Plots.plot(sol::OptimalControlFlowSolution, args...; kwargs...)
        Plots.plot(sol.ode_sol, args...; kwargs...)
    end
    
    function Plots.plot!(p::Plots.Plot, sol::OptimalControlFlowSolution, args...; kwargs...)
        Plots.plot!(p, sol.ode_sol, args...; kwargs...)
    end

end