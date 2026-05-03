"""
$(TYPEDSIGNATURES)

Default implementation for `PointConfig` — return the final state.

For scalar configurations (`X0 <: Number`), unwraps the length-1 vector that was
introduced by scalar-promotion at ODE problem construction time. For vector
configurations, returns the state vector unchanged.

This uses compile-time dispatch on the configuration's type parameter `X0`
to avoid runtime type tests.

# Arguments
- `result::AbstractIntegrationResult`: The integration result.
- `sys::Systems.VectorFieldSystem`: The vector field system.
- `config::Common.PointConfig{<:Real, <:Number, <:Real}`: Scalar point configuration.

# Returns
- `Number`: The unwrapped scalar final state.

See also: [`CTFlows.Solutions.AbstractIntegrationResult`](@ref), [`CTFlows.Common.AbstractConfig`](@ref).
"""
function build_solution(result::AbstractIntegrationResult, sys::Systems.VectorFieldSystem, config::Common.PointConfig{<:Real, <:Number, <:Real})
    return final_state(result)[1]
end

"""
$(TYPEDSIGNATURES)

Default implementation for `PointConfig` — return the final state.

For vector configurations, returns the state vector unchanged.

# Arguments
- `result::AbstractIntegrationResult`: The integration result.
- `sys::Systems.VectorFieldSystem`: The vector field system.
- `config::Common.PointConfig`: Vector point configuration.

# Returns
- `AbstractVector`: The final state vector.

See also: [`CTFlows.Solutions.AbstractIntegrationResult`](@ref), [`CTFlows.Common.AbstractConfig`](@ref).
"""
function build_solution(result::AbstractIntegrationResult, sys::Systems.VectorFieldSystem, config::Common.PointConfig)
    return final_state(result)
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
