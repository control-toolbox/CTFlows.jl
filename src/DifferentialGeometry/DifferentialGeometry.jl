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

import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Exceptions
using ADTypes: ADTypes
import MacroTools: postwalk, @capture

# ==============================================================================
# Internal sibling-submodule imports
# ==============================================================================

import ..Traits: Traits
import ..Common: Common
import ..Data: Data
import ..Differentiation: Differentiation

# ==============================================================================
# Include files (in dependency order)
# ==============================================================================

include("default.jl")
include("prefix.jl")
include("exception_prefix.jl")
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
export Poisson
export ∂ₜ
export @Lie
export dg_ad_backend, dg_ad_backend!
export diffgeo_prefix, diffgeo_prefix!
export e_prefix, e_prefix!

end # module DifferentialGeometry
