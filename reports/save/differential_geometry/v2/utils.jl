"""
$(TYPEDSIGNATURES)

Compute the derivative of a scalar function `f` at a scalar point `x`.

# Arguments
- `f::Function`: A scalar-valued function.
- `backend`: Automatic differentiation backend (default: `__backend()` = `AutoForwardDiff()`)
- `x::ctNumber`: A scalar input.

# Returns
- The derivative of `f` evaluated at `x`.

# Example
```julia-repl
julia> ctgradient(x -> x^2, 3.0)  # returns 6.0
```
"""
function ctgradient(f::Function, backend::AbstractADType, x::ctNumber)
    return derivative(f, backend, x)
end

"""
$(TYPEDSIGNATURES)

Compute the derivative of a scalar function `f` at a scalar point `x` using default backend.

# Arguments
- `f::Function`: A scalar-valued function.
- `x::ctNumber`: A scalar input.

# Returns
- The derivative of `f` evaluated at `x`.
"""
function ctgradient(f::Function, x::ctNumber)
    return ctgradient(f, __backend(), x)
end

"""
$(TYPEDSIGNATURES)

Compute the gradient of a scalar function `f` at a vector point `x`.

# Arguments
- `f::Function`: A scalar-valued function accepting a vector input.
- `backend`: Automatic differentiation backend (default: `__backend()` = `AutoForwardDiff()`)
- `x`: A vector of numbers.

# Returns
- A vector representing the gradient ∇f(x).

# Example
```julia-repl
julia> ctgradient(x -> sum(x.^2), [1.0, 2.0])  # returns [2.0, 4.0]
```
"""
function ctgradient(f::Function, backend::AbstractADType, x)
    return gradient(f, backend, x)
end

"""
$(TYPEDSIGNATURES)

Compute the gradient of a scalar function `f` at a vector point `x` using default backend.

# Arguments
- `f::Function`: A scalar-valued function accepting a vector input.
- `x`: A vector of numbers.

# Returns
- A vector representing the gradient ∇f(x).
"""
function ctgradient(f::Function, x)
    return ctgradient(f, __backend(), x)
end
