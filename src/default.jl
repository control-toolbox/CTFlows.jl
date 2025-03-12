__autonomous()::Bool = true
__variable()::Bool = false
function __variable(ocp::CTModels.Model)::Bool
    return CTModels.variable_dimension(ocp) > 0
end