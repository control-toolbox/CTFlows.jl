module CTFlows

# Packages needed: 
using OrdinaryDiffEq
import Base: *, isempty, Base

#
using CTBase

#
Base.isempty(p::OrdinaryDiffEq.SciMLBase.NullParameters) = true

# --------------------------------------------------------------------------------------------------
# Aliases for types
#
# const AbstractVector{T} = AbstractArray{T,1}.
const CoTangent = MyVector
const Control = MyVector
const DState = MyVector
const DAdjoint = MyVector
const DCoTangent = MyVector

# const StaticVector{N, T} = StaticArray{Tuple{N}, T, 1}
#isstatic(v::MyVector) = v isa StaticVector{E, <:MyNumber} where {E}

#
const ctgradient = CTBase.ctgradient

#
struct CTFlow{D, U, T}
    f::Function     # f(args..., rhs)
    rhs!::Function   # OrdinaryDiffEq rhs
    tstops::Times
    CTFlow{D, U, T}(f, rhs!) where {D, U, T} = new{D, U, T}(f, rhs!, Vector{Time}())
    CTFlow{D, U, T}(f, rhs!, tstops) where {D, U, T} = new{D, U, T}(f, rhs!, tstops)
end
(F::CTFlow)(args...; kwargs...) = F.f(args...; _t_stops_interne=F.tstops, DiffEqRHS=F.rhs!, kwargs...)

# --------------------------------------------------------------------------------------------
# Default options for flows
# --------------------------------------------------------------------------------------------
__abstol() = 1e-10
__reltol() = 1e-10
__saveat() = []
__alg() = Tsit5()
__tstops() = Vector{Time}()

# --------------------------------------------------------------------------------------------
# all flows
include("flow_constructors.jl")
include("flow_hamiltonian.jl")
include("flow_function.jl")
include("flow_vf_hamiltonian.jl")
include("flow_vf.jl")
include("concatenation.jl")

#todo: ajout du temps, de paramètres...
# ces fichiers sont stockés ailleurs
#include("flows/flow_lagrange_system.jl")
#include("flows/flow_mayer_system.jl")
#include("flows/flow_pseudo_ham.jl")
#include("flows/flow_si_mayer.jl")

export isnonautonomous
export VectorField
export Hamiltonian
export HamiltonianVectorField
export Flow
export *

end
