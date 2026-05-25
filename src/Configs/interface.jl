# =============================================================================
# Interface: stubs
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the time span for a configuration (stub method).

This is a stub method on the base `AbstractConfig` type that throws
`NotImplemented`. Concrete subtypes should implement this method to return
their specific time span format.

# Arguments
- `c::AbstractConfig`: The configuration.

# Throws
- `Exceptions.NotImplemented`: Always thrown for the base abstract type.

See also: [`CTFlows.Configs.AbstractConfig`](@ref).
"""
function tspan(c::AbstractConfig)
    throw(Exceptions.NotImplemented(
        "AbstractConfig tspan method not implemented";
        required_method = "tspan(c::$(typeof(c)))",
        suggestion = "Return the time span as a tuple (t0, tf) for this configuration.",
        context = "AbstractConfig.tspan - required method implementation",
    ))
end

function initial_time(c::AbstractConfig)
    throw(Exceptions.NotImplemented(
        "AbstractConfig initial_time method not implemented";
        required_method = "initial_time(c::$(typeof(c)))",
        suggestion = "Return the initial time for this configuration.",
        context = "AbstractConfig.initial_time - required method implementation",
    ))
end

function final_time(c::AbstractConfig)
    throw(Exceptions.NotImplemented(
        "AbstractConfig final_time method not implemented";
        required_method = "final_time(c::$(typeof(c)))",
        suggestion = "Return the final time for this configuration.",
        context = "AbstractConfig.final_time - required method implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Return the initial condition for a configuration (stub method).

This is a stub method on the base `AbstractConfig` type that throws
`NotImplemented`. Concrete subtypes should implement this method to return
their specific initial condition format.

# Arguments
- `c::AbstractConfig`: The configuration.

# Throws
- `Exceptions.NotImplemented`: Always thrown for the base abstract type.

See also: [`CTFlows.Configs.AbstractConfig`](@ref).
"""
function initial_condition(c::AbstractConfig)
    throw(Exceptions.NotImplemented(
        "AbstractConfig initial_condition method not implemented";
        required_method = "initial_condition(c::$(typeof(c)))",
        suggestion = "Return the initial condition for this configuration.",
        context = "AbstractConfig.initial_condition - required method implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Return the initial state for a configuration (stub method).

This is a stub method on the base `AbstractConfig` type that throws
`NotImplemented`. Concrete subtypes should implement this method to return
their specific initial state.

# Arguments
- `c::AbstractConfig`: The configuration.

# Throws
- `Exceptions.NotImplemented`: Always thrown for the base abstract type.

See also: [`CTFlows.Configs.AbstractConfig`](@ref).
"""
function initial_state(c::AbstractConfig)
    throw(Exceptions.NotImplemented(
        "AbstractConfig initial_state method not implemented";
        required_method = "initial_state(c::$(typeof(c)))",
        suggestion = "Return the initial state for this configuration.",
        context = "AbstractConfig.initial_state - required method implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Return the initial costate for a configuration (stub method).

This is a stub method on the base `AbstractConfig` type that throws
`NotImplemented`. Concrete subtypes should implement this method to return
their specific initial costate (if applicable).

# Arguments
- `c::AbstractConfig`: The configuration.

# Throws
- `Exceptions.NotImplemented`: Always thrown for the base abstract type.

See also: [`CTFlows.Configs.AbstractConfig`](@ref).
"""
function initial_costate(c::AbstractConfig)
    throw(Exceptions.NotImplemented(
        "AbstractConfig initial_costate method not implemented";
        required_method = "initial_costate(c::$(typeof(c)))",
        suggestion = "Return the initial costate for this configuration.",
        context = "AbstractConfig.initial_costate - required method implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Return the initial variable costate for a configuration (stub method).

This is a stub method on the base `AbstractConfig` type that throws
`NotImplemented`. Concrete subtypes should implement this method to return
their specific initial variable costate (if applicable).

# Arguments
- `c::AbstractConfig`: The configuration.

# Throws
- `Exceptions.NotImplemented`: Always thrown for the base abstract type.

See also: [`CTFlows.Configs.AbstractConfig`](@ref).
"""
function initial_variable_costate(c::AbstractConfig)
    throw(Exceptions.NotImplemented(
        "AbstractConfig initial_variable_costate method not implemented";
        required_method = "initial_variable_costate(c::$(typeof(c)))",
        suggestion = "Return the initial variable costate for this configuration.",
        context = "AbstractConfig.initial_variable_costate - required method implementation",
    ))
end
