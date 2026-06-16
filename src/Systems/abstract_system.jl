"""
$(TYPEDEF)

Abstract type for all systems in CTFlows.

An `AbstractSystem` represents a fully assembled object that can be integrated.
It embeds its own `rhs`, dimensional metadata, and solution-building logic.

# Contract

All subtypes must implement:

- `rhs(system::AbstractSystem)`: Returns a function `(du, u, p, t) -> nothing` that fills `du` in place.

# Example

\`\`\`julia
using CTFlows.Systems
using CTFlows.Common

# Define a concrete system
struct MySystem <: Systems.AbstractSystem{Traits.Autonomous, Traits.Fixed, Traits.StateDynamics}
    data::Vector{Float64}
end

# Implement required contract method
function Systems.rhs(sys::MySystem)
    return (du, u, p, t) -> du .= sys.data .* u
end
\`\`\`

See also: [`CTFlows.Systems.rhs`](@ref), [`CTFlows.Traits.time_dependence`](@ref), [`CTFlows.Traits.variable_dependence`](@ref).
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
using CTFlows.Common

struct MySystem <: Systems.AbstractSystem end

# All systems have the time-dependence trait
Traits.has_time_dependence_trait(MySystem)  # Returns true

# Concrete subtypes must implement time_dependence
function Traits.time_dependence(sys::MySystem)
    return Traits.Autonomous
end
\`\`\`

See also: [`CTFlows.Traits.time_dependence`](@ref), [`CTFlows.Systems.AbstractSystem`](@ref).
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
using CTFlows.Common

struct MySystem <: Systems.AbstractSystem end

# All systems have the variable-dependence trait
Traits.has_variable_dependence_trait(MySystem)  # Returns true

# Concrete subtypes must implement variable_dependence
function Traits.variable_dependence(sys::MySystem)
    return Traits.NonFixed
end
\`\`\`

See also: [`CTFlows.Traits.variable_dependence`](@ref), [`CTFlows.Systems.AbstractSystem`](@ref).
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
using CTFlows.Common

struct MySystem <: Systems.AbstractSystem{Traits.Autonomous, Traits.Fixed, Traits.StateDynamics}
    data::Vector{Float64}
end

Traits.time_dependence(MySystem)  # Returns Autonomous
\`\`\`

See also: [`CTFlows.Traits.has_time_dependence_trait`](@ref), `is_autonomous`, [`CTFlows.Systems.AbstractSystem`](@ref).
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
using CTFlows.Common

struct MySystem <: Systems.AbstractSystem{Traits.Autonomous, Traits.Fixed, Traits.StateDynamics}
    data::Vector{Float64}
end

Traits.variable_dependence(MySystem)  # Returns Fixed
\`\`\`

See also: [`CTFlows.Traits.has_variable_dependence_trait`](@ref), `is_variable`, [`CTFlows.Systems.AbstractSystem`](@ref).
"""
function Traits.variable_dependence(::AbstractSystem{<:Traits.TimeDependence, VD, <:Traits.AbstractDynamicsTrait}) where {VD <: Traits.VariableDependence}
    return VD
end

"""
$(TYPEDSIGNATURES)

Extract the dynamics trait from an `AbstractSystem`.

# Returns
- `Type{<:AbstractDynamicsTrait}`: `StateDynamics` or `HamiltonianDynamics`.

See also: [`CTFlows.Traits.AbstractDynamicsTrait`](@ref), [`CTFlows.Systems.AbstractStateSystem`](@ref), [`CTFlows.Systems.AbstractHamiltonianSystem`](@ref).
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

See also: [`CTFlows.Traits.AbstractVariableCostateCapability`](@ref), [`CTFlows.Traits.SupportsVariableCostate`](@ref), [`CTFlows.Traits.NoVariableCostate`](@ref).
"""
Traits.variable_costate_trait(::AbstractSystem) = Traits.NoVariableCostate

