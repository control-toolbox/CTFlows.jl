"""
$(TYPEDSIGNATURES)

Lift a function to a Hamiltonian via the canonical symplectic structure.

Returns a function representing the Hamiltonian `H(x, p) = p' * f(x)`. This is an
algebraic operation that does not use automatic differentiation.

# Arguments
- `f::Function`: Vector field function (returns a vector).
- `is_autonomous::Bool`: Whether the function is time-independent (default: from global config).
- `is_variable::Bool`: Whether the function depends on a variable parameter (default: from global config).

# Returns
- A function with signature depending on TD/VD:
  - Autonomous/Fixed: `(x, p) -> p' * f(x)`
  - NonAutonomous/Fixed: `(t, x, p) -> p' * f(t, x)`
  - Autonomous/NonFixed: `(x, p, v) -> p' * f(x, v)`
  - NonAutonomous/NonFixed: `(t, x, p, v) -> p' * f(t, x, v)`

# Example
```julia
using CTFlows.DifferentialGeometry

f = x -> [x[2], -x[1]]
H = Lift(f)

H([1.0, 2.0], [0.5, 1.0])  # Returns -1.5
```

See also: [`CTFlows.DifferentialGeometry.Lift`](@ref), [`CTFlows.DifferentialGeometry.Poisson`](@ref)
"""
function Lift(
    f::Function;
    is_autonomous::Bool = Common.__is_autonomous(),
    is_variable::Bool   = Common.__is_variable(),
)
    TD = is_autonomous ? Traits.Autonomous : Traits.NonAutonomous
    VD = is_variable   ? Traits.NonFixed   : Traits.Fixed
    return Lift(f, TD, VD)
end

"""
$(TYPEDSIGNATURES)

Lift a function to a Hamiltonian with explicit type parameters.

Returns a function representing the Hamiltonian `H(x, p) = p' * f(x)`. This typed entry
point is used by the [`@Lie`](@ref) macro for compile-time dispatch.

# Arguments
- `f::Function`: Vector field function (returns a vector).
- `::Type{TD}`: Time dependence type (`Autonomous` or `NonAutonomous`).
- `::Type{VD}`: Variable dependence type ([`CTFlows.Traits.Fixed`](@ref) or [`CTFlows.Traits.NonFixed`](@ref)).

# Returns
- A function with signature depending on TD/VD.

# Example
```julia
using CTFlows.DifferentialGeometry
using CTFlows.Traits

f = x -> [x[2], -x[1]]
H = Lift(f, Traits.Autonomous, Traits.Fixed)

H([1.0, 2.0], [0.5, 1.0])  # Returns -1.5
```

See also: [`CTFlows.DifferentialGeometry.Lift(f::Function)`](@ref), [`CTFlows.DifferentialGeometry.@Lie`](@ref)
"""
function Lift(f::Function, ::Type{TD}, ::Type{VD}) where {TD, VD}
    return _Lift(f, TD, VD)
end

# Internal: 4 closures — first arg typed Any so AbstractVectorField callables work
"""
Internal implementation of Lift for all TD×VD combinations.

Returns closures representing the Hamiltonian `H(x, p) = p' * f(x)`.

# Arguments
- `f`: Vector field function (typed Any to accept AbstractVectorField callables).
- `::Type{Traits.Autonomous}` or `::Type{Traits.NonAutonomous}`: Time dependence type.
- `::Type{Traits.Fixed}` or `::Type{Traits.NonFixed}`: Variable dependence type.

# Returns
- A closure with signature depending on TD/VD.
"""
_Lift(f, ::Type{Traits.Autonomous},    ::Type{Traits.Fixed})    = (x, p)       -> p' * f(x)
_Lift(f, ::Type{Traits.Autonomous},    ::Type{Traits.NonFixed}) = (x, p, v)    -> p' * f(x, v)
_Lift(f, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})    = (t, x, p)    -> p' * f(t, x)
_Lift(f, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed}) = (t, x, p, v) -> p' * f(t, x, v)

"""
$(TYPEDSIGNATURES)

Lift a vector field to a Hamiltonian via the canonical symplectic structure.

Returns a [`Data.Hamiltonian`](@ref) representing `H(x, p) = p' * X(x)`. This overload
allows lifting typed vector fields directly to Hamiltonians.

# Arguments
- `X::Data.AbstractVectorField{TD, VD}`: Vector field to lift.

# Returns
- `Data.Hamiltonian{TD, VD}`: The lifted Hamiltonian.

# Throws
- `Exceptions.NotImplemented`: If the vector field is an `AbstractHamiltonianVectorField`.

# Example
```julia
using CTFlows.DifferentialGeometry
using CTFlows.Data
using CTFlows.Traits

X = VectorField(x -> [x[2], -x[1]], Traits.Autonomous, Traits.Fixed, Traits.OutOfPlace)
H = Lift(X)

H([1.0, 2.0], [0.5, 1.0])  # Returns -1.5
```

See also: [`CTFlows.DifferentialGeometry.Lift(f::Function)`](@ref), [`CTFlows.DifferentialGeometry.Poisson`](@ref)
"""
function Lift(X::Data.AbstractVectorField{TD, VD}) where {TD, VD}
    _check_not_hvf(X)   # guard from ad_types.jl
    closure = _Lift(X, TD, VD)
    return Data.Hamiltonian(closure, TD, VD)   # typed constructor (no MD param)
end
