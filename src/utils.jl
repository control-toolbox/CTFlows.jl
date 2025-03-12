function ctgradient(f::Function, x::ctNumber)
    return ForwardDiff.derivative(x -> f(x), x)
end

function ctgradient(f::Function, x)
    return ForwardDiff.gradient(f, x)
end

ctgradient(X::VectorField, x) = ctgradient(X.f, x)

function ctjacobian(f::Function, x::ctNumber)
    return ForwardDiff.jacobian(x -> f(x[1]), [x])
end

ctjacobian(f::Function, x) = ForwardDiff.jacobian(f, x)

ctjacobian(X::VectorField, x) = ctjacobian(X.f, x)