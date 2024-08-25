module CTFlowsODE

using CTBase
using CTFlows
using OrdinaryDiffEq
using DocStringExtensions
using MLStyle
#
import CTFlows: Flow, CTFlows
import Base: *
import CTBase: OptimalControlSolution, CTBase

# --------------------------------------------------------------------------------------------------
# Aliases
const CoTangent = ctVector
const DCoTangent = ctVector
const ctgradient = CTBase.__ctgradient

# types
abstract type AbstractFlow{D,U} end

# from CTFlows
const __create_hamiltonian = CTFlows.__create_hamiltonian

#
rg(i::Int, j::Int) = i == j ? i : i:j

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
