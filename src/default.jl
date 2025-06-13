"""
Returns `true` by default, assuming the problem is autonomous.

This is the fallback for generic cases when no model is provided.
"""
__autonomous()::Bool = true

"""
Returns `true` for a model declared as `CTModels.Autonomous`.

Used to determine whether a model has time-independent dynamics.
"""
__autonomous(::CTModels.Model{CTModels.Autonomous})::Bool = true

"""
Returns `false` for a model declared as `CTModels.NonAutonomous`.

Used to identify models whose dynamics depend explicitly on time.
"""
__autonomous(::CTModels.Model{CTModels.NonAutonomous})::Bool = false

"""
Returns `false` by default, assuming no external variable is used.

Fallback for cases where no model is given.
"""
__variable()::Bool = false

"""
Returns `true` if the model has one or more external variables.

Used to check whether the problem is parameterized by an external vector `v`.
"""
function __variable(ocp::CTModels.Model)::Bool
    return CTModels.variable_dimension(ocp) > 0
end
