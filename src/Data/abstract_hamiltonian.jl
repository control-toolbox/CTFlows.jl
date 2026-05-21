"""
$(TYPEDEF)

Abstract supertype for scalar Hamiltonian functions together with their
time-dependence and variable-dependence traits.

A Hamiltonian is a scalar function `H(t, x, p[, v]) → ℝ` from which a
Hamiltonian vector field can be derived via automatic differentiation.
Unlike vector fields, a Hamiltonian has no mutability trait (in-place vs
out-of-place) because a scalar return has no meaningful in-place form.

# Type Parameters
- `TD <: TimeDependence`: `Autonomous` or `NonAutonomous`.
- `VD <: VariableDependence`: `Fixed` or `NonFixed`.

# Notes
- All Hamiltonian types support both natural and uniform call signatures.
- The uniform signature `(t, x, p, v)` is used internally by systems.

See also: [`CTFlows.Data.Hamiltonian`](@ref), [`CTFlows.Common.TimeDependence`](@ref), [`CTFlows.Common.VariableDependence`](@ref).
"""
abstract type AbstractHamiltonian{
    TD <: Common.TimeDependence,
    VD <: Common.VariableDependence
} end

# =============================================================================
# Trait accessors for AbstractHamiltonian
# =============================================================================

"""
    Common.has_time_dependence_trait(::AbstractHamiltonian) -> true

Indicates that all `AbstractHamiltonian` types support time-dependence queries.

# Returns
- `true`: Always returns `true` for Hamiltonian types.

See also: [`CTFlows.Common.time_dependence`](@ref), [`CTFlows.Data.AbstractHamiltonian`](@ref).
"""
function Common.has_time_dependence_trait(::AbstractHamiltonian)
    return true
end

"""
    Common.has_variable_dependence_trait(::AbstractHamiltonian) -> true

Indicates that all `AbstractHamiltonian` types support variable-dependence queries.

# Returns
- `true`: Always returns `true` for Hamiltonian types.

See also: [`CTFlows.Common.variable_dependence`](@ref), [`CTFlows.Data.AbstractHamiltonian`](@ref).
"""
function Common.has_variable_dependence_trait(::AbstractHamiltonian)
    return true
end

"""
    Common.time_dependence(h::AbstractHamiltonian{TD, VD}) where {TD, VD} -> TD

Return the time-dependence trait of a Hamiltonian.

# Arguments
- `h::AbstractHamiltonian`: The Hamiltonian object.

# Returns
- `TD`: The time-dependence type (`Autonomous` or `NonAutonomous`).

See also: [`CTFlows.Common.VariableDependence`](@ref), [`CTFlows.Common.Autonomous`](@ref), [`CTFlows.Common.NonAutonomous`](@ref).
"""
function Common.time_dependence(::AbstractHamiltonian{TD, <:VariableDependence}) where {TD <: TimeDependence}
    return TD
end

"""
    Common.variable_dependence(h::AbstractHamiltonian{TD, VD}) where {TD, VD} -> VD

Return the variable-dependence trait of a Hamiltonian.

# Arguments
- `h::AbstractHamiltonian`: The Hamiltonian object.

# Returns
- `VD`: The variable-dependence type (`Fixed` or `NonFixed`).

See also: [`CTFlows.Common.TimeDependence`](@ref), [`CTFlows.Common.Fixed`](@ref), [`CTFlows.Common.NonFixed`](@ref).
"""
function Common.variable_dependence(::AbstractHamiltonian{<:TimeDependence, VD}) where {VD <: VariableDependence}
    return VD
end
