module CTFlows

#
import Base: *, isempty, Base
using CTBase
using DocStringExtensions
using OrdinaryDiffEq
using Plots: plot, Plots
using MLStyle

# les fonctions suivantes devraient être dans CTBase.jl
function is_variable(H::AbstractHamiltonian{TD, VD}) where {TD<:TimeDependence, VD<:VariableDependence}
    return VD==NonFixed
end

function is_variable(Hv::HamiltonianVectorField{TD, VD}) where {TD<:TimeDependence, VD<:VariableDependence}
    return VD==NonFixed
end

function is_variable(V::VectorField{TD, VD}) where {TD<:TimeDependence, VD<:VariableDependence}
    return VD==NonFixed
end

#####
# pourquoi pas juste redéfinir State avec les matrices et on refait un VectorField ici que 
# je mettrai dans CTBase plus tard.
####

# ceci devrait remplacer VectorField (à voir car je ne sais pas quoi mettre comme valeur par défaut 
# pour les types des variables x et v)
struct GeneralVectorField{TD<:TimeDependence, VD<:VariableDependence, XType, VType}
    f::Function
    function GeneralVectorField(f::Function; autonomous::Bool=true, variable::Bool=false, XType::Type=Any, VType::Type=Any)
        (TD, VD) = @match (!autonomous, variable) begin
            (true,  true ) => (NonAutonomous, NonFixed)
            (true,  false) => (NonAutonomous, Fixed)
            (false, true ) => (Autonomous,    NonFixed)
            (false, false) => (Autonomous,    Fixed)
        end
        new{TD, VD, XType, VType}(f)
    end
end
(F::GeneralVectorField)(args...; kwargs...) = F.f(args...; kwargs...)

function is_variable(G::GeneralVectorField{TD, VD, XT, VT}) where {TD<:TimeDependence, VD<:VariableDependence, XT, VT}
    return VD==NonFixed
end

# --------------------------------------------------------------------------------------------------
# Aliases for types
const CoTangent  = ctVector
const DCoTangent = ctVector

#
const ctgradient = CTBase.ctgradient

# --------------------------------------------------------------------------------------------------
rg(i::Integer, j::Integer) = i==j ? i : i:j

# --------------------------------------------------------------------------------------------
#
include("default.jl")
#
include("system.jl")
include("systems/hamiltonian.jl")
include("systems/vector_field.jl")
#
include("flow.jl")
include("flows/hamiltonian.jl")
include("flows/vector_field.jl")

# include("utils.jl")
# #
# include("vector_field.jl")
# include("function.jl")
# include("optimal_control_problem.jl")
# #
# include("concatenation.jl")

#
export VectorField
export Hamiltonian
export HamiltonianLift
export HamiltonianVectorField
export Flow
# export *
# export plot, plot!
# export isnonautonomous

end
