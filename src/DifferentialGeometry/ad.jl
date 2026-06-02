# Public API — kwargs entry point
function ad(
    X, foo;
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
    is_autonomous::Bool = Common.__is_autonomous(),
    is_variable::Bool   = Common.__is_variable(),
)
    TD      = is_autonomous ? Traits.Autonomous    : Traits.NonAutonomous
    VD      = is_variable   ? Traits.NonFixed       : Traits.Fixed
    backend = _resolve_backend(ad_backend)
    return _ad(X, foo, backend, TD, VD)
end

# Public API — typed entry point
function ad(
    X, foo,
    ::Type{TD}, ::Type{VD};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD <: Traits.TimeDependence, VD <: Traits.VariableDependence}
    backend = _resolve_backend(ad_backend)
    return _ad(X, foo, backend, TD, VD)
end

# Internal — 4 variants for (TD, VD) combinations
function _ad(X, foo, backend, ::Type{Traits.Autonomous}, ::Type{Traits.Fixed})
    return function (x)
        X_x  = X(x)
        g(t) = foo(x + t * X_x)
        dfoo = Differentiation.derivative(backend, g, 0.0)
        return _ad_result(X, foo, dfoo, x, X_x, backend)
    end
end

function _ad(X, foo, backend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})
    return function (t, x)
        X_x  = X(t, x)
        g(s) = foo(t, x + s * X_x)
        dfoo = Differentiation.derivative(backend, g, 0.0)
        return _ad_result(X, foo, dfoo, x, X_x, backend, t)
    end
end

function _ad(X, foo, backend, ::Type{Traits.Autonomous}, ::Type{Traits.NonFixed})
    return function (x, v)
        X_x  = X(x, v)
        g(t) = foo(x + t * X_x, v)
        dfoo = Differentiation.derivative(backend, g, 0.0)
        return _ad_result(X, foo, dfoo, x, X_x, backend, v)
    end
end

function _ad(X, foo, backend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed})
    return function (t, x, v)
        X_x  = X(t, x, v)
        g(s) = foo(t, x + s * X_x, v)
        dfoo = Differentiation.derivative(backend, g, 0.0)
        return _ad_result(X, foo, dfoo, x, X_x, backend, t, v)
    end
end

# Lie derivative (scalar output): just return the directional derivative
_ad_result(X, foo, dfoo::Number, x, X_x, backend, args...) = dfoo # Already ∇f(x)' * X(x)

# Lie bracket (vector output): subtract J_X * Y
function _ad_result(X, foo, dfoo::AbstractVector, x, X_x, backend, args...)
    # dfoo = J_Y(x) * X(x)
    # Compute J_X(x) * Y(x) using directional derivative
    Y_x  = foo(x, args...)
    h(t) = X(x + t * Y_x, args...)
    dX   = Differentiation.derivative(backend, h, 0.0)
    return dfoo - dX # J_Y(x)*X(x) - J_X(x)*Y(x)
end
