"""
    Traits

Trait types and trait-based dispatch for CTFlows.

This module provides the trait system used throughout CTFlows for compile-time
dispatch on:
- Time dependence: [`Autonomous`](@extref), [`NonAutonomous`](@extref)
- Variable dependence: [`Fixed`](@ref), [`NonFixed`](@ref)
- Integration mode: [`PointTrait`](@ref), [`TrajectoryTrait`](@ref)
- Content type: [`StateTrait`](@ref), [`HamiltonianTrait`](@ref), [`AugmentedHamiltonianTrait`](@ref)
- Mutability: [`InPlace`](@ref), [`OutOfPlace`](@ref)
- Automatic differentiation: [`WithAD`](@ref), [`WithoutAD`](@ref)
- Variable costate capability: [`SupportsVariableCostate`](@ref), [`NoVariableCostate`](@ref)

Traits are used as type parameters in configuration types, vector fields, and systems
to enable static dispatch without runtime type checks.

See also: [`CTFlows.Configs.AbstractConfig`](@ref), [`CTFlows.Data.AbstractVectorField`](@ref).
"""
module Traits

# ==============================================================================
# External package imports
# ==============================================================================

using Reexport
import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Exceptions
import CTModels.OCP

# ==============================================================================
# Includes
# ==============================================================================

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "abstract.jl"))
include(joinpath(@__DIR__, "mode.jl"))
include(joinpath(@__DIR__, "content.jl"))
include(joinpath(@__DIR__, "ad.jl"))
include(joinpath(@__DIR__, "variable_costate.jl"))
include(joinpath(@__DIR__, "mutability.jl"))
include(joinpath(@__DIR__, "time_dependence.jl"))
include(joinpath(@__DIR__, "variable_dependence.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

@reexport import CTModels.OCP: Autonomous, NonAutonomous, TimeDependence
@reexport import CTModels.OCP: is_autonomous, is_nonautonomous, is_variable, is_nonvariable, has_variable

export AbstractTrait
export AbstractModeTrait, AbstractContentTrait
export AbstractMutabilityTrait
export AbstractADTrait
export AbstractVariableCostateCapability
export PointTrait, TrajectoryTrait
export StateTrait, HamiltonianTrait, AugmentedHamiltonianTrait
export InPlace, OutOfPlace
export WithAD, WithoutAD
export SupportsVariableCostate, NoVariableCostate
export VariableDependence, Fixed, NonFixed
export ad_trait, variable_costate_trait
export is_inplace, is_outofplace
export has_time_dependence_trait, time_dependence, has_mutability_trait, mutability
export has_variable_dependence_trait, variable_dependence

end # module Traits
