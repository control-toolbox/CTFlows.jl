# =============================================================================
# AbstractHamiltonianVectorField — Abstract type for Hamiltonian vector fields
# =============================================================================

"""
$(TYPEDEF)

Abstract supertype for Hamiltonian vector fields.

A Hamiltonian vector field represents the dynamics of a Hamiltonian system,
combining state and costate evolution according to Hamilton's equations.
It extends `AbstractVectorField` with the additional structure required
for Hamiltonian mechanics.

# Type Parameters
- `TD <: TimeDependence`: Time dependence trait (Autonomous or NonAutonomous)
- `VD <: VariableDependence`: Variable dependence trait (Fixed or NonFixed)
- `MD <: AbstractMutabilityTrait`: Mutability trait (InPlace or OutOfPlace)

# Interface Requirements

All subtypes must implement:
- Call signature: `(t, x, p)` or `(x, p)` depending on time dependence
- Returns the combined state-costate derivative vector

# Example
\`\`\`julia-repl
julia> using CTFlows.Data

julia> HamiltonianVectorField <: Data.AbstractHamiltonianVectorField
true
\`\`\`

See also: [`CTFlows.Data.AbstractVectorField`](@ref), [`CTFlows.Data.HamiltonianVectorField`](@ref), [`CTFlows.Data.Hamiltonian`](@ref).
"""
abstract type AbstractHamiltonianVectorField{
    TD <: Traits.TimeDependence,
    VD <: Traits.VariableDependence,
    MD <: Traits.AbstractMutabilityTrait
} <: AbstractVectorField{TD, VD, MD} end
