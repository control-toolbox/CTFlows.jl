# Public API — kwargs (plain Functions ; AbstractVectorField géré dans ad_types.jl)
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

# Public API — typed entry point
function ad(
    X::Function, foo::Function,
    ::Type{TD}, ::Type{VD};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD <: Traits.TimeDependence, VD <: Traits.VariableDependence}
    backend = _resolve_backend(ad_backend)
    return _ad(X, foo, backend, TD, VD)
end

# Internal — X/foo unannotés pour accepter AbstractVectorField callables (via ad_types.jl)
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
_ad_result(X̂::Function, f̂::Function, dfoo::Number, x, X_x, backend::Differentiation.AbstractADBackend) = dfoo

# Lie bracket (vector): J_Y(x)*X(x) - J_X(x)*Y(x)
function _ad_result(X̂::Function, f̂::Function, dfoo::AbstractVector, x, X_x, backend::Differentiation.AbstractADBackend)
    Y_x  = f̂(x)
    h(s) = X̂(x + s * Y_x)
    dX   = Differentiation.derivative(backend, h, 0.0)
    return dfoo - dX
end
