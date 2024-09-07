using Aqua

using Test
using CTFlows
using OrdinaryDiffEq
using CTBase
using Plots
using LinearAlgebra

const CTFlowsODE = Base.get_extension(CTFlows, :CTFlowsODE) # to test functions from CTFlowsODE not in CTFlows

@testset verbose = true showtiming = true "CTFlows" begin
    for name in (
        :aqua,
        :concatenation,
        :default,
        :flow_function,
        :flow_hamiltonian_vector_field,
        :flow_hamiltonian,
        :flow_vector_field,
        :optimal_control_problem,
    )
        @testset "$(name)" begin
            test_name = Symbol(:test_, name)
            include("$(test_name).jl")
            @eval $test_name()
        end
    end
end
