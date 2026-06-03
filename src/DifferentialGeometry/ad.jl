"""
$(TYPEDSIGNATURES)

Compute the Lie derivative or Lie bracket of two functions using keyword arguments.

- If `foo` returns a scalar, returns the Lie derivative (directional derivative): `∇foo(x)'*X(x)`
- If `foo` returns a vector, returns the Lie bracket: `J_foo(x)*X(x) - J_X(x)*foo(x)`

The time dependence and variable dependence are inferred from the `is_autonomous` and
`is_variable` keyword arguments.

# Arguments
- `X::Function`: Vector field function (returns a vector).
- `foo::Function`: Scalar or vector field function.
- `ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided}`: AD backend to use (default: global backend).
- `is_autonomous::Bool`: Whether the functions are time-independent (default: from global config).
- `is_variable::Bool`: Whether the functions depend on a variable parameter (default: from global config).

# Returns
- A function with signature depending on TD/VD:
  - Autonomous/Fixed: `(x) -> result`
  - NonAutonomous/Fixed: `(t, x) -> result`
  - Autonomous/NonFixed: `(x, v) -> result`
  - NonAutonomous/NonFixed: `(t, x, v) -> result`

# Example
```julia
using CTFlows.DifferentialGeometry

X = x -> [x[2], -x[1]]
f = x -> x[1]^2 + x[2]^2

# Lie derivative (scalar output)
L = ad(X, f)
L([1.0, 2.0])  # Returns 0.0
```

See also: [`CTFlows.DifferentialGeometry.ad`](@ref), [`CTFlows.DifferentialGeometry.Poisson`](@ref), [`CTFlows.DifferentialGeometry.Lift`](@ref)
"""
function ad(
    X::Function, foo::Function;
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
    is_autonomous::Bool = Common.__is_autonomous(),
    is_variable::Bool   = Common.__is_variable(),
)
    TD      = is_autonomous ? Traits.Autonomous : Traits.NonAutonomous
    VD      = is_variable   ? Traits.NonFixed : Traits.Fixed
    backend = _resolve_backend(ad_backend)
    return _ad(X, foo, backend, TD, VD)
end

"""
$(TYPEDSIGNATURES)

Compute the Lie derivative or Lie bracket of two functions with explicit type parameters.

- If `foo` returns a scalar, returns the Lie derivative (directional derivative): `∇foo(x)'*X(x)`
- If `foo` returns a vector, returns the Lie bracket: `J_foo(x)*X(x) - J_X(x)*foo(x)`

This typed entry point is used by the [`@Lie`](@ref) macro for compile-time dispatch.

# Arguments
- `X::Function`: Vector field function (returns a vector).
- `foo::Function`: Scalar or vector field function.
- `::Type{TD}`: Time dependence type (`Autonomous` or `NonAutonomous`).
- `::Type{VD}`: Variable dependence type ([`CTFlows.Traits.Fixed`](@ref) or [`CTFlows.Traits.NonFixed`](@ref)).
- `ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided}`: AD backend to use (default: global backend).

# Returns
- A function with signature depending on TD/VD:
  - Autonomous/Fixed: `(x) -> result`
  - NonAutonomous/Fixed: `(t, x) -> result`
  - Autonomous/NonFixed: `(x, v) -> result`
  - NonAutonomous/NonFixed: `(t, x, v) -> result`

# Example
```julia
using CTFlows.DifferentialGeometry
using CTFlows.Traits

X = x -> [x[2], -x[1]]
f = x -> x[1]^2 + x[2]^2

# Lie derivative with explicit types
L = ad(X, f, Traits.Autonomous, Traits.Fixed)
L([1.0, 2.0])  # Returns 0.0
```

See also: [`CTFlows.DifferentialGeometry.ad(X::Function, foo::Function)`](@ref), [`CTFlows.DifferentialGeometry.@Lie`](@ref), [`CTFlows.DifferentialGeometry.Poisson`](@ref)
"""
function ad(
    X::Function, foo::Function,
    ::Type{TD}, ::Type{VD};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD <: Traits.TimeDependence, VD <: Traits.VariableDependence}
    backend = _resolve_backend(ad_backend)
    return _ad(X, foo, backend, TD, VD)
end

# Internal — X/foo unannotés pour accepter AbstractVectorField callables (via ad_types.jl)
"""
Internal implementation of Lie derivative/bracket for Autonomous/Fixed case.

# Arguments
- `X`: Vector field (unannotated to accept AbstractVectorField callables).
- `foo`: Scalar or vector field function.
- `backend::Differentiation.AbstractADBackend`: AD backend.
- `::Type{Traits.Autonomous}`: Time dependence type.
- `::Type{Traits.Fixed}`: Variable dependence type.

# Returns
- A function `(x) -> result`.
"""
function _ad(X, foo, backend::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous}, ::Type{Traits.Fixed})
    return function (x)
        X_x  = X(x)
        X̂    = x_ -> X(x_)
        f̂    = x_ -> foo(x_)
        g(s) = f̂(x + s * X_x)
        dfoo = Differentiation.derivative(backend, g, 0.0)
        return _ad_result(X̂, f̂, dfoo, x, X_x, backend)
    end
