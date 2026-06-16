# =============================================================================
# Trait contracts for CTModels.Models.Model
#
# TEMPORARY — will move to CTModels once the contracts are stable.
#
# Implements has_time_dependence_trait / time_dependence and
# has_variable_dependence_trait / variable_dependence for CTModels.Models.Model,
# enabling Flow(ocp) to read TD/VD at the type level without boolean inspection.
# =============================================================================

import CTModels

# -----------------------------------------------------------------------------
# Time dependence
#
# CTModels.Model{TD, ...} carries TD ∈ {Components.Autonomous, Components.NonAutonomous}
# as a type parameter.  CTFlows.Traits.is_autonomous compares via:
#   time_dependence(obj) === Models.Autonomous
# so returning the TD type itself satisfies the contract.
# -----------------------------------------------------------------------------

Traits.has_time_dependence_trait(::CTModels.Models.Model) = true

Traits.time_dependence(::CTModels.Models.Model{TD}) where {TD} = TD

# -----------------------------------------------------------------------------
# Variable dependence
#
# Position 5 of CTModels.Model is VariableModelType.
# CTModels.Components.EmptyVariableModel ⟹ no optimisation variable ⟹ Traits.Fixed
# Any other VariableModelType                                        ⟹ Traits.NonFixed
#
# CTFlows.Traits.Fixed / NonFixed are types; the contract compares via ===, so
# return the type (not an instance).
# -----------------------------------------------------------------------------

Traits.has_variable_dependence_trait(::CTModels.Models.Model) = true

Traits.variable_dependence(ocp::CTModels.Models.Model) =
    CTModels.Models.is_nonvariable(ocp) ? Traits.Fixed : Traits.NonFixed
