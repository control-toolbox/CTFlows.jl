# =============================================================================
# build_options — CTFlows glue: select the integrator's cached option bundle
# per configuration type (dispatch on Configs; read via CTSolvers accessors)
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return pre-computed solver options for point integration configs.

For point configs (e.g., `StateEndPointConfig`, `HamiltonianEndPointConfig`), options like
`dense`, `save_everystep`, and `save_start` are set to `false` to minimize memory since only
the final state is needed.

# Arguments
- `integ::SciML`: The SciML integrator with pre-computed option caches.
- `config::Configs.AbstractEndPointConfig`: The point configuration.

# Returns
- `Dict{Symbol,Any}`: Pre-computed options optimized for point integration.

See also: [`CTFlows.Integrators.build_options`](@extref), [`CTFlows.Configs.AbstractEndPointConfig`](@extref).
"""
function Integrators.build_options(
    integ::Integrators.SciML, config::Configs.AbstractEndPointConfig
)
    return Integrators.options_point(integ)
end

"""
$(TYPEDSIGNATURES)

Return pre-computed solver options for trajectory integration configs.

For trajectory configs (e.g., `StateTrajectoryConfig`, `HamiltonianTrajectoryConfig`), options
like `dense`, `save_everystep`, and `save_start` are set to `true` to enable full trajectory
storage and interpolation.

# Arguments
- `integ::SciML`: The SciML integrator with pre-computed option caches.
- `config::Configs.AbstractTrajectoryConfig`: The trajectory configuration.

# Returns
- `Dict{Symbol,Any}`: Pre-computed options optimized for trajectory integration.

See also: [`CTFlows.Integrators.build_options`](@extref), [`CTFlows.Configs.AbstractTrajectoryConfig`](@extref).
"""
function Integrators.build_options(
    integ::Integrators.SciML, config::Configs.AbstractTrajectoryConfig
)
    return Integrators.options_trajectory(integ)
end

"""
$(TYPEDSIGNATURES)

Return pre-computed solver options for the fallback case (`nothing`).

Defaults to trajectory options when no configuration is provided.

# Arguments
- `integ::SciML`: The SciML integrator with pre-computed option caches.
- `config::Nothing`: No configuration provided (fallback).

# Returns
- `Dict{Symbol,Any}`: Pre-computed options for trajectory integration (fallback).

See also: [`CTFlows.Integrators.build_options`](@extref).
"""
function Integrators.build_options(integ::Integrators.SciML, config::Nothing)
    return Integrators.options_trajectory(integ)  # fallback vers Trajectory par défaut
end
