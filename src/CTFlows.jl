module CTFlows

#
import Base: *, isempty, Base
using CTBase
using DocStringExtensions
using OrdinaryDiffEq
using Plots: plot, Plots

#
Base.isempty(p::OrdinaryDiffEq.SciMLBase.NullParameters) = true

# --------------------------------------------------------------------------------------------------
# Aliases for types
const CoTangent = ctVector
const Control = ctVector
const DState = ctVector
const DCostate = ctVector
const DCoTangent = ctVector

#
const ctgradient = CTBase.ctgradient

# --------------------------------------------------------------------------------------------
#
include("default.jl")
include("solutions.jl")
include("flows.jl")
#
include("hamiltonian.jl")
include("hamiltonian_vector_field.jl")
include("vector_field.jl")
include("optimal_control_problem.jl")
#
include("plot.jl")
include("concatenation.jl")

#
export isnonautonomous
export VectorField
export Hamiltonian
export HamiltonianVectorField
export Flow
export plot
export *

end
