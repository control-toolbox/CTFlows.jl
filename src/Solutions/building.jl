# =============================================================================
# Solution from VectorFieldSystem
# =============================================================================

"""
$(TYPEDSIGNATURES)

Default implementation for scalar point configs — return the final state.

For scalar configurations (`initial_state <: Number`), unwraps the length-1 vector that was
introduced by scalar-promotion at ODE problem construction time.

This uses compile-time dispatch on the initial state type to avoid runtime type tests.

# Arguments
- `::Type{Common.PointTrait}`: The point mode trait type.
- `::Type{Common.StateTrait}`: The state content trait type.
- `initial_state::Number`: The scalar initial state.
- `result::Integrators.AbstractIntegrationResult`: The integration result.

# Returns
- `Number`: The unwrapped scalar final state.

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Common.PointTrait`](@ref), [`CTFlows.Common.StateTrait`](@ref).
"""
function build_solution(
    ::Type{Common.PointTrait},
    ::Type{Common.StateTrait},
    initial_state::Number,
    result::Integrators.AbstractIntegrationResult, 
)
    return final_state(result)[1]
end

"""
$(TYPEDSIGNATURES)

Default implementation for point configs — return the final state.

For vector configurations, returns the state vector unchanged.

# Arguments
- `::Type{Common.PointTrait}`: The point mode trait type.
- `::Type{Common.StateTrait}`: The state content trait type.
- `initial_state`: The initial state (vector or scalar).
- `result::Integrators.AbstractIntegrationResult`: The integration result.

# Returns
- `AbstractVector`: The final state vector.

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Common.PointTrait`](@ref), [`CTFlows.Common.StateTrait`](@ref).
"""
function build_solution(
    ::Type{Common.PointTrait},
    ::Type{Common.StateTrait},
    initial_state,
    result::Integrators.AbstractIntegrationResult, 
)
    return final_state(result)
end

"""
$(TYPEDSIGNATURES)

Default implementation for trajectory configs — wrap the integration result
in a `VectorFieldSolution` for future extensibility.

# Arguments
- `::Type{Common.TrajectoryTrait}`: The trajectory mode trait type.
- `::Type{Common.StateTrait}`: The state content trait type.
- `initial_state`: The initial state.
- `result::Integrators.AbstractIntegrationResult`: The integration result.

# Returns
- `VectorFieldSolution`: The wrapped integration result.

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Solutions.VectorFieldSolution`](@ref), [`CTFlows.Common.TrajectoryTrait`](@ref), [`CTFlows.Common.StateTrait`](@ref).
"""
function build_solution(
    ::Type{Common.TrajectoryTrait},
    ::Type{Common.StateTrait},
    initial_state,
    result::Integrators.AbstractIntegrationResult, 
)
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
_ham_split_solution(u, ::Number) = (u[1], u[2])
_ham_split_solution(u, x0::AbstractVector) = (u[1:length(x0)], u[length(x0)+1:end])
_ham_split_solution(u, x0::AbstractMatrix) = (u[1:size(x0, 1), :], u[size(x0, 1)+1:end, :])

"""
$(TYPEDSIGNATURES)

Split an augmented final state `u` into state `x`, costate `p`, and variable costate `pv` components.

For Hamiltonian systems, `n_p = n_x` always, so the augmented state is `[x; p; pv]` where
`n_pv = length(u) - 2 * n_x`.

# Arguments
- `u`: Augmented final state `[x; p; pv]` from integration.
- `n::Int`: The state dimension `n_x = n_p`.

# Returns
- `Tuple{AbstractVector, AbstractVector, AbstractVector}`: Tuple `(x, p, pv)`.

# Notes
- Internal helper used by `build_solution` for `AugmentedHamiltonianPointConfig`.
- Assumes `n_p = n_x` invariant for Hamiltonian systems.
"""
_aug_split_solution(u, n::Int) = (
    u[1:n],
    u[n+1:2n],
    u[2n+1:end],
)

# =============================================================================
# Solution from HamiltonianVectorFieldSystem
# =============================================================================

"""
$(TYPEDSIGNATURES)

Build a solution for Hamiltonian point configs.

Returns the final state and costate as a tuple `(xf, pf)`, dispatching on the
type of the initial state to handle scalar, vector, and matrix cases.

# Arguments
- `::Type{Common.PointTrait}`: The point mode trait type.
- `::Type{Common.HamiltonianTrait}`: The Hamiltonian content trait type.
- `initial_state`: The initial state (scalar, vector, or matrix).
- `result::Integrators.AbstractIntegrationResult`: The integration result.

# Returns
- `Tuple`: The final state and costate. Type depends on `initial_state`:
  - `Tuple{Number, Number}` for scalar inputs
  - `Tuple{AbstractVector, AbstractVector}` for vector inputs
  - `Tuple{AbstractMatrix, AbstractMatrix}` for matrix inputs

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Common.PointTrait`](@ref), [`CTFlows.Common.HamiltonianTrait`](@ref).
"""
function build_solution(
    ::Type{Common.PointTrait},
    ::Type{Common.HamiltonianTrait},
    initial_state,
    result::Integrators.AbstractIntegrationResult,
    )
    return _ham_split_solution(Integrators.final_state(result), initial_state)
end

"""
$(TYPEDSIGNATURES)

Build a solution for Hamiltonian trajectory configs.

Wraps the integration result in a `HamiltonianVectorFieldSolution` for future extensibility.

# Arguments
- `::Type{Common.TrajectoryTrait}`: The trajectory mode trait type.
- `::Type{Common.HamiltonianTrait}`: The Hamiltonian content trait type.
- `initial_state`: The initial state.
- `result::Integrators.AbstractIntegrationResult`: The integration result.

# Returns
- `HamiltonianVectorFieldSolution`: The wrapped integration result.

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Solutions.HamiltonianVectorFieldSolution`](@ref), [`CTFlows.Common.TrajectoryTrait`](@ref), [`CTFlows.Common.HamiltonianTrait`](@ref).
"""
function build_solution(
    ::Type{Common.TrajectoryTrait},
    ::Type{Common.HamiltonianTrait},
    initial_state,
    result::Integrators.AbstractIntegrationResult,
    )
    return HamiltonianVectorFieldSolution(result)
end

# =============================================================================
# Solution from augmented Hamiltonian systems
# =============================================================================

"""
$(TYPEDSIGNATURES)

Build a solution for augmented Hamiltonian point configs.

Returns the final state, costate, and variable costate as a tuple `(xf, pf, pvf)`.
For Hamiltonian systems, `n_p = n_x` always, so the augmented state `[x; p; pv]`
splits using only the state dimension `n = length(initial_state)`.

# Arguments
- `::Type{Common.PointTrait}`: The point mode trait type.
- `::Type{Common.AugmentedHamiltonianTrait}`: The augmented Hamiltonian content trait type.
- `initial_state`: The initial state (used to determine state dimension `n`).
- `result::Integrators.AbstractIntegrationResult`: The integration result.

# Returns
- `Tuple{AbstractVector, AbstractVector, AbstractVector}`: Tuple `(xf, pf, pvf)`.

# Notes
- Uses `_aug_split_solution` helper to split the augmented final state.
- Assumes `n_p = n_x` invariant for Hamiltonian systems.

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Common.PointTrait`](@ref), [`CTFlows.Common.AugmentedHamiltonianTrait`](@ref).
"""
function build_solution(
    ::Type{Common.PointTrait},
    ::Type{Common.AugmentedHamiltonianTrait},
    initial_state,
    result::Integrators.AbstractIntegrationResult,
)
    return _aug_split_solution(Integrators.final_state(result), length(initial_state))
end
