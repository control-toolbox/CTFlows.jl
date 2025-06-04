__autonomous()::Bool = true
__autonomous(::CTModels.Model{CTModels.Autonomous})::Bool = true
__autonomous(::CTModels.Model{CTModels.NonAutonomous})::Bool = false
__variable()::Bool = false
function __variable(ocp::CTModels.Model)::Bool
    return CTModels.variable_dimension(ocp) > 0
end