"""
$(TYPEDSIGNATURES)

Return the right-hand side function for the system.

The returned function must have the signature `(du, u, p, t) -> nothing` and
fill `du` in place with the derivative at state `u`, parameters `p`, and time `t`.

# Example

\`\`\`julia
using CTFlows.Systems

struct MySystem <: Systems.AbstractSystem{Traits.Autonomous, Traits.Fixed, Traits.StateDynamics}
    data::Vector{Float64}
end

# Implement rhs to return the ODE right-hand side function
function Systems.rhs(sys::MySystem)
    return (du, u, p, t) -> du .= sys.data .* u
end

# Usage
sys = MySystem([1.0, 2.0])
rhs_func = Systems.rhs(sys)
du = zeros(2)
rhs_func(du, [3.0, 4.0], [], 0.0)  # du becomes [3.0, 8.0]
\`\`\`

# Throws
- [`CTBase.Exceptions.NotImplemented`](@extref): If not implemented by the concrete type.

See also: [`CTFlows.Systems.AbstractSystem`](@ref).
"""
function rhs(system::AbstractSystem)
    throw(
        Exceptions.NotImplemented(
            "AbstractSystem rhs method not implemented";
            required_method = "rhs(system::$(typeof(system)))",
            suggestion = "Return a function (du, u, p, t) -> nothing that fills du in place.",
            context = "AbstractSystem.rhs - required method implementation",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Return the out-of-place right-hand side function for the system.

The returned function must have the signature `(u, p, t) -> du` and
return the derivative at state `u`, parameters `p`, and time `t` without modifying `u`.

This is used for immutable array types like `StaticArrays.SVector` where in-place
operations are not possible.

# Example

```julia
using CTFlows.Systems

struct MySystem <: Systems.AbstractSystem{Traits.Autonomous, Traits.Fixed, Traits.StateDynamics}
    data::Vector{Float64}
end

# Implement rhs_oop to return the ODE right-hand side function (out-of-place)
function Systems.rhs_oop(sys::MySystem)
    return (u, p, t) -> sys.data .* u
end

# Usage
sys = MySystem([1.0, 2.0])
rhs_oop_func = Systems.rhs_oop(sys)
u = [3.0, 4.0]
p = nothing
t = 0.0
du = rhs_oop_func(u, p, t)  # du = [3.0, 8.0]
```

# Throws
- [`CTBase.Exceptions.NotImplemented`](@extref): If not implemented by the concrete type.

# Notes
- This method is called when `ismutable(u0)` returns `false` for the initial condition.
- For mutable arrays like `Vector`, the in-place `rhs` method is used instead.

See also: [`CTFlows.Systems.rhs`](@ref), [`CTFlows.Systems.AbstractSystem`](@ref).
"""
function rhs_oop(system::AbstractSystem, ::Bool = true)
    throw(
        Exceptions.NotImplemented(
            "AbstractSystem rhs_oop method not implemented";
            required_method = "rhs_oop(sys::$(typeof(system)))",
            suggestion = "Implement rhs_oop for your system type to support immutable array initial conditions.",
            context = "AbstractSystem.rhs_oop - required method implementation",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Build the in-place right-hand side for a Hamiltonian system.

Contract stub — concrete Hamiltonian system types must implement this method.
`HamiltonianVectorFieldSystem` and `HamiltonianSystem` provide concrete implementations.

# Throws
- [`CTBase.Exceptions.NotImplemented`](@extref): If not implemented by the concrete type.

See also: [`CTFlows.Systems.HamiltonianSystem`](@ref), [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref).
"""
function build_rhs(system::AbstractHamiltonianSystem, args...)
    throw(
        Exceptions.NotImplemented(
            "AbstractHamiltonianSystem build_rhs method not implemented";
            required_method = "build_rhs(sys::$(typeof(system)), ...)",
            suggestion = "Use HamiltonianSystem (AD-backed) or HamiltonianVectorFieldSystem.",
            context = "AbstractHamiltonianSystem.build_rhs - required method implementation",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Build the out-of-place right-hand side for a Hamiltonian system.

Contract stub — concrete Hamiltonian system types must implement this method.

# Throws
- [`CTBase.Exceptions.NotImplemented`](@extref): If not implemented by the concrete type.

See also: [`CTFlows.Systems.HamiltonianSystem`](@ref), [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref).
"""
function build_oop_rhs(system::AbstractHamiltonianSystem, args...)
    throw(
        Exceptions.NotImplemented(
            "AbstractHamiltonianSystem build_oop_rhs method not implemented";
            required_method = "build_oop_rhs(sys::$(typeof(system)), ...)",
            suggestion = "Use HamiltonianSystem (AD-backed) or HamiltonianVectorFieldSystem.",
            context = "AbstractHamiltonianSystem.build_oop_rhs - required method implementation",
        ),
    )
end

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
