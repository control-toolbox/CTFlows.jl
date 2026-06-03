"""
$(TYPEDSIGNATURES)

Compute the time derivative of a function.

Returns a function representing the partial derivative with respect to time.
The input function must accept time as its first argument.

# Arguments
- `f::Function`: Function that takes time as the first argument.
- `ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided}`: AD backend to use (default: global backend).

# Returns
- A function with signature `(t, args...) -> ∂f/∂t(t, args...)`.

# Example
```julia
using CTFlows.DifferentialGeometry

f = (t, x) -> t * x[1] + x[2]^2
df_dt = ∂ₜ(f)

df_dt(2.0, [1.0, 3.0])  # Returns 1.0
```

See also: [`CTFlows.DifferentialGeometry.∂ₜ`](@ref)
"""
function ∂ₜ(
    f::Function;
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
)
    backend = _resolve_backend(ad_backend)
    return (t, args...) -> Differentiation.derivative(backend, s -> f(s, args...), t)
end

"""
$(TYPEDSIGNATURES)

Compute the time derivative of a Hamiltonian vector field.

Returns a new [`Data.HamiltonianVectorField`](@ref) with `NonAutonomous` time dependence.
For autonomous vector fields, the derivative is zero.

# Arguments
- `X::Data.AbstractHamiltonianVectorField{TD, VD, MD}`: Hamiltonian vector field.
- `ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided}`: AD backend to use (default: global backend).

# Returns
- `Data.HamiltonianVectorField{Traits.NonAutonomous, VD, Traits.OutOfPlace}`: Time derivative.

# Throws
- `Exceptions.NotImplemented`: If the vector field has `InPlace` mutability.

# Example
```julia
using CTFlows.DifferentialGeometry
using CTFlows.Data
using CTFlows.Traits

X = HamiltonianVectorField((t, x, p) -> t * p, Traits.NonAutonomous, Traits.Fixed, Traits.OutOfPlace)
dX_dt = ∂ₜ(X)

dX_dt(2.0, [1.0], [0.5])  # Returns 0.5
```

See also: [`CTFlows.DifferentialGeometry.∂ₜ`](@ref)
"""
function ∂ₜ(
    X::Data.AbstractHamiltonianVectorField{TD, VD, MD};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD, VD, MD}
    _check_outofplace(MD)
    backend = _resolve_backend(ad_backend)
    closure = _∂ₜ_hvf(X, backend, TD, VD)
    return Data.HamiltonianVectorField(closure, Traits.NonAutonomous, VD, Traits.OutOfPlace)
end

# Autonomous HVF: call signature (x,p) ou (x,p,v) — s ignoré → dérivée = 0
"""
Internal time derivative implementation for HamiltonianVectorField (4 TD×VD variants).

# Arguments
- `X`: Hamiltonian vector field.
- `b::Differentiation.AbstractADBackend`: AD backend.
- `::Type{Traits.Autonomous}` or `::Type{Traits.NonAutonomous}`: Time dependence type.
- `::Type{Traits.Fixed}` or `::Type{Traits.NonFixed}`: Variable dependence type.

# Returns
- A closure with signature depending on TD/VD.
"""
_∂ₜ_hvf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous},    ::Type{Traits.Fixed})    = (t, x, p)    -> Differentiation.derivative(b, s -> X(x, p),    t)
_∂ₜ_hvf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous},    ::Type{Traits.NonFixed}) = (t, x, p, v) -> Differentiation.derivative(b, s -> X(x, p, v), t)
# NonAutonomous HVF: call signature (t,x,p) ou (t,x,p,v)
_∂ₜ_hvf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})    = (t, x, p)    -> Differentiation.derivative(b, s -> X(s, x, p),    t)
_∂ₜ_hvf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed}) = (t, x, p, v) -> Differentiation.derivative(b, s -> X(s, x, p, v), t)

