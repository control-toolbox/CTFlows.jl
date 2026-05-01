"""
$(TYPEDSIGNATURES)

Default implementation for `PointConfig` — return the final state.

If the config's `x0` is a `Number`, unwrap the length-1 vector that was
introduced by the scalar-promotion at `ode_problem` time.
"""
function build_solution(ode_sol::SciMLBase.AbstractODESolution, sys::Systems.VectorFieldSystem, config::Common.PointConfig)
    final = ode_sol.u[end]
    return config.x0 isa Number ? final[1] : final
end

"""
$(TYPEDSIGNATURES)

Default implementation for `TrajectoryConfig` — wrap the raw ODE solution
in a `VectorFieldSolution` for future extensibility.
"""
function build_solution(ode_sol::SciMLBase.AbstractODESolution, sys::Systems.VectorFieldSystem, config::Common.TrajectoryConfig)
    return VectorFieldSolution(ode_sol)
end
