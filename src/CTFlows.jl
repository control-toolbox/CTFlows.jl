module CTFlows

    #
    using CTBase
    using DocStringExtensions
    using MLStyle
    #
    import Base: *

    # to be placed in CTBase
    include("exceptions.jl")

    # --------------------------------------------------------------------------------------------------
    # Aliases for types
    const CoTangent  = ctVector
    const DCoTangent = ctVector

    # --------------------------------------------------------------------------------------------------
    rg(i::Integer, j::Integer) = i==j ? i : i:j
    abstract type AbstractFlow{D, U} end

    #
    include("types.jl")

    # to be extended
    Flow(args...; kwargs...) = throw(ExtensionError("Please make: julia> using DifferentialEquations"))
    default_algorithm = nothing
    function set_default_algorithm(alg)
        global default_algorithm = alg
        nothing
    end
    #CTFlows.plot(sol::OptimalControlFlowSolution, args...; kwargs...) = throw(ExtensionError("Please make: julia> using Plots"))
    #CTFlows.plot!(p, sol::OptimalControlFlowSolution, args...; kwargs...) = throw(ExtensionError("Please make: julia> using Plots"))

    #
    include("default.jl")
    include("concatenation.jl")
    include("optimal_control_problem_utils.jl")

    #
    export isnonautonomous
    export VectorField
    export Hamiltonian
    export HamiltonianLift
    export HamiltonianVectorField
    #export plot, plot!
    export Flow
    export *

end
