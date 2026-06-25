"""
    DifferentialGeometry

Differential geometry operations on vector fields and Hamiltonians: Lie derivatives,
Lie brackets, Poisson brackets, and time derivatives.

This module provides:
- `ad(X, Y)` — Lie bracket and Lie derivative
- `Lift(f)` — lift a function to a Hamiltonian
- `Poisson(H, G)` — Poisson bracket
- `∂ₜ(X)` — time derivative
- `@Lie` — macro for typed dispatch

All operations support automatic differentiation via a global backend (`dg_ad_backend`).
"""
module DifferentialGeometry

# ==============================================================================
# External-package imports (qualified, pollution-free)
# ==============================================================================

import ADTypes
import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Data
import CTBase.Differentiation
import CTBase.Exceptions
import CTBase.Traits
import MacroTools: postwalk, @capture

# ==============================================================================
# Internal sibling-submodule imports
# ==============================================================================

import ..Common: Common

# ==============================================================================
# Include files (in dependency order)
# ==============================================================================

include("default.jl")
include("ad.jl")
include("ad_types.jl")
include("lift.jl")
include("poisson.jl")
include("time_derivative.jl")
include("lie_macro.jl")

# ==============================================================================
# Public API — exports
# ==============================================================================

export ad
export Lift
export LiftedHamiltonianFunction
export Poisson
export ∂ₜ
export @Lie
export dg_ad_backend, dg_ad_backend!

end # module DifferentialGeometry
