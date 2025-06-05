"""
$(TYPEDSIGNATURES)

Compute the derivative of a scalar function `f` at a scalar point `x`.

# Arguments
- `f::Function`: A scalar-valued function.
- `x::ctNumber`: A scalar input.

# Returns
- The derivative of `f` evaluated at `x`.

# Example
```julia-repl
julia> ctgradient(x -> x^2, 3.0)  # returns 6.0
```
"""
function ctgradient(f::Function, x::ctNumber)
    return ForwardDiff.derivative(x -> f(x), x)
end

"""
$(TYPEDSIGNATURES)

Compute the gradient of a scalar function `f` at a vector point `x`.

# Arguments
- `f::Function`: A scalar-valued function accepting a vector input.
- `x`: A vector of numbers.

# Returns
- A vector representing the gradient ∇f(x).

# Example
```julia-repl
julia> ctgradient(x -> sum(x.^2), [1.0, 2.0])  # returns [2.0, 4.0]
```
"""
function ctgradient(f::Function, x)
    return ForwardDiff.gradient(f, x)
end

"""
$(TYPEDSIGNATURES)

Compute the gradient of a `VectorField` at a given point.

# Arguments
- `X::VectorField`: A vector field object with a callable function `X.f`.
- `x`: A scalar or vector input.

# Returns
- The derivative or gradient depending on the type of `x`.

# Example
```julia-repl
julia> X = VectorField(x -> x^2)
julia> ctgradient(X, 2.0)  # returns 4.0
```
"""
ctgradient(X::VectorField, x) = ctgradient(X.f, x)

"""
$(TYPEDSIGNATURES)

Compute the Jacobian of a vector-valued function `f` at a scalar point `x`.

# Arguments
- `f::Function`: A vector-valued function.
- `x::ctNumber`: A scalar input.

# Returns
- A matrix representing the Jacobian Jf(x).

# Example
```julia-repl
julia> f(x) = [sin(x), cos(x)]
julia> ctjacobian(f, 0.0)  # returns a 2×1 matrix
```
"""
function ctjacobian(f::Function, x::ctNumber)
    return ForwardDiff.jacobian(x -> f(x[1]), [x])
end

"""
$(TYPEDSIGNATURES)

Compute the Jacobian of a vector-valued function `f` at a vector point `x`.

# Arguments
- `f::Function`: A vector-valued function.
- `x`: A vector input.

# Returns
- A matrix representing the Jacobian Jf(x).

# Example
```julia-repl
julia> f(x) = [x[1]^2, x[2]^2]
julia> ctjacobian(f, [1.0, 2.0])  # returns [2.0 0.0; 0.0 4.0]
```
"""
ctjacobian(f::Function, x) = ForwardDiff.jacobian(f, x)

"""
$(TYPEDSIGNATURES)

Compute the Jacobian of a `VectorField` at a given point.

# Arguments
- `X::VectorField`: A vector field object with a callable function `X.f`.
- `x`: A scalar or vector input.

# Returns
- A matrix representing the Jacobian of `X` at `x`.

# Example
```julia-repl
julia> X = VectorField(x -> [x[1]^2, x[2]])
julia> ctjacobian(X, [1.0, 3.0])  # returns [2.0 0.0; 0.0 1.0]
```
"""
ctjacobian(X::VectorField, x) = ctjacobian(X.f, x)
