# =============================================================================
# Concrete configurations
# =============================================================================

"""
$(TYPEDEF)

Configuration for a point-to-point integration problem.

Defines the initial and final time points along with the initial state for
integration from a single initial condition to a specific final time.

# Fields
- `t0::T0`: Initial time
- `x0::X0`: Initial state vector
- `tf::TF`: Final time

# Example
\`\`\`julia-repl
julia> using CTFlows.Configs

julia> config = StatePointConfig(0.0, [1.0, 0.0], 1.0)
StatePointConfig
  t0: 0.0
  x0: [1.0, 0.0]
  tf: 1.0
\`\`\`

See also: [`CTFlows.Configs.StateTrajectoryConfig`](@ref)
"""
struct StatePointConfig{T0<:Real, X0, TF<:Real} <: AbstractConfigWithMaC{X0, Traits.PointTrait, Traits.StateTrait}
    t0::T0
    x0::X0
    tf::TF
end

"""
$(TYPEDEF)

Configuration for a trajectory integration problem.

Defines a time span and initial state for integration over a continuous
time interval, useful for generating full trajectories.

# Fields
- `tspan::TS`: Time span as a tuple (t0, tf)
- `x0::X0`: Initial state vector

# Example
\`\`\`julia-repl
julia> using CTFlows.Configs

julia> config = StateTrajectoryConfig((0.0, 1.0), [1.0, 0.0])
StateTrajectoryConfig
  tspan: (0.0, 1.0)
  x0: [1.0, 0.0]
\`\`\`

See also: [`CTFlows.Configs.StatePointConfig`](@ref)
"""
struct StateTrajectoryConfig{TS<:Tuple{<:Real,<:Real}, X0} <: AbstractConfigWithMaC{X0, Traits.TrajectoryTrait, Traits.StateTrait}
    tspan::TS
    x0::X0
end


"""
$(TYPEDEF)

Configuration for a Hamiltonian point-to-point integration problem.

Defines the initial and final time points along with the initial state and costate
for integration from a single initial condition to a specific final time in the
Hamiltonian framework.

# Fields
- `t0::T0`: Initial time
- `x0::X0`: Initial state vector
- `p0::P0`: Initial costate vector
- `tf::TF`: Final time

# Example
\`\`\`julia-repl
julia> using CTFlows.Configs

julia> config = HamiltonianPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], 1.0)
HamiltonianPointConfig
  t0: 0.0
  x0: [1.0, 0.0]
  p0: [0.5, 0.3]
  tf: 1.0
\`\`\`

See also: [`CTFlows.Configs.HamiltonianTrajectoryConfig`](@ref), [`CTFlows.Configs.StatePointConfig`](@ref).
"""
struct HamiltonianPointConfig{T0<:Real, X0, P0, TF<:Real} <: AbstractConfigWithMaC{X0, Traits.PointTrait, Traits.HamiltonianTrait}
    t0::T0
    x0::X0
    p0::P0
    tf::TF
end

"""
$(TYPEDEF)

Configuration for a Hamiltonian trajectory integration problem.

Defines a time span and initial state and costate for integration over a
continuous time interval in the Hamiltonian framework, useful for generating
full Hamiltonian trajectories.

# Fields
- `tspan::TS`: Time span as a tuple (t0, tf)
- `x0::X0`: Initial state vector
- `p0::P0`: Initial costate vector

# Example
\`\`\`julia-repl
julia> using CTFlows.Configs

julia> config = HamiltonianTrajectoryConfig((0.0, 1.0), [1.0, 0.0], [0.5, 0.3])
HamiltonianTrajectoryConfig
  tspan: (0.0, 1.0)
  x0: [1.0, 0.0]
  p0: [0.5, 0.3]
\`\`\`

See also: [`CTFlows.Configs.HamiltonianPointConfig`](@ref), [`CTFlows.Configs.StateTrajectoryConfig`](@ref).
"""
struct HamiltonianTrajectoryConfig{TS<:Tuple{<:Real,<:Real}, X0, P0} <: AbstractConfigWithMaC{X0, Traits.TrajectoryTrait, Traits.HamiltonianTrait}
    tspan::TS
    x0::X0
    p0::P0
end

"""
$(TYPEDEF)

Configuration for an augmented Hamiltonian point-to-point integration problem.

Defines the initial and final time points along with the initial state, costate,
and variable costate for integration from a single initial condition to a specific
final time in the augmented Hamiltonian framework.

# Fields
- `t0::T0`: Initial time
- `x0::X0`: Initial state vector
- `p0::P0`: Initial costate vector
- `pv0::PV0`: Initial variable costate vector (typically zeros)
- `tf::TF`: Final time

# Example
\`\`\`julia-repl
julia> using CTFlows.Configs

julia> config = AugmentedHamiltonianPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], [0.0, 0.0], 1.0)
AugmentedHamiltonianPointConfig
  t0: 0.0
  x0: [1.0, 0.0]
  p0: [0.5, 0.3]
  pv0: [0.0, 0.0]
  tf: 1.0
\`\`\`

See also: [`CTFlows.Configs.HamiltonianPointConfig`](@ref), [`CTFlows.Traits.AugmentedHamiltonianTrait`](@ref).
"""
struct AugmentedHamiltonianPointConfig{T0<:Real, X0, P0, PV0, TF<:Real} <: AbstractAugmentedHamiltonianConfig{X0, Traits.PointTrait}
    t0::T0
    x0::X0
    p0::P0
    pv0::PV0
    tf::TF
end

"""
$(TYPEDSIGNATURES)

Return the initial condition for augmented Hamiltonian configurations.

For augmented Hamiltonian systems, the initial condition is the concatenation of the
initial state, initial costate, and initial variable costate: `vcat(x0, p0, pv0)`.

# Arguments
- `c::AugmentedHamiltonianPointConfig`: The augmented Hamiltonian configuration.

# Returns
- Concatenated vector `[x0; p0; pv0]`.

See also: [`CTFlows.Configs.AugmentedHamiltonianPointConfig`](@ref), [`CTFlows.Configs.initial_state`](@ref), [`CTFlows.Configs.initial_costate`](@ref), [`CTFlows.Configs.initial_variable_costate`](@ref).
"""
function initial_condition(c::AugmentedHamiltonianPointConfig)
    return vcat(c.x0, c.p0, c.pv0)
end

"""
$(TYPEDSIGNATURES)

Return the initial costate for augmented Hamiltonian configurations.

Extracts the initial costate field from the augmented Hamiltonian configuration.

# Arguments
- `c::AugmentedHamiltonianPointConfig`: The augmented Hamiltonian configuration.

# Returns
- The initial costate vector.

See also: [`CTFlows.Configs.AugmentedHamiltonianPointConfig`](@ref).
"""
function initial_costate(c::AugmentedHamiltonianPointConfig)
    return c.p0
end

"""
$(TYPEDSIGNATURES)

Return the initial variable costate for augmented Hamiltonian configurations.

Extracts the initial variable costate field from the augmented Hamiltonian configuration.

# Arguments
- `c::AugmentedHamiltonianPointConfig`: The augmented Hamiltonian configuration.

# Returns
- The initial variable costate vector.

See also: [`CTFlows.Configs.AugmentedHamiltonianPointConfig`](@ref).
"""
function initial_variable_costate(c::AugmentedHamiltonianPointConfig)
    return c.pv0
end
