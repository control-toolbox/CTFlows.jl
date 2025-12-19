module CTFlows

#
using CTBase
using CTModels
using DocStringExtensions
using MLStyle
using MacroTools: @capture, postwalk, striplines
using ForwardDiff: ForwardDiff
using DifferentiationInterface
using DifferentiationInterface: AutoForwardDiff, derivative, gradient

# to be extended
Flow(args...; kwargs...) = throw(CTBase.ExtensionError(:OrdinaryDiffEq))

#
include("default.jl")
include("types.jl")
include("utils.jl")
include("differential_geometry.jl")
include("optimal_control_problem_utils.jl")

end
