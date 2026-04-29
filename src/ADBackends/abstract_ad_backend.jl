"""
$(TYPEDEF)

Abstract strategy for automatic differentiation operations.

An `AbstractADBackend` is a strategy that provides gradient and Jacobian capabilities
used by flow modelers when assembling a system from an OCP (e.g., computing
∂H/∂p, ∂H/∂x).

This type inherits the full CTSolvers strategy contract:
- `id(::Type{<:S}) → Symbol`
- `metadata(::Type{<:S}) → StrategyMetadata`
- `options(s::S) → StrategyOptions`
- `Base.show` (tree + compact, automatic)
- `describe(::Type{<:S})`

# Contract

All subtypes must implement:
- `ctgradient(backend, f, x)`: Compute the gradient of `f` at `x`.
- `ctjacobian(backend, f, x)`: Compute the Jacobian of `f` at `x`.

# Throws
- `CTBase.Exceptions.NotImplemented`: If methods are not implemented by the concrete type.

See also: [`AbstractFlowModeler`](@ref).
"""
abstract type AbstractADBackend <: CTSolvers.Strategies.AbstractStrategy end

"""
$(TYPEDSIGNATURES)

Compute the gradient of function `f` at point `x` using the AD backend.

# Arguments
- `backend::AbstractADBackend`: The AD backend strategy.
- `f`: The function to differentiate.
- `x`: The point at which to compute the gradient.

# Returns
- The gradient vector.

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`AbstractADBackend`](@ref), [`ctjacobian`](@ref).
"""
function ctgradient(backend::AbstractADBackend, f, x)
    throw(Exceptions.NotImplemented(
        "AbstractADBackend ctgradient method not implemented";
        required_method = "ctgradient(backend::$(typeof(backend)), f, x)",
        suggestion = "Implement gradient computation using your AD backend.",
        context = "AbstractADBackend.ctgradient - required method implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Compute the Jacobian of function `f` at point `x` using the AD backend.

# Arguments
- `backend::AbstractADBackend`: The AD backend strategy.
- `f`: The function to differentiate.
- `x`: The point at which to compute the Jacobian.

# Returns
- The Jacobian matrix.

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`AbstractADBackend`](@ref), [`ctgradient`](@ref).
"""
function ctjacobian(backend::AbstractADBackend, f, x)
    throw(Exceptions.NotImplemented(
        "AbstractADBackend ctjacobian method not implemented";
        required_method = "ctjacobian(backend::$(typeof(backend)), f, x)",
        suggestion = "Implement Jacobian computation using your AD backend.",
        context = "AbstractADBackend.ctjacobian - required method implementation",
    ))
end
