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

# Example

\`\`\`julia
using CTFlows.Systems
using CTFlows.Common

# Define a concrete system
struct MySystem <: Systems.AbstractSystem
    data::Vector{Float64}
end

# Implement required contract methods
function Systems.rhs!(sys::MySystem)
    return (du, u, p, t) -> du .= sys.data .* u
end

function Common.variable_dependence(sys::MySystem)
    return Common.NonFixed
end

function Common.time_dependence(sys::MySystem)
    return Common.Autonomous
end
\`\`\`

See also: [`CTFlows.Systems.rhs!`](@ref), [`CTFlows.Common.time_dependence`](@ref), [`CTFlows.Common.variable_dependence`](@ref).
"""
abstract type AbstractSystem end

"""
$(TYPEDSIGNATURES)

Indicate that `AbstractSystem` has the time-dependence trait.

This implementation declares that all systems support time-dependence queries.
Concrete subtypes must implement `time_dependence` to return the specific trait value.

# Example

\`\`\`julia
using CTFlows.Systems
using CTFlows.Common

struct MySystem <: Systems.AbstractSystem end

# All systems have the time-dependence trait
Common.has_time_dependence_trait(MySystem)  # Returns true

# Concrete subtypes must implement time_dependence
function Common.time_dependence(sys::MySystem)
    return Common.Autonomous
end
\`\`\`

See also: [`CTFlows.Common.time_dependence`](@ref), [`CTFlows.Systems.AbstractSystem`](@ref).
"""
Common.has_time_dependence_trait(::AbstractSystem) = true

"""
$(TYPEDSIGNATURES)

Indicate that `AbstractSystem` has the variable-dependence trait.

This implementation declares that all systems support variable-dependence queries.
Concrete subtypes must implement `variable_dependence` to return the specific trait value.

# Example

\`\`\`julia
using CTFlows.Systems
using CTFlows.Common

struct MySystem <: Systems.AbstractSystem end

# All systems have the variable-dependence trait
Common.has_variable_dependence_trait(MySystem)  # Returns true

# Concrete subtypes must implement variable_dependence
function Common.variable_dependence(sys::MySystem)
    return Common.NonFixed
end
\`\`\`

See also: [`CTFlows.Common.variable_dependence`](@ref), [`CTFlows.Systems.AbstractSystem`](@ref).
"""
Common.has_variable_dependence_trait(::AbstractSystem) = true

"""
$(TYPEDSIGNATURES)

Return the right-hand side function for the system.

The returned function must have the signature `(du, u, p, t) -> nothing` and
fill `du` in place with the derivative at state `u`, parameters `p`, and time `t`.

# Example

\`\`\`julia
using CTFlows.Systems

struct MySystem <: Systems.AbstractSystem
    data::Vector{Float64}
end

# Implement rhs! to return the ODE right-hand side function
function Systems.rhs!(sys::MySystem)
    return (du, u, p, t) -> du .= sys.data .* u
end

# Usage
sys = MySystem([1.0, 2.0])
rhs_func = Systems.rhs!(sys)
du = zeros(2)
rhs_func(du, [3.0, 4.0], [], 0.0)  # du becomes [3.0, 8.0]
\`\`\`

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

