# ==============================================================================
# AbstractADBackend — AD Backend Strategy Contract
# ==============================================================================

"""
$(TYPEDEF)

Abstract base type for automatic differentiation backends in CTFlows.

An `AbstractADBackend` is a strategy that defines how to compute gradients of a
scalar Hamiltonian function. Concrete backends (e.g., `DifferentiationInterface`)
implement the contract methods to provide actual gradient computation.

# Notes
 - `AbstractADBackend` subtypes `CTSolvers.Strategies.AbstractStrategy` — they are
   first-class strategies in the CTSolvers ecosystem.
 - The contract consists of three methods: `hamiltonian_gradient`, `variable_gradient`,
   and `prepare_cache`. Concrete backends must implement all three.
 - Gradient methods return **non-negated** partial derivatives; the RHS closures
   apply the signs (ṗ = -∂H/∂x, ṽ = -∂H/∂v).

See also: [`CTFlows.Differentiation.DifferentiationInterface`](@ref),
[`CTFlows.Differentiation.hamiltonian_gradient`](@ref),
[`CTFlows.Differentiation.variable_gradient`](@ref),
[`CTFlows.Differentiation.prepare_cache`](@ref).
"""
abstract type AbstractADBackend <: CTSolvers.Strategies.AbstractStrategy end

# ==============================================================================
# Contract Methods
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Compute the Hamiltonian gradient (∂H/∂x, ∂H/∂p) using the backend.

# Arguments
- `backend::AbstractADBackend`: The AD backend.
- `h`: The Hamiltonian function or type.
- `t`: Time (scalar).
- `x`: State vector.
- `p`: Costate vector.
- `v`: Variable (scalar or `nothing` for Fixed problems).
- `cache`: Optional pre-allocated cache for efficient computation.

# Returns
- `(∂H_∂x, ∂H_∂p)`: Tuple of partial derivatives, **non-negated**. The RHS closure
  is responsible for applying the signs (ṗ = -∂H/∂x).

# Throws
- `CTBase.Exceptions.NotImplemented`: If the concrete backend does not implement
  this method.

# Notes
 - The cache defaults to `nothing` so calls without a prepared cache still work.
 - Concrete backends should fall back to plain gradient computation when cache is
   `nothing`, and use the prepared cache when available for efficiency.

See also: [`CTFlows.Differentiation.variable_gradient`](@ref),
[`CTFlows.Differentiation.prepare_cache`](@ref).
"""
function hamiltonian_gradient(backend::AbstractADBackend, h, t, x, p, v, cache)
    throw(Exceptions.NotImplemented(
        "hamiltonian_gradient not implemented for $(typeof(backend))",
        required_method = "hamiltonian_gradient(backend::$(typeof(backend)), h, t, x, p, v[, cache])",
        suggestion = "Implement hamiltonian_gradient for $(typeof(backend)) or load an extension that provides gradient computation (e.g., CTFlowsDifferentiationInterface)",
        context = "AD backend contract"
    ))
end

"""
$(TYPEDSIGNATURES)

Compute the variable gradient ∂H/∂v using the backend.

# Arguments
- `backend::AbstractADBackend`: The AD backend.
- `h`: The Hamiltonian function or type.
- `t`: Time (scalar).
- `x`: State vector.
- `p`: Costate vector.
- `v`: Variable (scalar or `nothing` for Fixed problems).
- `cache`: Optional pre-allocated cache for efficient computation.

# Returns
- `∂H_∂v`: Partial derivative with respect to the variable, **non-negated**. The RHS
  closure is responsible for applying the sign (ṽ = -∂H/∂v).

# Throws
- `CTBase.Exceptions.NotImplemented`: If the concrete backend does not implement
  this method.

# Notes
 - For Fixed problems (`v === nothing`), this method should return `nothing` or
   throw an error depending on the backend's contract.
 - The cache defaults to `nothing` so calls without a prepared cache still work.

See also: [`CTFlows.Differentiation.hamiltonian_gradient`](@ref),
[`CTFlows.Differentiation.prepare_cache`](@ref).
"""
function variable_gradient(backend::AbstractADBackend, h, t, x, p, v, cache)
    throw(Exceptions.NotImplemented(
        "variable_gradient not implemented for $(typeof(backend))",
        required_method = "variable_gradient(backend::$(typeof(backend)), h, t, x, p, v[, cache])",
        suggestion = "Implement variable_gradient for $(typeof(backend)) or load an extension that provides gradient computation (e.g., CTFlowsDifferentiationInterface)",
        context = "AD backend contract"
    ))
end

"""
$(TYPEDSIGNATURES)

