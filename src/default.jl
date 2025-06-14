"""
$(TYPEDSIGNATURES)

Return `true` by default, assuming the problem is autonomous.

This is the fallback for generic cases when no model is provided.
"""
__autonomous()::Bool = true

"""
$(TYPEDSIGNATURES)

Return `true` for a model declared as `CTModels.Autonomous`.

Used to determine whether a model has time-independent dynamics.
"""
__autonomous(::CTModels.Model{CTModels.Autonomous})::Bool = true

"""
$(TYPEDSIGNATURES)

Return `false` for a model declared as `CTModels.NonAutonomous`.

Used to identify models whose dynamics depend explicitly on time.
"""
__autonomous(::CTModels.Model{CTModels.NonAutonomous})::Bool = false

"""
$(TYPEDSIGNATURES)

Return `false` by default, assuming no external variable is used.

Fallback for cases where no model is given.
"""
__variable()::Bool = false

"""
$(TYPEDSIGNATURES)

Return `true` if the model has one or more external variables.

Used to check whether the problem is parameterized by an external vector `v`.
"""
function __variable(ocp::CTModels.Model)::Bool
    return CTModels.variable_dimension(ocp) > 0
end
