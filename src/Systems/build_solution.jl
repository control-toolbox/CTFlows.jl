"""
$(TYPEDSIGNATURES)

Default implementation for `PointConfig` — return the final state.

If the config's `x0` is a `Number`, unwrap the length-1 vector that was
introduced by the scalar-promotion at `ode_problem` time.
"""
function build_solution(sys::VectorFieldSystem, raw, flow, config::Common.PointConfig)
    final = raw.u[end]
    return config.x0 isa Number ? final[1] : final
end

"""
$(TYPEDSIGNATURES)

Default implementation for `TrajectoryConfig` — wrap the raw ODE solution
in a `VectorFieldSolution` for future extensibility.
"""
function build_solution(sys::VectorFieldSystem, raw, flow, config::Common.TrajectoryConfig)
    return VectorFieldSolution(raw)
end
