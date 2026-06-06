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
$(TYPEDEF)

Callable struct representing the Lie derivative or Lie bracket of `foo` along `X`.

- **Scalar `foo`**: Lie derivative `∇foo(x)'·X(x)` — first JVP, no second pass.
- **Vector `foo`**: Lie bracket `J_foo(x)·X(x) - J_X(x)·foo(x)` — two JVPs via
  `Differentiation.pushforward`, eliminating the per-call inner closures
  (`X̂ = x_->X(x_)`, `f̂ = x_->foo(x_)`, `g(s) = f̂(x+s·X_x)`) that the old
  closure-based `_ad` created on every evaluation.

`TD` and `VD` are compile-time trait parameters so the correct call method (and slot
numbering) is resolved statically.
"""
struct Ad{TX, TF, B <: Differentiation.AbstractADBackend, TD, VD} <: Function
    X::TX
    foo::TF
    backend::B
end

# Autonomous/Fixed: X(x), foo(x) — active = x = slot 1, consts = ()
function (a::Ad{TX, TF, B, Traits.Autonomous, Traits.Fixed})(x) where {TX, TF, B}
    X_x  = a.X(x)
    dfoo = Differentiation.pushforward(a.backend, a.foo, Val(1), x, X_x)
    return _ad_bracket(a.X, a.foo, dfoo, a.backend, Val(1), x)
end

# NonAutonomous/Fixed: X(t,x), foo(t,x) — active = x = slot 2, consts = (t,)
function (a::Ad{TX, TF, B, Traits.NonAutonomous, Traits.Fixed})(t, x) where {TX, TF, B}
    X_x  = a.X(t, x)
    dfoo = Differentiation.pushforward(a.backend, a.foo, Val(2), x, X_x, t)
    return _ad_bracket(a.X, a.foo, dfoo, a.backend, Val(2), x, t)
end

# Autonomous/NonFixed: X(x,v), foo(x,v) — active = x = slot 1, consts = (v,)
function (a::Ad{TX, TF, B, Traits.Autonomous, Traits.NonFixed})(x, v) where {TX, TF, B}
    X_x  = a.X(x, v)
    dfoo = Differentiation.pushforward(a.backend, a.foo, Val(1), x, X_x, v)
    return _ad_bracket(a.X, a.foo, dfoo, a.backend, Val(1), x, v)
end

# NonAutonomous/NonFixed: X(t,x,v), foo(t,x,v) — active = x = slot 2, consts = (t, v)
function (a::Ad{TX, TF, B, Traits.NonAutonomous, Traits.NonFixed})(t, x, v) where {TX, TF, B}
    X_x  = a.X(t, x, v)
    dfoo = Differentiation.pushforward(a.backend, a.foo, Val(2), x, X_x, t, v)
    return _ad_bracket(a.X, a.foo, dfoo, a.backend, Val(2), x, t, v)
end

# Factory — single method replaces the four closure-returning _ad methods
function _ad(X, foo, backend::Differentiation.AbstractADBackend, ::Type{TD}, ::Type{VD}) where {TD, VD}
    return Ad{typeof(X), typeof(foo), typeof(backend), TD, VD}(X, foo, backend)
end

# Lie derivative (scalar): directional derivative already computed — nothing more to do
_ad_bracket(_, _, dfoo::Number, _, ::Val{Slot}, x, consts...) where {Slot} = dfoo

# Lie bracket (vector): J_foo(x)·X(x) - J_X(x)·foo(x)
# `WithActiveArg(foo, Val(Slot))(x, consts...)` reconstructs foo(...) at the current point
# without a closure; second `pushforward` computes J_X(x)·Y_x.
function _ad_bracket(X, foo, dfoo::AbstractVector, backend, ::Val{Slot}, x, consts...) where {Slot}
    Y_x = Differentiation.WithActiveArg(foo, Val(Slot))(x, consts...)
    dX  = Differentiation.pushforward(backend, X, Val(Slot), x, Y_x, consts...)
    return dfoo - dX
end