end

"""
Internal implementation of Lie derivative/bracket for NonAutonomous/Fixed case.

# Arguments
- `X`: Vector field (unannotated to accept AbstractVectorField callables).
- `foo`: Scalar or vector field function.
- `backend::Differentiation.AbstractADBackend`: AD backend.
- `::Type{Traits.NonAutonomous}`: Time dependence type.
- `::Type{Traits.Fixed}`: Variable dependence type.

# Returns
- A function `(t, x) -> result`.
"""
function _ad(X, foo, backend::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})
    return function (t, x)
        X_x  = X(t, x)
        X̂    = x_ -> X(t, x_)
        f̂    = x_ -> foo(t, x_)
        g(s) = f̂(x + s * X_x)
        dfoo = Differentiation.derivative(backend, g, 0.0)
        return _ad_result(X̂, f̂, dfoo, x, X_x, backend)
    end
end

"""
Internal implementation of Lie derivative/bracket for Autonomous/NonFixed case.

# Arguments
- `X`: Vector field (unannotated to accept AbstractVectorField callables).
- `foo`: Scalar or vector field function.
- `backend::Differentiation.AbstractADBackend`: AD backend.
- `::Type{Traits.Autonomous}`: Time dependence type.
- `::Type{Traits.NonFixed}`: Variable dependence type.

# Returns
- A function `(x, v) -> result`.
"""
function _ad(X, foo, backend::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous}, ::Type{Traits.NonFixed})
    return function (x, v)
        X_x  = X(x, v)
        X̂    = x_ -> X(x_, v)
        f̂    = x_ -> foo(x_, v)
        g(s) = f̂(x + s * X_x)
        dfoo = Differentiation.derivative(backend, g, 0.0)
        return _ad_result(X̂, f̂, dfoo, x, X_x, backend)
    end
end

"""
Internal implementation of Lie derivative/bracket for NonAutonomous/NonFixed case.

# Arguments
- `X`: Vector field (unannotated to accept AbstractVectorField callables).
- `foo`: Scalar or vector field function.
- `backend::Differentiation.AbstractADBackend`: AD backend.
- `::Type{Traits.NonAutonomous}`: Time dependence type.
- `::Type{Traits.NonFixed}`: Variable dependence type.

# Returns
- A function `(t, x, v) -> result`.
"""
function _ad(X, foo, backend::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed})
    return function (t, x, v)
        X_x  = X(t, x, v)
        X̂    = x_ -> X(t, x_, v)
        f̂    = x_ -> foo(t, x_, v)
        g(s) = f̂(x + s * X_x)
        dfoo = Differentiation.derivative(backend, g, 0.0)
        return _ad_result(X̂, f̂, dfoo, x, X_x, backend)
    end
end

# Lie derivative (scalar): ∇f(x)'*X(x) — directional derivative déjà calculé
"""
Internal result handler for scalar Lie derivative.

# Arguments
- `X̂::Function`: Vector field closure.
- `f̂::Function`: Scalar function closure.
- `dfoo::Number`: Directional derivative result.
- `x`: State.
- `X_x`: Vector field evaluated at x.
- `backend::Differentiation.AbstractADBackend`: AD backend.

# Returns
- `Number`: The directional derivative.
"""
_ad_result(X̂::Function, f̂::Function, dfoo::Number, x, X_x, backend::Differentiation.AbstractADBackend) = dfoo

# Lie bracket (vector): J_Y(x)*X(x) - J_X(x)*Y(x)
"""
Internal result handler for vector Lie bracket.

Computes `J_foo(x)*X(x) - J_X(x)*foo(x)`.

# Arguments
- `X̂::Function`: Vector field closure.
- `f̂::Function`: Vector field closure.
- `dfoo::AbstractVector`: Directional derivative of foo along X.
- `x`: State.
- `X_x`: Vector field evaluated at x.
- `backend::Differentiation.AbstractADBackend`: AD backend.

# Returns
- `AbstractVector`: The Lie bracket.
"""
function _ad_result(X̂::Function, f̂::Function, dfoo::AbstractVector, x, X_x, backend::Differentiation.AbstractADBackend)
    Y_x  = f̂(x)
    h(s) = X̂(x + s * Y_x)
    dX   = Differentiation.derivative(backend, h, 0.0)
    return dfoo - dX
end
