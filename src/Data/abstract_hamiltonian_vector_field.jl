# =============================================================================
# AbstractHamiltonianVectorField — Abstract type for Hamiltonian vector fields
# =============================================================================

# TODO: docstring
abstract type AbstractHamiltonianVectorField{
    TD <: Traits.TimeDependence,
    VD <: Traits.VariableDependence,
    MD <: Traits.AbstractMutabilityTrait
} <: AbstractVectorField{TD, VD, MD} end
