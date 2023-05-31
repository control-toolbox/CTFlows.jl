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

# --------------------------------------------------------------------------------------------------
rg(i::Integer, j::Integer) = i==j ? i : i:j

abstract type AbstractFlow{D, U, T} end

function AbstractFlow(::Type{TF}, f, rhs, tstops) where {TF <: AbstractFlow}
    return TF(f, rhs, tstops)
end

# --------------------------------------------------------------------------------------------
#
include("default.jl")
#
include("hamiltonian.jl")
include("vector_field.jl")
include("optimal_control_problem.jl")
#include("function.jl")
#
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
