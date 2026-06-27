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
- `::Type{Traits.EndPointMode}`: The point mode trait type.
- `::Type{Traits.StateDynamics}`: The state content trait type.
- `initial_state::Number`: The scalar initial state.
- `result::Integrators.AbstractIntegrationResult`: The integration result.

# Returns
- `Number`: The unwrapped scalar final state.

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTBase.Traits.EndPointMode`](@ref), [`CTBase.Traits.StateDynamics`](@ref).
"""
function build_trajectory(
    ::Type{Traits.EndPointMode},
    ::Type{Traits.StateDynamics},
    config::Configs.AbstractConfig,
    result::Integrators.AbstractIntegrationResult,
)
    return Core.make_coerce(Configs.initial_state(config))(Integrators.final_state(result))
end

"""
$(TYPEDSIGNATURES)

Default implementation for trajectory configs — wrap the integration result
in a `VectorFieldTrajectory` for future extensibility.

# Arguments
- `::Type{Traits.TrajectoryMode}`: The trajectory mode trait type.
- `::Type{Traits.StateDynamics}`: The state content trait type.
- `initial_state`: The initial state.
- `result::Integrators.AbstractIntegrationResult`: The integration result.

# Returns
- `VectorFieldTrajectory`: The wrapped integration result.

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Trajectories.VectorFieldTrajectory`](@ref), [`CTBase.Traits.TrajectoryMode`](), [`CTBase.Traits.StateDynamics`]().
"""
function build_trajectory(
    ::Type{Traits.TrajectoryMode},
    ::Type{Traits.StateDynamics},
    config::Configs.AbstractConfig,
    result::Integrators.AbstractIntegrationResult,
)
    return VectorFieldTrajectory(result)
end

# =============================================================================
# Internal helpers for Hamiltonian solution splitting
# =============================================================================

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
- Internal helper used by `build_trajectory` for `AugmentedHamiltonianEndPointConfig`.
- Assumes `n_p = n_x` invariant for Hamiltonian systems.
"""
function _aug_split_solution(u, x0, pv0)
    n = length(x0)
    return (
        Core.make_coerce(x0)(u[1:n]),
        Core.make_coerce(x0)(u[(n + 1):2n]),
        Core.make_coerce(pv0)(u[(2n + 1):end]),
    )
end

# =============================================================================
# Solution from HamiltonianVectorFieldSystem
# =============================================================================

"""
$(TYPEDSIGNATURES)

Build a solution for Hamiltonian point configs.

Returns the final state and costate as a tuple `(xf, pf)`, dispatching on the
type of the initial state to handle scalar, vector, and matrix cases.

# Arguments
- `::Type{Traits.EndPointMode}`: The point mode trait type.
- `::Type{Traits.HamiltonianDynamics}`: The Hamiltonian content trait type.
- `initial_state`: The initial state (scalar, vector, or matrix).
- `result::Integrators.AbstractIntegrationResult`: The integration result.

# Returns
- `Tuple`: The final state and costate. Type depends on `initial_state`:
  - `Tuple{Number, Number}` for scalar inputs
  - `Tuple{AbstractVector, AbstractVector}` for vector inputs
  - `Tuple{AbstractMatrix, AbstractMatrix}` for matrix inputs

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTBase.Traits.EndPointMode`](@ref), [`CTBase.Traits.HamiltonianDynamics`]().
"""
function build_trajectory(
    ::Type{Traits.EndPointMode},
    ::Type{Traits.HamiltonianDynamics},
    config::Configs.AbstractConfig,
    result::Integrators.AbstractIntegrationResult,
)
    u = Integrators.final_state(result)
    x0 = Configs.initial_state(config)
    x, p = _ham_split_solution(u, x0)
    return (Core.make_coerce(x0)(x), Core.make_coerce(x0)(p))
end

"""
$(TYPEDSIGNATURES)

Build a solution for Hamiltonian trajectory configs.

Wraps the integration result in a `HamiltonianVectorFieldTrajectory` for future extensibility.

# Arguments
- `::Type{Traits.TrajectoryMode}`: The trajectory mode trait type.
- `::Type{Traits.HamiltonianDynamics}`: The Hamiltonian content trait type.
- `initial_state`: The initial state.
- `result::Integrators.AbstractIntegrationResult`: The integration result.

# Returns
- `HamiltonianVectorFieldTrajectory`: The wrapped integration result.

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTFlows.Trajectories.HamiltonianVectorFieldTrajectory`](@ref), [`CTBase.Traits.TrajectoryMode`](), [`CTBase.Traits.HamiltonianDynamics`]().
"""
function build_trajectory(
    ::Type{Traits.TrajectoryMode},
    ::Type{Traits.HamiltonianDynamics},
    config::Configs.AbstractConfig,
    result::Integrators.AbstractIntegrationResult,
)
    x0 = Configs.initial_state(config)
    return HamiltonianVectorFieldTrajectory(x0, result)
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
- `::Type{Traits.EndPointMode}`: The point mode trait type.
- `::Type{Traits.AugmentedHamiltonianDynamics}`: The augmented Hamiltonian content trait type.
- `initial_state`: The initial state (used to determine state dimension `n`).
- `result::Integrators.AbstractIntegrationResult`: The integration result.

# Returns
- `Tuple{AbstractVector, AbstractVector, AbstractVector}`: Tuple `(xf, pf, pvf)`.

# Notes
- Uses `_aug_split_solution` helper to split the augmented final state.
- Assumes `n_p = n_x` invariant for Hamiltonian systems.

See also: [`CTFlows.Integrators.AbstractIntegrationResult`](@ref), [`CTBase.Traits.EndPointMode`](@ref), [`CTBase.Traits.AugmentedHamiltonianDynamics`]().
"""
function build_trajectory(
    ::Type{Traits.EndPointMode},
    ::Type{Traits.AugmentedHamiltonianDynamics},
    config::Configs.AbstractConfig,
    result::Integrators.AbstractIntegrationResult,
)
    return _aug_split_solution(
        Integrators.final_state(result),
        Configs.initial_state(config),
        Configs.initial_variable_costate(config),
    )
end
