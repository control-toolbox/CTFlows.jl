module CTFlows

    #
    using CTBase
    using DocStringExtensions
    using MLStyle

    # to be extended
    Flow(args...; kwargs...) = throw(ExtensionError(:OrdinaryDiffEq))

    #
    include("optimal_control_problem_utils.jl")

    #
    export VectorField
    export Hamiltonian
    export HamiltonianLift
    export HamiltonianVectorField
    export Flow

end
