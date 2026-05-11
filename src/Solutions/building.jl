"""
$(TYPEDSIGNATURES)

Default implementation for `PointConfig` — return the final state.

For scalar configurations (`X0 <: Number`), unwraps the length-1 vector that was
introduced by scalar-promotion at ODE problem construction time. For vector
configurations, returns the state vector unchanged.

This uses compile-time dispatch on the configuration's type parameter `X0`
to avoid runtime type tests.

# Arguments
- `result::Integrators.AbstractIntegrationResult`: The integration result.
- `sys::Systems.VectorFieldSystem`: The vector field system.
- `config::Common.PointConfig{<:Real, <:Number, <:Real}`: Scalar point configuration.

# Returns
- `Number`: The unwrapped scalar final state.

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Common.AbstractConfig`](@ref).
"""
function build_solution(result::Integrators.AbstractIntegrationResult, sys::Systems.VectorFieldSystem, config::Common.PointConfig{<:Real, <:Number, <:Real})
    return final_state(result)[1]
end

"""
$(TYPEDSIGNATURES)

Default implementation for `PointConfig` — return the final state.

For vector configurations, returns the state vector unchanged.

# Arguments
- `result::Integrators.AbstractIntegrationResult`: The integration result.
- `sys::Systems.VectorFieldSystem`: The vector field system.
- `config::Common.PointConfig`: Vector point configuration.

# Returns
- `AbstractVector`: The final state vector.

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Common.AbstractConfig`](@ref).
"""
function build_solution(result::Integrators.AbstractIntegrationResult, sys::Systems.VectorFieldSystem, config::Common.PointConfig)
    return final_state(result)
end

"""
$(TYPEDSIGNATURES)

Default implementation for `TrajectoryConfig` — wrap the integration result
in a `VectorFieldSolution` for future extensibility.

# Arguments
- `result::Integrators.AbstractIntegrationResult`: The integration result.
- `sys::Systems.VectorFieldSystem`: The vector field system.
- `config::Common.TrajectoryConfig`: The trajectory configuration.

# Returns
- `VectorFieldSolution`: The wrapped integration result.

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Solutions.VectorFieldSolution`](@ref).
"""
function build_solution(result::Integrators.AbstractIntegrationResult, sys::Systems.VectorFieldSystem, config::Common.TrajectoryConfig)
    return VectorFieldSolution(result)
end

"""
$(TYPEDSIGNATURES)

Build a solution for a scalar HamiltonianPointConfig integration.

Returns the final state and costate as a tuple of scalars `(xf, pf)`, unwrapping the
length-1 vectors that were introduced by scalar-promotion at ODE problem construction time.

# Arguments
- `result::Integrators.AbstractIntegrationResult`: The integration result.
- `sys::Systems.HamiltonianVectorFieldSystem`: The Hamiltonian vector field system.
- `config::Common.HamiltonianPointConfig{<:Real, <:Number, <:Number, <:Real}`: Scalar Hamiltonian point configuration.

# Returns
- `Tuple{Number, Number}`: The final state and costate as scalars.

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Common.AbstractConfig`](@ref).
"""
function build_solution(result::Integrators.AbstractIntegrationResult, sys::Systems.HamiltonianVectorFieldSystem, config::Common.HamiltonianPointConfig{<:Real, <:Number, <:Number, <:Real})
    u = Integrators.final_state(result)
    return (u[1], u[2])
end

"""
$(TYPEDSIGNATURES)

Build a solution for a vectorial HamiltonianPointConfig integration.

Returns the final state and costate as a tuple of vectors `(xf, pf)`.

# Arguments
- `result::Integrators.AbstractIntegrationResult`: The integration result.
- `sys::Systems.HamiltonianVectorFieldSystem`: The Hamiltonian vector field system.
- `config::Common.HamiltonianPointConfig`: Vectorial Hamiltonian point configuration.

# Returns
- `Tuple{AbstractVector, AbstractVector}`: The final state and costate vectors.

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Common.AbstractConfig`](@ref).
"""
function build_solution(result::Integrators.AbstractIntegrationResult, sys::Systems.HamiltonianVectorFieldSystem, config::Common.HamiltonianPointConfig)
    u = Integrators.final_state(result)
    n = length(Common.initial_condition(config))
    return (u[1:n], u[n+1:2n])
end

"""
$(TYPEDSIGNATURES)

Build a solution for a HamiltonianTrajectoryConfig integration.

Wraps the integration result in a `HamiltonianVectorFieldSolution` for future extensibility.

# Arguments
- `result::Integrators.AbstractIntegrationResult`: The integration result.
- `sys::Systems.HamiltonianVectorFieldSystem`: The Hamiltonian vector field system.
- `config::Common.HamiltonianTrajectoryConfig`: The Hamiltonian trajectory configuration.

# Returns
- `HamiltonianVectorFieldSolution`: The wrapped integration result.

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Solutions.HamiltonianVectorFieldSolution`](@ref).
"""
function build_solution(result::Integrators.AbstractIntegrationResult, sys::Systems.HamiltonianVectorFieldSystem, config::Common.HamiltonianTrajectoryConfig)
    return HamiltonianVectorFieldSolution(result)
end
