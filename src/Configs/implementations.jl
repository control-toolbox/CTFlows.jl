# =============================================================================
# Interface implementations on abstract config types
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the time span as a tuple for point configurations.

For point configurations, extracts the initial and final times from the
`t0` and `tf` fields.

# Arguments
- `c::AbstractEndPointConfig`: The point configuration.

# Returns
- `Tuple{Real, Real}`: Time span as (t0, tf).

See also: [`CTFlows.Configs.AbstractEndPointConfig`](@ref), [`CTFlows.Configs.tspan`](@ref).
"""
function tspan(c::AbstractEndPointConfig)::Tuple{Real,Real}
    return (c.t0, c.tf)
end

"""
$(TYPEDSIGNATURES)

Return the time span for trajectory configurations.

For trajectory configurations, returns the stored `tspan` field directly.

# Arguments
- `c::AbstractTrajectoryConfig`: The trajectory configuration.

# Returns
- `Tuple{Real, Real}`: Time span as (t0, tf).

See also: [`CTFlows.Configs.AbstractTrajectoryConfig`](@ref), [`CTFlows.Configs.tspan`](@ref).
"""
function tspan(c::AbstractTrajectoryConfig)::Tuple{Real,Real}
    return c.tspan
end

"""
$(TYPEDSIGNATURES)

Return the initial time for point configurations.

For point configurations, returns the stored `t0` field directly.

# Arguments
- `c::AbstractEndPointConfig`: The point configuration.

# Returns
- `Real`: Initial time t0.

See also: [`CTFlows.Configs.AbstractEndPointConfig`](@ref), [`CTFlows.Configs.initial_time`](@ref).
"""
function initial_time(c::AbstractEndPointConfig)::Real
    return c.t0
end

"""
$(TYPEDSIGNATURES)

Return the initial time for trajectory configurations.

For trajectory configurations, returns the first element of the stored `tspan` field.

# Arguments
- `c::AbstractTrajectoryConfig`: The trajectory configuration.

# Returns
- `Real`: Initial time t0.

See also: [`CTFlows.Configs.AbstractTrajectoryConfig`](@ref), [`CTFlows.Configs.initial_time`](@ref).
"""
function initial_time(c::AbstractTrajectoryConfig)::Real
    return c.tspan[1]
end

"""
$(TYPEDSIGNATURES)

Return the final time for point configurations.

For point configurations, returns the stored `tf` field directly.

# Arguments
- `c::AbstractEndPointConfig`: The point configuration.

# Returns
- `Real`: Final time tf.

See also: [`CTFlows.Configs.AbstractEndPointConfig`](@ref), [`CTFlows.Configs.final_time`](@ref).
"""
function final_time(c::AbstractEndPointConfig)::Real
    return c.tf
end

"""
$(TYPEDSIGNATURES)

Return the final time for trajectory configurations.

For trajectory configurations, returns the second element of the stored `tspan` field.

# Arguments
- `c::AbstractTrajectoryConfig`: The trajectory configuration.

# Returns
- `Real`: Final time tf.

See also: [`CTFlows.Configs.AbstractTrajectoryConfig`](@ref), [`CTFlows.Configs.final_time`](@ref).
"""
function final_time(c::AbstractTrajectoryConfig)::Real
    return c.tspan[2]
end

"""
$(TYPEDSIGNATURES)

Return the initial condition as a vector for scalar state configurations.

For scalar initial conditions, wraps the scalar in a length-1 vector to
maintain consistent vector-based ODE problem construction.

# Arguments
- `c::AbstractStateConfig{<:Number, M}`: The state configuration with scalar initial state.

# Returns
- `Vector{<:Number}`: Length-1 vector containing the scalar initial state.

See also: [`CTFlows.Configs.AbstractStateConfig`](@ref), [`CTFlows.Configs.initial_condition`](@ref).
"""
function initial_condition(
    c::AbstractStateConfig{<:Number,M}
) where {M<:Traits.AbstractModeTrait}
    return [c.x0]
end

"""
$(TYPEDSIGNATURES)

Return the initial condition for state configurations.

For vector initial conditions, returns the state vector directly.

# Arguments
- `c::AbstractStateConfig`: The state configuration.

# Returns
- The initial state vector.

See also: [`CTFlows.Configs.AbstractStateConfig`](@ref).
"""
function initial_condition(c::AbstractStateConfig)
    return c.x0
end

"""
$(TYPEDSIGNATURES)

Return the initial condition for Hamiltonian configurations.

For Hamiltonian systems, the initial condition is the concatenation of the
initial state and initial costate: `vcat(x0, p0)`.

# Arguments
- `c::AbstractHamiltonianConfig`: The Hamiltonian configuration.

# Returns
- Concatenated vector `[x0; p0]`.

See also: [`CTFlows.Configs.AbstractHamiltonianConfig`](@ref), [`CTFlows.Configs.initial_state`](@ref), [`CTFlows.Configs.initial_costate`](@ref).
"""
function initial_condition(c::AbstractHamiltonianConfig)
    return vcat(c.x0, c.p0)
end

"""
$(TYPEDSIGNATURES)

Return the initial state from a configuration.

Extracts the initial state field from the configuration.

# Arguments
- `c::AbstractConfigWithMaC`: The configuration with mode and content traits.

# Returns
- The initial state vector.

See also: [`CTFlows.Configs.AbstractConfigWithMaC`](@ref).
"""
function initial_state(c::AbstractConfigWithMaC)
    return c.x0
end

"""
$(TYPEDSIGNATURES)

Return the initial costate for state configurations (error stub).

State configurations do not have a costate field. This method throws a
`PreconditionError` to enforce the contract that `initial_costate` is only
defined for Hamiltonian configurations.

# Arguments
- `c::AbstractStateConfig`: The state configuration.

# Throws
- `Exceptions.PreconditionError`: Always thrown for state configurations.

See also: [`CTFlows.Configs.AbstractStateConfig`](@ref), [`CTFlows.Configs.AbstractHamiltonianConfig`](@ref), [`CTFlows.Configs.initial_costate`](@ref).
"""
function initial_costate(c::AbstractStateConfig)
    return throw(
        Exceptions.PreconditionError(
            "initial_costate is only defined for Hamiltonian configs";
            context="initial_costate - requires Hamiltonian config",
            reason="config type $(typeof(c)) does not have a costate field",
            suggestion="use HamiltonianEndPointConfig or HamiltonianTrajectoryConfig instead",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Return the initial costate for Hamiltonian configurations.

Extracts the initial costate field from the Hamiltonian configuration.

# Arguments
- `c::AbstractHamiltonianConfig`: The Hamiltonian configuration.

# Returns
- The initial costate vector.

See also: [`CTFlows.Configs.AbstractHamiltonianConfig`](@ref).
"""
function initial_costate(c::AbstractHamiltonianConfig)
    return c.p0
end
