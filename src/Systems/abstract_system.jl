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
struct MySystem <: Systems.AbstractSystem{Common.Autonomous, Common.Fixed}
    data::Vector{Float64}
end

# Implement required contract method
function Systems.rhs(sys::MySystem)
    return (du, u, p, t) -> du .= sys.data .* u
end
\`\`\`

See also: [`CTFlows.Systems.rhs`](@ref), [`CTFlows.Common.time_dependence`](@ref), [`CTFlows.Common.variable_dependence`](@ref).
"""
abstract type AbstractSystem{TD<:Common.TimeDependence, VD<:Common.VariableDependence} end

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

# Example
\`\`\`julia-repl
julia> using CTFlows.Systems

julia> MyHamiltonianSystem <: Systems.AbstractHamiltonianSystem
true
\`\`\`

See also: [`CTFlows.Systems.AbstractSystem`](@ref), [`CTFlows.Systems.AbstractStateSystem`](@ref).
"""
abstract type AbstractHamiltonianSystem{TD, VD} <: AbstractSystem{TD, VD} end

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

Extract the time dependence trait from an `AbstractSystem`.

# Returns
- `Type{<:TimeDependence}`: The time dependence trait type (Autonomous or NonAutonomous).

# Example
\`\`\`julia
using CTFlows.Systems
using CTFlows.Common

struct MySystem <: Systems.AbstractSystem{Common.Autonomous, Common.Fixed}
    data::Vector{Float64}
end

Common.time_dependence(MySystem)  # Returns Autonomous
\`\`\`

See also: [`CTFlows.Common.has_time_dependence_trait`](@ref), [`CTFlows.Common.is_autonomous`](@ref), [`CTFlows.Systems.AbstractSystem`](@ref).
"""
function Common.time_dependence(sys::AbstractSystem{TD, <:VariableDependence}) where {TD <: TimeDependence}
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

struct MySystem <: Systems.AbstractSystem{Common.Autonomous, Common.Fixed}
    data::Vector{Float64}
end

Common.variable_dependence(MySystem)  # Returns Fixed
\`\`\`

See also: [`CTFlows.Common.has_variable_dependence_trait`](@ref), [`CTFlows.Common.is_variable`](@ref), [`CTFlows.Systems.AbstractSystem`](@ref).
"""
function Common.variable_dependence(sys::AbstractSystem{<:TimeDependence, VD}) where {VD <: VariableDependence}
    return VD
end

"""
$(TYPEDSIGNATURES)

Return the right-hand side function for the system.

The returned function must have the signature `(du, u, p, t) -> nothing` and
fill `du` in place with the derivative at state `u`, parameters `p`, and time `t`.

# Example

\`\`\`julia
using CTFlows.Systems

struct MySystem <: Systems.AbstractSystem{Common.Autonomous, Common.Fixed}
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

struct MySystem <: Systems.AbstractSystem{Common.Autonomous, Common.Fixed}
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
