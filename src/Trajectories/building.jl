# =============================================================================
# Solution from VectorFieldSystem
# =============================================================================

"""
$(TYPEDSIGNATURES)

Default implementation for state point configs — return the final state, coerced to a
scalar for a 1-D state.

For scalar or length-1-vector configurations, collapses the final state to a scalar
(the "1-D = scalar" convention, issue #357); vectors of length ≥ 2 and matrices are
left untouched.

# Arguments
- `::Type{Traits.EndPointMode}`: The point mode trait type.
- `::Type{Traits.StateDynamics}`: The state content trait type.
- `config::Configs.AbstractConfig`: The state configuration (its `initial_state` drives
  the coercion).
- `result::Integrators.AbstractIntegrationResult`: The integration result.

# Returns
- The final state, `isa Real`/`Complex` for a 1-D state, `isa AbstractVector`/
  `AbstractMatrix` otherwise.

See also: [`CTFlows.Systems._coerce_state`](@extref), [`CTSolvers.Integrators.AbstractIntegrationResult`](@extref), [`CTBase.Traits.EndPointMode`](@extref), [`CTBase.Traits.StateDynamics`](@extref).
"""
function build_trajectory(
    ::Type{Traits.EndPointMode},
    ::Type{Traits.StateDynamics},
    config::Configs.AbstractConfig,
    result::Integrators.AbstractIntegrationResult,
    variable=Core.NotProvided,
)
    x0 = Configs.initial_state(config)
    return Systems._coerce_state(x0)(Integrators.final_state(result))
end

"""
$(TYPEDSIGNATURES)

Default implementation for trajectory configs — wrap the integration result
in a `VectorFieldTrajectory` for future extensibility.

# Arguments
- `::Type{Traits.TrajectoryMode}`: The trajectory mode trait type.
- `::Type{Traits.StateDynamics}`: The state content trait type.
- `config::Configs.AbstractConfig`: The state configuration (its `initial_state` drives
  the "1-D = scalar" coercion applied by the resulting trajectory's accessors, issue #357).
- `result::Integrators.AbstractIntegrationResult`: The integration result.

# Returns
- `VectorFieldTrajectory`: The wrapped integration result.

See also: [`CTSolvers.Integrators.AbstractIntegrationResult`](@extref), [`CTFlows.Trajectories.VectorFieldTrajectory`](@extref), [`CTBase.Traits.TrajectoryMode`](@extref), [`CTBase.Traits.StateDynamics`](@extref).
"""
function build_trajectory(
    ::Type{Traits.TrajectoryMode},
    ::Type{Traits.StateDynamics},
    config::Configs.AbstractConfig,
    result::Integrators.AbstractIntegrationResult,
    variable=Core.NotProvided,
)
    x0 = Configs.initial_state(config)
    return VectorFieldTrajectory(result, variable, x0)
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
        Systems._coerce_state(x0)(u[1:n]),
        Systems._coerce_state(x0)(u[(n + 1):2n]),
        Systems._coerce_state(pv0)(u[(2n + 1):end]),
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

See also: [`CTSolvers.Integrators.AbstractIntegrationResult`](@extref), [`CTBase.Traits.EndPointMode`](@extref), [`CTBase.Traits.HamiltonianDynamics`](@extref).
"""
function build_trajectory(
    ::Type{Traits.EndPointMode},
    ::Type{Traits.HamiltonianDynamics},
    config::Configs.AbstractConfig,
    result::Integrators.AbstractIntegrationResult,
    variable=Core.NotProvided,
)
    u = Integrators.final_state(result)
    x0 = Configs.initial_state(config)
    x, p = _ham_split_solution(u, x0)
    return (Systems._coerce_state(x0)(x), Systems._coerce_state(x0)(p))
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

See also: [`CTSolvers.Integrators.AbstractIntegrationResult`](@extref), [`CTFlows.Trajectories.HamiltonianVectorFieldTrajectory`](@extref), [`CTBase.Traits.TrajectoryMode`](@extref), [`CTBase.Traits.HamiltonianDynamics`](@extref).
"""
function build_trajectory(
    ::Type{Traits.TrajectoryMode},
    ::Type{Traits.HamiltonianDynamics},
    config::Configs.AbstractConfig,
    result::Integrators.AbstractIntegrationResult,
    variable=Core.NotProvided,
)
    x0 = Configs.initial_state(config)
    return HamiltonianVectorFieldTrajectory(x0, result, variable)
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

See also: [`CTSolvers.Integrators.AbstractIntegrationResult`](@extref), [`CTBase.Traits.EndPointMode`](@extref), [`CTBase.Traits.AugmentedHamiltonianDynamics`](@extref).
"""
function build_trajectory(
    ::Type{Traits.EndPointMode},
    ::Type{Traits.AugmentedHamiltonianDynamics},
    config::Configs.AbstractConfig,
    result::Integrators.AbstractIntegrationResult,
    variable=Core.NotProvided,
)
    return _aug_split_solution(
        Integrators.final_state(result),
        Configs.initial_state(config),
        Configs.initial_variable_costate(config),
    )
end