Prepare a cache for efficient gradient computation using typical values.

# Arguments
- `backend::AbstractADBackend`: The AD backend.
- `h`: The Hamiltonian function or type.
- `typical_t`: Typical time value (used for cache pre-allocation).
- `typical_x`: Typical state vector (used for cache pre-allocation).
- `typical_p`: Typical costate vector (used for cache pre-allocation).
- `typical_v`: Typical variable value (scalar or `nothing` for Fixed problems).

# Returns
- `Common.AbstractCache`: A concrete cache subtype containing pre-allocated buffers
  and prepared differentiation plans.

# Throws
- `CTBase.Exceptions.NotImplemented`: If the concrete backend does not implement
  this method.

# Notes
 - The cache is passed to gradient methods via the `cache` argument.
 - Concrete cache types are extension-specific (e.g., `DifferentiationInterfaceCache`
   from the `CTFlowsDifferentiationInterface` extension).
 - The cache is stored in `ODEParameters` and accessed during ODE integration.

See also: [`CTFlows.Differentiation.hamiltonian_gradient`](@ref),
[`CTFlows.Differentiation.variable_gradient`](@ref),
[`CTFlows.Common.AbstractCache`](@ref),
[`CTFlows.Common.ODEParameters`](@ref).
"""
function prepare_cache(backend::AbstractADBackend, h, typical_t, typical_x, typical_p, typical_v)
    throw(Exceptions.NotImplemented(
        "prepare_cache not implemented for $(typeof(backend))",
        required_method = "prepare_cache(backend::$(typeof(backend)), h, typical_t, typical_x, typical_p, typical_v)",
        suggestion = "Implement prepare_cache for $(typeof(backend)) or load an extension that provides cache preparation (e.g., CTFlowsDifferentiationInterface)",
        context = "AD backend contract"
    ))
end

"""
$(TYPEDSIGNATURES)

Extract the AD backend from a backend strategy.

# Arguments
- `backend::AbstractADBackend`: The AD backend.

# Returns
- `ADTypes.AbstractADType`: The concrete AD backend (e.g., `AutoForwardDiff()`).

# Throws
- `CTBase.Exceptions.NotImplemented`: If the concrete backend does not implement
  this method.

# Notes
 - This method is used by the `hamiltonian_vector_field` getter to extract the
   AD backend from a `HamiltonianSystem`'s backend.
 - For `DifferentiationInterface`, this extracts the `:ad_backend` option.

See also: [`CTFlows.Differentiation.DifferentiationInterface`](@ref),
[`CTFlows.Systems.hamiltonian_vector_field`](@ref).
"""
function ad_backend(backend::AbstractADBackend)
    throw(Exceptions.NotImplemented(
        "ad_backend not implemented for $(typeof(backend))";
        required_method = "ad_backend(backend::$(typeof(backend)))",
        suggestion = "Implement ad_backend for $(typeof(backend))",
        context = "AD backend contract",
    ))
end

"""
$(TYPEDSIGNATURES)

Update a prepared cache when the input types or dimensions change.

# Arguments
- `cache::AbstractCache`: The cache to update (extension-specific type).
- `backend::AbstractADBackend`: The AD backend.
- `t`: Time (scalar).
- `x`: State vector.
- `p`: Costate vector.
- `v`: Variable (scalar or `nothing` for Fixed problems).

# Returns
- `nothing`

# Throws
- [`CTBase.Exceptions.NotImplemented`](@extref): If the concrete backend does not implement
  this method.

# Notes
 - This method is called when a `PreparationMismatchError` (from DifferentiationInterface.jl)
   occurs during gradient computation, indicating that the prepared cache no longer matches
   the current input types or dimensions.
 - Concrete backends with cache preparation (e.g., `DifferentiationInterface`)
   should re-prepare the cache with the new input characteristics.
 - Backends without cache preparation can provide a no-op implementation.

See also: [`CTFlows.Differentiation.prepare_cache`](@ref),
[`CTFlows.Differentiation.hamiltonian_gradient`](@ref),
[`CTFlows.Differentiation.variable_gradient`](@ref).
"""
function update!(cache, backend::AbstractADBackend, t, x, p, v)
    throw(Exceptions.NotImplemented(
        "update! not implemented for $(typeof(backend))",
        required_method = "update!(cache, backend::$(typeof(backend)), t, x, p, v)",
        suggestion = "Implement update! for $(typeof(backend)) or provide a no-op if cache preparation is not used",
        context = "AD backend contract",
    ))
end
