# ==============================================================================
# Differentiation — AD Backend Strategies for Hamiltonian Gradients
# ==============================================================================

"""
Module `CTFlows.Differentiation` provides automatic differentiation backend strategies
for computing gradients of scalar Hamiltonian functions.

## Architecture

The module defines an abstract contract `AbstractADBackend` with three methods:
- `hamiltonian_gradient(backend, h, t, x, p, v, cache)` → (∂H/∂x, ∂H/∂p)
- `variable_gradient(backend, h, t, x, p, v, cache)` → ∂H/∂v
- `prepare_cache(backend, h, typical_t, typical_x, typical_p, typical_v)` → AbstractCache

The concrete strategy `DifferentiationInterface` wraps DifferentiationInterface.jl backends
(e.g., `AutoForwardDiff()`) and stores them in its `:ad_backend` option.

## Dependencies

- `ADTypes.jl` (hard dependency) — provides `AutoForwardDiff` type
- `CTSolvers.Strategies` (from CTSolvers) — strategy contract
- `CTBase.Exceptions` — `NotImplemented` for stub methods
- `Common` (sibling) — `AbstractCache` type

## Extension

Gradient computation requires the `CTFlowsDifferentiationInterface` extension (Phase 5),
which implements the three contract methods using `DifferentiationInterface.gradient`
and `DifferentiationInterface.prepare_gradient`.

## Exports

- `AbstractADBackend`
- `DifferentiationInterface`
- `build_ad_backend`
- `hamiltonian_gradient`
- `variable_gradient`
- `prepare_cache`
"""
module Differentiation

# ==============================================================================
# External Imports
# ==============================================================================

import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Exceptions
using CTSolvers: CTSolvers
using ADTypes: ADTypes  # Hard dep — provides AutoForwardDiff

# ==============================================================================
# Internal Sibling Imports
# ==============================================================================

using ..Common

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
export hamiltonian_gradient
export variable_gradient
export prepare_cache

end # module
