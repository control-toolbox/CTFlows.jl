# ==============================================================================
# Differentiation — AD Backend Strategies for Hamiltonian Gradients
# ==============================================================================

"""
Module `CTFlows.Differentiation` provides automatic differentiation backend strategies
for computing gradients of scalar Hamiltonian functions.

## Architecture

The module defines an abstract contract `AbstractADBackend` with seven methods:
- `hamiltonian_gradient(backend, h, t, x, p, v)` → (∂H/∂x, ∂H/∂p)
- `variable_gradient(backend, h, t, x, p, v)` → ∂H/∂v
- `gradient(backend, f, x)` → ∇f (extension contract)
- `derivative(backend, g, t)` → dg/dt (extension contract)
- `differentiate(backend, f, ::Val{Slot}, active, consts...)` → partial derivative at slot
- `pushforward(backend, f, ::Val{Slot}, x, dx, consts...)` → JVP along direction dx

The concrete strategy `DifferentiationInterface` wraps DifferentiationInterface.jl backends
(e.g., `AutoForwardDiff()`) and stores them in its `:ad_backend` option.

## Dependencies

- `ADTypes.jl` (hard dependency) — provides `AutoForwardDiff` type
- `CTBase.Strategies` — strategy contract
- `CTBase.Exceptions` — `NotImplemented` for stub methods
- `Common` (sibling) — `AbstractCache` type

## Extension

Gradient computation requires the `CTFlowsDifferentiationInterface` extension (Phase 5),
which implements the contract methods using `DifferentiationInterface.gradient`
and `DifferentiationInterface.prepare_gradient`.

## Exports

- `AbstractADBackend`
- `DifferentiationInterface`
- `build_ad_backend`
- `hamiltonian_gradient`
- `variable_gradient`
- `gradient`
- `derivative`
- `differentiate`
- `pushforward`
"""
module Differentiation

# ==============================================================================
# External Imports
# ==============================================================================

import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Exceptions
import CTBase.Strategies
using ADTypes: ADTypes  # Hard dep — provides AutoForwardDiff

# ==============================================================================
# Internal Sibling Imports
# ==============================================================================

import ..Common: Common
import ..Data: Data

# ==============================================================================
# Includes (in dependency order)
# ==============================================================================

include("abstract_ad_backend.jl")
include("differentiation_interface.jl")
include("building.jl")

# ==============================================================================
# Exports
# ==============================================================================

export AbstractADBackend
export DifferentiationInterface
export build_ad_backend
export ad_backend
export hamiltonian_gradient
export variable_gradient
export gradient
export derivative
export differentiate
export pushforward

end # module
