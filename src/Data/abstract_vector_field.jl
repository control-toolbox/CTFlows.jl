"""
$(TYPEDEF)

Abstract type for all vector fields in CTFlows.

An `AbstractVectorField` represents a vector field function with time-dependence
and variable-dependence traits encoded in the type parameters.

# Contract

All subtypes must have type parameters:
- `TD <: Common.TimeDependence`: `Autonomous` or `NonAutonomous`
- `VD <: Common.VariableDependence`: `Fixed` or `NonFixed`

Trait accessors are implemented at the abstract level and work for all subtypes.

# Example

\`\`\`julia
using CTFlows.Data
using CTFlows.Common

# Define a concrete vector field
struct MyVectorField{F, TD, VD} <: AbstractVectorField{TD, VD}
    f::F
end

# Trait accessors work automatically
vf = MyVectorField(x -> -x, Autonomous, Fixed)
Common.time_dependence(vf)  # Returns Autonomous
Common.variable_dependence(vf)  # Returns Fixed
\`\`\`

See also: [`CTFlows.Data.VectorField`](@ref), [`CTFlows.Data.HamiltonianVectorField`](@ref), [`CTFlows.Common.time_dependence`](@ref), [`CTFlows.Common.variable_dependence`](@ref).
"""
abstract type AbstractVectorField{TD<:Common.TimeDependence, VD<:Common.VariableDependence} end

# =============================================================================
# Trait accessors for AbstractVectorField
# =============================================================================

"""
$(TYPEDSIGNATURES)

Indicate that `AbstractVectorField` has the time-dependence trait.

This implementation declares that all vector fields support time-dependence queries.
Concrete `AbstractVectorField` instances have their time dependence encoded in the type parameter `TD`.

See also: [`CTFlows.Common.time_dependence`](@ref), [`CTFlows.Data.AbstractVectorField`](@ref).
"""
Common.has_time_dependence_trait(::AbstractVectorField) = true

"""
$(TYPEDSIGNATURES)

Indicate that `AbstractVectorField` has the variable-dependence trait.

This implementation declares that all vector fields support variable-dependence queries.
Concrete `AbstractVectorField` instances have their variable dependence encoded in the type parameter `VD`.

See also: [`CTFlows.Common.variable_dependence`](@ref), [`CTFlows.Data.AbstractVectorField`](@ref).
"""
Common.has_variable_dependence_trait(::AbstractVectorField) = true

"""
$(TYPEDSIGNATURES)

Extract the time dependence trait from an AbstractVectorField.

# Returns
- `Type{<:TimeDependence}`: The time dependence trait type (Autonomous or NonAutonomous).

# Example
\`\`\`julia
using CTFlows.Data
using CTFlows.Common

vf = Data.VectorField(x -> -x; is_autonomous=true)
Common.time_dependence(vf)  # Returns Autonomous

hvf = Data.HamiltonianVectorField((t, x, p) -> (x, -p); is_autonomous=false)
Common.time_dependence(hvf)  # Returns NonAutonomous
\`\`\`

See also: [`CTFlows.Common.has_time_dependence_trait`](@ref), [`CTFlows.Common.is_autonomous`](@ref).
"""
function Common.time_dependence(vf::AbstractVectorField{TD, <:VariableDependence}) where {TD <: TimeDependence}
    return TD
end

"""
$(TYPEDSIGNATURES)

Extract the variable dependence trait from an AbstractVectorField.

# Returns
- `Type{<:VariableDependence}`: The variable dependence trait type (Fixed or NonFixed).

# Example
\`\`\`julia
using CTFlows.Data
using CTFlows.Common

vf = Data.VectorField(x -> -x; is_variable=false)
Common.variable_dependence(vf)  # Returns Fixed

hvf = Data.HamiltonianVectorField((x, p, v) -> (x .* v, -p); is_variable=true)
Common.variable_dependence(hvf)  # Returns NonFixed
\`\`\`

See also: [`CTFlows.Common.has_variable_dependence_trait`](@ref), [`CTFlows.Common.is_variable`](@ref).
"""
function Common.variable_dependence(vf::AbstractVectorField{<:TimeDependence, VD}) where {VD <: VariableDependence}
    return VD
end
