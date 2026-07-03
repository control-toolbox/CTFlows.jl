"""
$(TYPEDEF)

Abstract type for all systems in CTFlows.

An `AbstractSystem` represents a fully assembled object that can be integrated.
It embeds its own right-hand side, dimensional metadata, and solution-building logic.

# Contract

All subtypes must implement:

- `get_ip_rhs(system::AbstractSystem, config)`: Returns a function `(du, u, p, t) -> nothing` that fills `du` in place.
- `get_oop_rhs(system::AbstractSystem, config)`: Returns a function `(u, p, t) -> du` that returns the derivative.

Hamiltonian systems supporting variable-costate integration additionally implement
`get_ip_rhs_augmented(system::AbstractHamiltonianSystem, config)`.

# Example

\`\`\`julia
using CTFlows.Systems

# Define a concrete system
struct MySystem <: Systems.AbstractSystem{Traits.Autonomous, Traits.Fixed, Traits.StateDynamics}
    data::Vector{Float64}
end

# Implement required contract methods
function Systems.get_ip_rhs(sys::MySystem, config)
    return (du, u, p, t) -> du .= sys.data .* u
end

function Systems.get_oop_rhs(sys::MySystem, config)
    return (u, p, t) -> sys.data .* u
end
\`\`\`

See also: [`CTFlows.Systems.get_ip_rhs`](@ref), [`CTFlows.Systems.get_oop_rhs`](@ref), [`CTFlows.Systems.get_ip_rhs_augmented`](@ref), [`CTBase.Traits.time_dependence`](@extref), [`CTBase.Traits.variable_dependence`](@extref).
"""
abstract type AbstractSystem{TD<:Traits.TimeDependence, VD<:Traits.VariableDependence, D<:Traits.AbstractDynamicsTrait} end

"""
$(TYPEDEF)

Alias for state systems (non-Hamiltonian).

Matches any `AbstractSystem` with `StateDynamics` as the dynamics parameter.

# Type Parameters
- `TD <: TimeDependence`: Time dependence trait (Autonomous or NonAutonomous)
- `VD <: VariableDependence`: Variable dependence trait (Fixed or NonFixed)

# Example
\`\`\`julia-repl
julia> using CTFlows.Systems

julia> VectorFieldSystem <: Systems.AbstractStateSystem
true
\`\`\`

See also: [`CTFlows.Systems.AbstractSystem`](@ref), [`CTFlows.Systems.AbstractHamiltonianSystem`](@ref).
"""
const AbstractStateSystem{TD, VD} = AbstractSystem{TD, VD, Traits.StateDynamics}

"""
$(TYPEDEF)

Alias for Hamiltonian systems.

Matches any `AbstractSystem` with `HamiltonianDynamics` as the dynamics parameter.
The AD capability is encoded as a plain trait (`ad_trait`) on the concrete type,
not as a type parameter of this alias.

# Type Parameters
- `TD <: TimeDependence`: Time dependence trait (Autonomous or NonAutonomous)
- `VD <: VariableDependence`: Variable dependence trait (Fixed or NonFixed)

# Example
\`\`\`julia-repl
julia> using CTFlows.Systems

julia> HamiltonianSystem <: Systems.AbstractHamiltonianSystem
true
\`\`\`

See also: [`CTFlows.Systems.AbstractSystem`](@ref), [`CTFlows.Systems.AbstractStateSystem`](@ref).
"""
const AbstractHamiltonianSystem{TD, VD} = AbstractSystem{TD, VD, Traits.HamiltonianDynamics}

"""
$(TYPEDSIGNATURES)

Indicate that `AbstractSystem` has the time-dependence trait.

This implementation declares that all systems support time-dependence queries.
Concrete subtypes must implement `time_dependence` to return the specific trait value.

# Example

\`\`\`julia
using CTFlows.Systems

struct MySystem <: Systems.AbstractSystem end

# All systems have the time-dependence trait
Traits.has_time_dependence_trait(MySystem)  # Returns true

# Concrete subtypes must implement time_dependence
function Traits.time_dependence(sys::MySystem)
    return Traits.Autonomous
end
\`\`\`

See also: [`CTBase.Traits.time_dependence`](@extref), [`CTFlows.Systems.AbstractSystem`](@ref).
"""
Traits.has_time_dependence_trait(::AbstractSystem) = true

