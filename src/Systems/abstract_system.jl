"""
$(TYPEDEF)

Abstract type for all systems in CTFlows.

An `AbstractSystem` represents a fully assembled object that can be integrated.
It embeds its own `rhs!`, dimensional metadata, and solution-building logic.

# Contract

All subtypes must implement:
- `rhs!(system::AbstractSystem)`: Returns a function `(du, u, p, t) -> nothing` that fills `du` in place.
- `variable_dependence(system::AbstractSystem)`: Returns the variable-dependence trait (`Fixed` or `NonFixed`).
- `time_dependence(system::AbstractSystem)`: Returns the time-dependence trait (`Autonomous` or `NonAutonomous`).

See also: [`CTFlows.Systems.rhs!`](@ref), [`CTFlows.Common.time_dependence`](@ref), [`CTFlows.Common.variable_dependence`](@ref).
"""
abstract type AbstractSystem end

"""
$(TYPEDSIGNATURES)

Indicate that `AbstractSystem` has the time-dependence trait.

This implementation declares that all systems support time-dependence queries.
Concrete subtypes must implement `time_dependence` to return the specific trait value.
"""
Common.has_time_dependence_trait(::AbstractSystem) = true

"""
$(TYPEDSIGNATURES)

Indicate that `AbstractSystem` has the variable-dependence trait.

This implementation declares that all systems support variable-dependence queries.
Concrete subtypes must implement `variable_dependence` to return the specific trait value.
"""
Common.has_variable_dependence_trait(::AbstractSystem) = true

"""
$(TYPEDSIGNATURES)

Return the right-hand side function for the system.

The returned function must have the signature `(du, u, p, t) -> nothing` and
fill `du` in place with the derivative at state `u`, parameters `p`, and time `t`.

# Throws
- [`CTBase.Exceptions.NotImplemented`](@extref): If not implemented by the concrete type.

See also: [`CTFlows.Systems.AbstractSystem`](@ref).
"""
function rhs!(system::AbstractSystem)
    throw(
        Exceptions.NotImplemented(
            "AbstractSystem rhs! method not implemented";
            required_method = "rhs!(system::$(typeof(system)))",
            suggestion = "Return a function (du, u, p, t) -> nothing that fills du in place.",
            context = "AbstractSystem.rhs! - required method implementation",
        ),
    )
end

