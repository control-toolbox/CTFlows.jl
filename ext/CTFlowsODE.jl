module CTFlowsODE

using CTBase
using CTFlows
using CTModels
using OrdinaryDiffEq
using DocStringExtensions
using MLStyle
#
import CTFlows: Flow, CTFlows
import Base: *
import CTModels: Solution, CTModels

# --------------------------------------------------------------------------------------------------
# Aliases
const CoTangent  = CTFlows.ctVector
const DCoTangent = CTFlows.ctVector
const ctgradient = CTFlows.ctgradient

# types
abstract type AbstractFlow{D,U} end

# from CTFlows
const __create_hamiltonian = CTFlows.__create_hamiltonian

#
rg(i::Int, j::Int) = i == j ? i : i:j

#
const __autonomous = CTFlows.__autonomous
const __variable = CTFlows.__variable

# --------------------------------------------------------------------------------------------#
include("default.jl")
include("types.jl")
include("utils.jl")
#
include("vector_field.jl")
include("hamiltonian.jl")
include("optimal_control_problem.jl")
include("function.jl")
include("concatenation.jl")

end