"""
$(TYPEDSIGNATURES)

Indicate that `AbstractSystem` has the variable-dependence trait.

This implementation declares that all systems support variable-dependence queries.
Concrete subtypes must implement `variable_dependence` to return the specific trait value.

# Example

\`\`\`julia
using CTFlows.Systems

struct MySystem <: Systems.AbstractSystem end

# All systems have the variable-dependence trait
Traits.has_variable_dependence_trait(MySystem)  # Returns true

# Concrete subtypes must implement variable_dependence
function Traits.variable_dependence(sys::MySystem)
    return Traits.NonFixed
end
\`\`\`

See also: [`CTBase.Traits.variable_dependence`](@extref), [`CTFlows.Systems.AbstractSystem`](@ref).
"""
Traits.has_variable_dependence_trait(::AbstractSystem) = true

"""
$(TYPEDSIGNATURES)

Extract the time dependence trait from an `AbstractSystem`.

# Returns
- `Type{<:TimeDependence}`: The time dependence trait type (Autonomous or NonAutonomous).

# Example
\`\`\`julia
using CTFlows.Systems

struct MySystem <: Systems.AbstractSystem{Traits.Autonomous, Traits.Fixed, Traits.StateDynamics}
    data::Vector{Float64}
end

Traits.time_dependence(MySystem)  # Returns Autonomous
\`\`\`

See also: [`CTBase.Traits.has_time_dependence_trait`](@extref), `is_autonomous`, [`CTFlows.Systems.AbstractSystem`](@ref).
"""
function Traits.time_dependence(::AbstractSystem{TD, <:Traits.VariableDependence, <:Traits.AbstractDynamicsTrait}) where {TD <: Traits.TimeDependence}
    return TD
end

"""
$(TYPEDSIGNATURES)

Extract the variable dependence trait from an `AbstractSystem`.

# Returns
- `Type{<:VariableDependence}`: The variable dependence trait type (Fixed or NonFixed).

# Example
\`\`\`julia
using CTFlows.Systems

struct MySystem <: Systems.AbstractSystem{Traits.Autonomous, Traits.Fixed, Traits.StateDynamics}
    data::Vector{Float64}
end

Traits.variable_dependence(MySystem)  # Returns Fixed
\`\`\`

See also: [`CTBase.Traits.has_variable_dependence_trait`](@extref), `is_variable`, [`CTFlows.Systems.AbstractSystem`](@ref).
"""
function Traits.variable_dependence(::AbstractSystem{<:Traits.TimeDependence, VD, <:Traits.AbstractDynamicsTrait}) where {VD <: Traits.VariableDependence}
    return VD
end

"""
$(TYPEDSIGNATURES)

Extract the dynamics trait from an `AbstractSystem`.

# Returns
- `Type{<:AbstractDynamicsTrait}`: `StateDynamics` or `HamiltonianDynamics`.

See also: [`CTBase.Traits.AbstractDynamicsTrait`](@extref), [`CTFlows.Systems.AbstractStateSystem`](@ref), [`CTFlows.Systems.AbstractHamiltonianSystem`](@ref).
"""
function Traits.dynamics_trait(::AbstractSystem{<:Traits.TimeDependence, <:Traits.VariableDependence, D}) where {D <: Traits.AbstractDynamicsTrait}
    return D
end

"""
$(TYPEDSIGNATURES)

Return the variable costate capability trait of a system.

# Arguments
- `sys::AbstractSystem`: The system (default implementation returns `NoVariableCostate`).

# Returns
- `Type{<:AbstractVariableCostateCapability}`: The capability trait, either
  `SupportsVariableCostate` or `NoVariableCostate`.

# Notes
- Default implementation returns `NoVariableCostate` for all systems
- Specialized implementation on `HamiltonianSystem` with `NonFixed` returns `SupportsVariableCostate`
- This trait is used for dispatch in `_invoke_flow_variable_costate` to determine if augmented integration is possible

See also: [`CTBase.Traits.AbstractVariableCostateCapability`](@extref), [`CTBase.Traits.SupportsVariableCostate`](@extref), [`CTBase.Traits.NoVariableCostate`](@extref).
"""
Traits.variable_costate_trait(::AbstractSystem) = Traits.NoVariableCostate

