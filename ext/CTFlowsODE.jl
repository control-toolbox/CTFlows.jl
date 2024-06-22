module CTFlowsODE

    using CTBase
    using CTFlows
    using OrdinaryDiffEq
    using DocStringExtensions
    using MLStyle
    #
    import CTFlows: Flow
    
    # --------------------------------------------------------------------------------------------------
    # Aliases
    const CoTangent  = ctVector
    const DCoTangent = ctVector
    const ctgradient = CTBase.ctgradient
    
    # from CTFlows
    const __variable           = CTFlows.__variable
    const __abstol             = CTFlows.__abstol
    const __reltol             = CTFlows.__reltol
    const __saveat             = CTFlows.__saveat
    const __alg                = CTFlows.__alg
    const __tstops             = CTFlows.__tstops
    const __callback           = CTFlows.__callback
    const __create_hamiltonian = CTFlows.__create_hamiltonian
    const HamiltonianFlow      = CTFlows.HamiltonianFlow
    const VectorFieldFlow      = CTFlows.VectorFieldFlow
    const ODEFlow              = CTFlows.ODEFlow
    const OptimalControlFlow   = CTFlows.OptimalControlFlow
    const rg                   = CTFlows.rg

    # default
    CTFlows.set_default_algorithm(Tsit5())

    # --------------------------------------------------------------------------------------------
    include("utils.jl")
    #
    include("vector_field.jl")
    include("hamiltonian.jl")
    include("optimal_control_problem.jl")
    include("function.jl")

end