"""
$(TYPEDSIGNATURES)

Compute the time derivative of a vector field.

Returns a new [`Data.VectorField`](@ref) with `NonAutonomous` time dependence.
For autonomous vector fields, the derivative is zero.

# Arguments
- `X::Data.AbstractVectorField{TD, VD, MD}`: Vector field.
- `ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided}`: AD backend to use (default: global backend).

# Returns
- `Data.VectorField{Traits.NonAutonomous, VD, Traits.OutOfPlace}`: Time derivative.

# Throws
- `Exceptions.NotImplemented`: If the vector field has `InPlace` mutability.

# Example
```julia
using CTFlows.DifferentialGeometry
using CTFlows.Data
using CTFlows.Traits

X = VectorField((t, x) -> t * x, Traits.NonAutonomous, Traits.Fixed, Traits.OutOfPlace)
dX_dt = ∂ₜ(X)

dX_dt(2.0, [1.0, 2.0])  # Returns [1.0, 2.0]
```

See also: [`CTFlows.DifferentialGeometry.∂ₜ`](@ref)
"""
function ∂ₜ(
    X::Data.AbstractVectorField{TD, VD, MD};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD, VD, MD}
    _check_outofplace(MD)
    backend = _resolve_backend(ad_backend)
    closure = _∂ₜ_vf(X, backend, TD, VD)
    return Data.VectorField(closure, Traits.NonAutonomous, VD, Traits.OutOfPlace)
end

# Autonomous VF: call signature (x) ou (x,v) — s ignoré → dérivée = 0
"""
Internal time derivative implementation for VectorField (4 TD×VD variants).

# Arguments
- `X`: Vector field.
- `b::Differentiation.AbstractADBackend`: AD backend.
- `::Type{Traits.Autonomous}` or `::Type{Traits.NonAutonomous}`: Time dependence type.
- `::Type{Traits.Fixed}` or `::Type{Traits.NonFixed}`: Variable dependence type.

# Returns
- A closure with signature depending on TD/VD.
"""
_∂ₜ_vf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous},    ::Type{Traits.Fixed})    = (t, x)    -> Differentiation.derivative(b, s -> X(x),    t)
_∂ₜ_vf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous},    ::Type{Traits.NonFixed}) = (t, x, v) -> Differentiation.derivative(b, s -> X(x, v), t)
# NonAutonomous VF
_∂ₜ_vf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})    = (t, x)    -> Differentiation.derivative(b, s -> X(s, x),    t)
_∂ₜ_vf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed}) = (t, x, v) -> Differentiation.derivative(b, s -> X(s, x, v), t)

"""
$(TYPEDSIGNATURES)

Compute the time derivative of a Hamiltonian.

Returns a new [`Data.Hamiltonian`](@ref) with `NonAutonomous` time dependence.
For autonomous Hamiltonians, the derivative is zero.

# Arguments
- `H::Data.AbstractHamiltonian{TD, VD}`: Hamiltonian.
- `ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided}`: AD backend to use (default: global backend).

# Returns
- `Data.Hamiltonian{Traits.NonAutonomous, VD}`: Time derivative.

# Example
```julia
using CTFlows.DifferentialGeometry
using CTFlows.Data
using CTFlows.Traits

H = Hamiltonian((t, x, p) -> t * p[1] + x[1]^2, Traits.NonAutonomous, Traits.Fixed)
dH_dt = ∂ₜ(H)

dH_dt(2.0, [1.0], [0.5])  # Returns 0.5
```

See also: [`CTFlows.DifferentialGeometry.∂ₜ`](@ref)
"""
function ∂ₜ(
    H::Data.AbstractHamiltonian{TD, VD};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD, VD}
    backend = _resolve_backend(ad_backend)
    closure = _∂ₜ_ham(H, backend, TD, VD)
    return Data.Hamiltonian(closure, Traits.NonAutonomous, VD)
end

# Autonomous Ham: call signature (x,p) ou (x,p,v) — dérivée = 0
"""
Internal time derivative implementation for Hamiltonian (4 TD×VD variants).

# Arguments
- `H`: Hamiltonian.
- `b::Differentiation.AbstractADBackend`: AD backend.
- `::Type{Traits.Autonomous}` or `::Type{Traits.NonAutonomous}`: Time dependence type.
- `::Type{Traits.Fixed}` or `::Type{Traits.NonFixed}`: Variable dependence type.

# Returns
- A closure with signature depending on TD/VD.
"""
_∂ₜ_ham(H, b::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous},    ::Type{Traits.Fixed})    = (t, x, p)    -> Differentiation.derivative(b, s -> H(x, p),    t)
_∂ₜ_ham(H, b::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous},    ::Type{Traits.NonFixed}) = (t, x, p, v) -> Differentiation.derivative(b, s -> H(x, p, v), t)
# NonAutonomous Ham
_∂ₜ_ham(H, b::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})    = (t, x, p)    -> Differentiation.derivative(b, s -> H(s, x, p),    t)
_∂ₜ_ham(H, b::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed}) = (t, x, p, v) -> Differentiation.derivative(b, s -> H(s, x, p, v), t)