"""
$(TYPEDSIGNATURES)

Return the in-place right-hand side function for a system given a configuration.

The returned function must have the signature `(du, u, p, t) -> nothing` and
fill `du` in place with the derivative at state `u`, parameters `p`, and time `t`.

Eager systems (e.g., `VectorFieldSystem`) ignore the config and return pre-computed closures.
Lazy systems (e.g., `HamiltonianSystem`) read `x0`/`p0` from the config to build type-specific closures.

# Arguments
- `system::AbstractSystem`: The system.
- `config`: The configuration containing initial conditions and time span.

# Returns
- `Function`: The in-place RHS closure with signature `(du, u, p, t) -> nothing`.

# Throws
- [`CTBase.Exceptions.NotImplemented`](@extref): If not implemented by the concrete type.

See also: [`CTFlows.Systems.get_oop_rhs`](@ref), [`CTFlows.Systems.get_ip_rhs_augmented`](@ref).
"""
function get_ip_rhs(system::AbstractSystem, config)
    throw(
        Exceptions.NotImplemented(
            "AbstractSystem get_ip_rhs method not implemented";
            required_method = "get_ip_rhs(sys::$(typeof(system)), config)",
            suggestion = "Implement get_ip_rhs for your system type.",
            context = "AbstractSystem.get_ip_rhs - required method implementation",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Return the out-of-place right-hand side function for a system given a configuration.

The returned function must have the signature `(u, p, t) -> du` and
return the derivative at state `u`, parameters `p`, and time `t` without modifying `u`.

Eager systems ignore the config and return pre-computed closures.
Lazy systems read `x0`/`p0` from the config to build type-specific closures.

# Arguments
- `system::AbstractSystem`: The system.
- `config`: The configuration containing initial conditions and time span.

# Returns
- `Function`: The out-of-place RHS closure with signature `(u, p, t) -> du`.

# Throws
- [`CTBase.Exceptions.NotImplemented`](@extref): If not implemented by the concrete type.

See also: [`CTFlows.Systems.get_ip_rhs`](@ref), [`CTFlows.Systems.get_ip_rhs_augmented`](@ref).
"""
function get_oop_rhs(system::AbstractSystem, config)
    throw(
        Exceptions.NotImplemented(
            "AbstractSystem get_oop_rhs method not implemented";
            required_method = "get_oop_rhs(sys::$(typeof(system)), config)",
            suggestion = "Implement get_oop_rhs for your system type.",
            context = "AbstractSystem.get_oop_rhs - required method implementation",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Return the augmented in-place right-hand side function for a Hamiltonian system.

The returned function computes state, costate, and variable costate derivatives.
Only applicable to Hamiltonian systems with variable costate support.

# Arguments
- `system::AbstractHamiltonianSystem`: The Hamiltonian system.
- `config`: The augmented Hamiltonian configuration containing `x0`, `p0`, and `pv0`.

# Returns
- `Function`: The augmented in-place RHS closure with signature `(du, u, p, t) -> nothing`.

# Throws
- [`CTBase.Exceptions.NotImplemented`](@extref): If not implemented by the concrete type.

See also: [`CTFlows.Systems.get_ip_rhs`](@ref), [`CTFlows.Systems.get_oop_rhs`](@ref).
"""
function get_ip_rhs_augmented(system::AbstractHamiltonianSystem, config)
    throw(
        Exceptions.NotImplemented(
            "AbstractHamiltonianSystem get_ip_rhs_augmented method not implemented";
            required_method = "get_ip_rhs_augmented(sys::$(typeof(system)), config)",
            suggestion = "Implement get_ip_rhs_augmented for your Hamiltonian system type.",
            context = "AbstractHamiltonianSystem.get_ip_rhs_augmented - required method implementation",
        ),
    )
end
