"""
$(TYPEDSIGNATURES)

Default implementation for `PointConfig` — return the final state.

If the config's `x0` is a `Number`, this unwraps the length-1 vector that was
introduced by the scalar-promotion at ODE problem construction time using
[`CTFlows.Common.unwrap_state`](@ref).

# Arguments
- `result::AbstractIntegrationResult`: The integration result.
- `sys::Systems.VectorFieldSystem`: The vector field system.
- `config::Common.PointConfig`: The point configuration.

# Returns
- `Union{Number, AbstractVector}`: The final state (scalar if config was scalar, vector otherwise).

See also: [`CTFlows.Solutions.AbstractIntegrationResult`](@ref), [`CTFlows.Common.unwrap_state`](@ref).
"""
function build_solution(result::AbstractIntegrationResult, sys::Systems.VectorFieldSystem, config::Common.PointConfig)
    return Common.unwrap_state(config, final_state(result))
end

"""
$(TYPEDSIGNATURES)

Default implementation for `TrajectoryConfig` — wrap the integration result
in a `VectorFieldSolution` for future extensibility.

# Arguments
- `result::AbstractIntegrationResult`: The integration result.
- `sys::Systems.VectorFieldSystem`: The vector field system.
- `config::Common.TrajectoryConfig`: The trajectory configuration.

# Returns
- `VectorFieldSolution`: The wrapped integration result.

See also: [`CTFlows.Solutions.AbstractIntegrationResult`](@ref), [`CTFlows.Solutions.VectorFieldSolution`](@ref).
"""
function build_solution(result::AbstractIntegrationResult, sys::Systems.VectorFieldSystem, config::Common.TrajectoryConfig)
    return VectorFieldSolution(result)
end
