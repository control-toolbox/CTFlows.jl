"""
$(TYPEDEF)

Callable struct for `∂ₜ(f::Function)` — time derivative of a generic callable.

Replaces the outer closure `(t, args...) -> Differentiation.derivative(b, s -> f(s, args...), t)`.
"""
struct TimeDeriv_F{F, B <: Differentiation.AbstractADBackend} <: Function
    f::F
    b::B
end
(dtd::TimeDeriv_F)(t, args...) = Differentiation.differentiate(dtd.b, dtd.f, Val(1), t, args...)

"""
$(TYPEDSIGNATURES)

Compute the time derivative of a function.

Returns a [`TimeDeriv_F`](@ref) callable representing the partial derivative with respect to time.
The input function must accept time as its first argument.

# Arguments
- `f::Function`: Function that takes time as the first argument.
- `ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided}`: AD backend to use (default: global backend).

# Returns
- A [`TimeDeriv_F`](@ref) callable `(t, args...) -> ∂f/∂t(t, args...)`.

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
    return TimeDeriv_F{typeof(f), typeof(backend)}(f, backend)
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

"""
$(TYPEDEF)

Callable struct for `∂ₜ(X::AbstractHamiltonianVectorField)`.

- **Autonomous** (TD=Autonomous): `∂X/∂t = 0`; evaluates `X` once to get the zero shape.
- **NonAutonomous** (TD=NonAutonomous): differentiates `X` w.r.t. slot 1 (time) via
  `Differentiation.differentiate`, eliminating the inner `s -> X(s,...)` closure.
"""
# HVF returns a tuple (ẋ, ṗ); DI.derivative does not extract derivatives from tuple-of-array
# outputs, so we project onto each component before differentiating.
struct _HVFComp1{F} <: Function; X::F; end
struct _HVFComp2{F} <: Function; X::F; end
(_c::_HVFComp1)(args...) = _c.X(args...)[1]
(_c::_HVFComp2)(args...) = _c.X(args...)[2]

struct TimeDeriv_HVF{FX, B <: Differentiation.AbstractADBackend, TD, VD} <: Function
    X::FX
    b::B
end

(dtd::TimeDeriv_HVF{FX, B, Traits.Autonomous,    Traits.Fixed})(_, x, p)       where {FX, B} = zero.(dtd.X(x, p))
(dtd::TimeDeriv_HVF{FX, B, Traits.Autonomous,    Traits.NonFixed})(_, x, p, v) where {FX, B} = zero.(dtd.X(x, p, v))
(dtd::TimeDeriv_HVF{FX, B, Traits.NonAutonomous, Traits.Fixed})(t, x, p) where {FX, B} = (
    Differentiation.differentiate(dtd.b, _HVFComp1(dtd.X), Val(1), t, x, p),
    Differentiation.differentiate(dtd.b, _HVFComp2(dtd.X), Val(1), t, x, p),
)
(dtd::TimeDeriv_HVF{FX, B, Traits.NonAutonomous, Traits.NonFixed})(t, x, p, v) where {FX, B} = (
    Differentiation.differentiate(dtd.b, _HVFComp1(dtd.X), Val(1), t, x, p, v),
    Differentiation.differentiate(dtd.b, _HVFComp2(dtd.X), Val(1), t, x, p, v),
)

_∂ₜ_hvf(X, b::Differentiation.AbstractADBackend, ::Type{TD}, ::Type{VD}) where {TD, VD} =
    TimeDeriv_HVF{typeof(X), typeof(b), TD, VD}(X, b)

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

"""
$(TYPEDEF)

Callable struct for `∂ₜ(X::AbstractVectorField)`.

- **Autonomous**: `∂X/∂t = 0`; returns `zero.(X(...))` without AD.
- **NonAutonomous**: differentiates `X` w.r.t. slot 1 (time) via `Differentiation.differentiate`.
"""
struct TimeDeriv_VF{FX, B <: Differentiation.AbstractADBackend, TD, VD} <: Function
    X::FX
    b::B
end

(dtd::TimeDeriv_VF{FX, B, Traits.Autonomous,    Traits.Fixed})(_, x)    where {FX, B} = zero.(dtd.X(x))
(dtd::TimeDeriv_VF{FX, B, Traits.Autonomous,    Traits.NonFixed})(_, x, v) where {FX, B} = zero.(dtd.X(x, v))
(dtd::TimeDeriv_VF{FX, B, Traits.NonAutonomous, Traits.Fixed})(t, x)    where {FX, B} = Differentiation.differentiate(dtd.b, dtd.X, Val(1), t, x)
(dtd::TimeDeriv_VF{FX, B, Traits.NonAutonomous, Traits.NonFixed})(t, x, v) where {FX, B} = Differentiation.differentiate(dtd.b, dtd.X, Val(1), t, x, v)

_∂ₜ_vf(X, b::Differentiation.AbstractADBackend, ::Type{TD}, ::Type{VD}) where {TD, VD} =
    TimeDeriv_VF{typeof(X), typeof(b), TD, VD}(X, b)

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

"""
$(TYPEDEF)

Callable struct for `∂ₜ(H::AbstractHamiltonian)`.

- **Autonomous**: `∂H/∂t = 0`; returns `zero(H(...))` without AD.
- **NonAutonomous**: differentiates `H` w.r.t. slot 1 (time) via `Differentiation.differentiate`.
"""
struct TimeDeriv_Ham{FH, B <: Differentiation.AbstractADBackend, TD, VD} <: Function
    H::FH
    b::B
end

(dtd::TimeDeriv_Ham{FH, B, Traits.Autonomous,    Traits.Fixed})(_, x, p)    where {FH, B} = zero(dtd.H(x, p))
(dtd::TimeDeriv_Ham{FH, B, Traits.Autonomous,    Traits.NonFixed})(_, x, p, v) where {FH, B} = zero(dtd.H(x, p, v))
(dtd::TimeDeriv_Ham{FH, B, Traits.NonAutonomous, Traits.Fixed})(t, x, p)    where {FH, B} = Differentiation.differentiate(dtd.b, dtd.H, Val(1), t, x, p)
(dtd::TimeDeriv_Ham{FH, B, Traits.NonAutonomous, Traits.NonFixed})(t, x, p, v) where {FH, B} = Differentiation.differentiate(dtd.b, dtd.H, Val(1), t, x, p, v)

_∂ₜ_ham(H, b::Differentiation.AbstractADBackend, ::Type{TD}, ::Type{VD}) where {TD, VD} =
    TimeDeriv_Ham{typeof(H), typeof(b), TD, VD}(H, b)
