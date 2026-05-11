# =============================================================================
# Solution from VectorFieldSystem
# =============================================================================

"""
$(TYPEDSIGNATURES)

Default implementation for scalar point configs — return the final state.

For scalar configurations (`X0 <: Number`), unwraps the length-1 vector that was
introduced by scalar-promotion at ODE problem construction time.

This uses compile-time dispatch on the configuration's type parameter to avoid
runtime type tests.

# Arguments
- `result::Integrators.AbstractIntegrationResult`: The integration result.
- `sys::Systems.VectorFieldSystem`: The vector field system.
- `config::Common.AbstractPointConfig{<:Number, Common.StateTag}`: Scalar point configuration.

# Returns
- `Number`: The unwrapped scalar final state.

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Common.AbstractPointConfig`](@ref).
"""
function build_solution(
    result::Integrators.AbstractIntegrationResult, 
    sys::Systems.AbstractStateSystem, 
    config::Common.AbstractPointConfig{<:Number, Common.StateTag}
    )
    return final_state(result)[1]
end

"""
$(TYPEDSIGNATURES)

Default implementation for point configs — return the final state.

For vector configurations, returns the state vector unchanged.

# Arguments
- `result::Integrators.AbstractIntegrationResult`: The integration result.
- `sys::Systems.VectorFieldSystem`: The vector field system.
- `config::Common.AbstractPointConfig`: Point configuration.

# Returns
- `AbstractVector`: The final state vector.

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Common.AbstractPointConfig`](@ref).
"""
function build_solution(
    result::Integrators.AbstractIntegrationResult, 
    sys::Systems.AbstractStateSystem, 
    config::Common.AbstractPointConfig{X0, Common.StateTag}
    ) where {X0}
    return final_state(result)
end

"""
$(TYPEDSIGNATURES)

Default implementation for trajectory configs — wrap the integration result
in a `VectorFieldSolution` for future extensibility.

# Arguments
- `result::Integrators.AbstractIntegrationResult`: The integration result.
- `sys::Systems.VectorFieldSystem`: The vector field system.
- `config::Common.AbstractTrajectoryConfig`: The trajectory configuration.

# Returns
- `VectorFieldSolution`: The wrapped integration result.

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Solutions.VectorFieldSolution`](@ref), [`CTFlows.Common.AbstractTrajectoryConfig`](@ref).
"""
function build_solution(
    result::Integrators.AbstractIntegrationResult, 
    sys::Systems.AbstractStateSystem, 
    config::Common.AbstractTrajectoryConfig{X0, Common.StateTag}
    ) where {X0}
    return VectorFieldSolution(result)
end

# =============================================================================
# Internal helpers for Hamiltonian solution splitting
# =============================================================================

"""
$(TYPEDSIGNATURES)

Split a combined final state `u` into state `x` and costate `p` components.

Dispatches on the type of the initial condition `x0` to handle scalar, vector, and matrix cases.

# Arguments
- `u`: Combined final state `[x; p]` from integration.
- `x0::Number`: Scalar initial condition (splits as `(u[1], u[2])`).
- `x0::AbstractVector`: Vector initial condition (splits by length).
- `x0::AbstractMatrix`: Matrix initial condition (splits by number of rows).

# Returns
- `Tuple`: Tuple `(x, p)` with types matching `x0`:
  - `Tuple{Number, Number}` for scalar inputs
  - `Tuple{AbstractVector, AbstractVector}` for vector inputs
  - `Tuple{AbstractMatrix, AbstractMatrix}` for matrix inputs

# Notes
- Internal helper used by `build_solution` for `HamiltonianPointConfig`.
- Enables DRY principle by centralizing solution splitting logic.
"""
_ham_split_solution(u, x0::Number) = (u[1], u[2])
_ham_split_solution(u, x0::AbstractVector) = (u[1:length(x0)], u[length(x0)+1:end])
_ham_split_solution(u, x0::AbstractMatrix) = (u[1:size(x0, 1), :], u[size(x0, 1)+1:end, :])

# =============================================================================
# Solution from HamiltonianVectorFieldSystem
# =============================================================================

"""
$(TYPEDSIGNATURES)

Build a solution for Hamiltonian point configs.

Returns the final state and costate as a tuple `(xf, pf)`, dispatching on the
type of the initial condition to handle scalar, vector, and matrix cases.

# Arguments
- `result::Integrators.AbstractIntegrationResult`: The integration result.
- `sys::Systems.HamiltonianVectorFieldSystem`: The Hamiltonian vector field system.
- `config::Common.AbstractPointConfig{<:Any, Common.HamiltonianTag}`: The Hamiltonian point configuration.

# Returns
- `Tuple`: The final state and costate. Type depends on `x0`/`p0`:
  - `Tuple{Number, Number}` for scalar inputs
  - `Tuple{AbstractVector, AbstractVector}` for vector inputs
  - `Tuple{AbstractMatrix, AbstractMatrix}` for matrix inputs

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Common.AbstractPointConfig`](@ref), [`CTFlows.Common.AbstractHamiltonianConfig`](@ref).
"""
function build_solution(
    result::Integrators.AbstractIntegrationResult, 
    sys::Systems.AbstractHamiltonianSystem, 
    config::Common.AbstractPointConfig{X0, Common.HamiltonianTag}
    ) where {X0}
    return _ham_split_solution(Integrators.final_state(result), Common.initial_state(config))
end

"""
$(TYPEDSIGNATURES)

Build a solution for Hamiltonian trajectory configs.

Wraps the integration result in a `HamiltonianVectorFieldSolution` for future extensibility.

# Arguments
- `result::Integrators.AbstractIntegrationResult`: The integration result.
- `sys::Systems.HamiltonianVectorFieldSystem`: The Hamiltonian vector field system.
- `config::Common.AbstractTrajectoryConfig{<:Any, Common.HamiltonianTag}`: The Hamiltonian trajectory configuration.

# Returns
- `HamiltonianVectorFieldSolution`: The wrapped integration result.

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Solutions.HamiltonianVectorFieldSolution`](@ref), [`CTFlows.Common.AbstractTrajectoryConfig`](@ref), [`CTFlows.Common.AbstractHamiltonianConfig`](@ref).
"""
function build_solution(
    result::Integrators.AbstractIntegrationResult, 
    sys::Systems.AbstractHamiltonianSystem, 
    config::Common.AbstractTrajectoryConfig{X0, Common.HamiltonianTag}
    ) where {X0}
    return HamiltonianVectorFieldSolution(result)
end
