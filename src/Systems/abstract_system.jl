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
struct MySystem <: Systems.AbstractSystem{Traits.Autonomous, Traits.Fixed}
    data::Vector{Float64}
end

# Implement required contract method
function Systems.rhs(sys::MySystem)
    return (du, u, p, t) -> du .= sys.data .* u
end
\`\`\`

See also: [`CTFlows.Systems.rhs`](@ref), [`CTFlows.Traits.time_dependence`](@ref), [`CTFlows.Traits.variable_dependence`](@ref).
"""
abstract type AbstractSystem{TD<:Traits.TimeDependence, VD<:Traits.VariableDependence} end

"""
$(TYPEDEF)

Abstract type for state systems (non-Hamiltonian).

Subtype of `AbstractSystem` specialized for state dynamics without costates.
Carries the time-dependence and variable-dependence traits for compile-time dispatch.

# Type Parameters
- `TD <: TimeDependence`: Time dependence trait (Autonomous or NonAutonomous)
- `VD <: VariableDependence`: Variable dependence trait (Fixed or NonFixed)

# Example
\`\`\`julia-repl
julia> using CTFlows.Systems

julia> MyStateSystem <: Systems.AbstractStateSystem
true
\`\`\`

See also: [`CTFlows.Systems.AbstractSystem`](@ref), [`CTFlows.Systems.AbstractHamiltonianSystem`](@ref).
"""
abstract type AbstractStateSystem{TD, VD} <: AbstractSystem{TD, VD} end

"""
$(TYPEDEF)

Abstract type for Hamiltonian systems.

Subtype of `AbstractSystem` specialized for Hamiltonian dynamics with state and costate.
Carries the time-dependence and variable-dependence traits for compile-time dispatch.

# Type Parameters
- `TD <: TimeDependence`: Time dependence trait (Autonomous or NonAutonomous)
- `VD <: VariableDependence`: Variable dependence trait (Fixed or NonFixed)
- `AT <: AbstractADTrait`: AD capability trait (WithAD or WithoutAD)

# Example
\`\`\`julia-repl
julia> using CTFlows.Systems

julia> MyHamiltonianSystem <: Systems.AbstractHamiltonianSystem
true
\`\`\`

See also: [`CTFlows.Systems.AbstractSystem`](@ref), [`CTFlows.Systems.AbstractStateSystem`](@ref).
"""
abstract type AbstractHamiltonianSystem{TD, VD, AT<:Traits.AbstractADTrait} <: AbstractSystem{TD, VD} end

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

struct MySystem <: Systems.AbstractSystem{Traits.Autonomous, Traits.Fixed}
    data::Vector{Float64}
end

Traits.time_dependence(MySystem)  # Returns Autonomous
\`\`\`

See also: [`CTFlows.Traits.has_time_dependence_trait`](@ref), `is_autonomous`, [`CTFlows.Systems.AbstractSystem`](@ref).
"""
function Traits.time_dependence(sys::AbstractSystem{TD, <:Traits.VariableDependence}) where {TD <: Traits.TimeDependence}
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

struct MySystem <: Systems.AbstractSystem{Traits.Autonomous, Traits.Fixed}
    data::Vector{Float64}
end

Traits.variable_dependence(MySystem)  # Returns Fixed
\`\`\`

See also: [`CTFlows.Traits.has_variable_dependence_trait`](@ref), `is_variable`, [`CTFlows.Systems.AbstractSystem`](@ref).
"""
function Traits.variable_dependence(sys::AbstractSystem{<:Traits.TimeDependence, VD}) where {VD <: Traits.VariableDependence}
    return VD
end

"""
$(TYPEDSIGNATURES)

Return the automatic differentiation capability trait of a Hamiltonian system.

# Arguments
- `sys::AbstractHamiltonianSystem`: The Hamiltonian system.

# Returns
- `AT <: AbstractADTrait`: The AD capability trait, either [`CTFlows.Traits.WithAD`](@ref) or [`CTFlows.Traits.WithoutAD`](@ref).

# Notes
- [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref) always returns `WithoutAD` since it uses an explicitly provided vector field.
- [`CTFlows.Systems.HamiltonianSystem`](@ref) returns `WithAD` since it uses automatic differentiation to compute gradients from a scalar Hamiltonian function.
- This trait is used for dispatch in flow integration and cache preparation.

See also: [`CTFlows.Traits.AbstractADTrait`](@ref), [`CTFlows.Traits.WithAD`](@ref), [`CTFlows.Traits.WithoutAD`](@ref), [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref), [`CTFlows.Systems.HamiltonianSystem`](@ref).
"""
function Traits.ad_trait(::AbstractHamiltonianSystem{TD, VD, AT}) where {TD, VD, AT}
    return AT
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

struct MySystem <: Systems.AbstractSystem{Traits.Autonomous, Traits.Fixed}
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

struct MySystem <: Systems.AbstractSystem{Traits.Autonomous, Traits.Fixed}
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
