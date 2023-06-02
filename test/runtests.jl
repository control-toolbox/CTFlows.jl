using CTFlows
using Test
using Plots
using CTBase
using OrdinaryDiffEq
using LinearAlgebra

@testset verbose = true showtiming = true "CTFlows" begin
    for name ∈ (
        :concatenation,
        #:default,
        #:flow_function,
        #:flow_hamiltonian_vector_field,
        #:flow_hamiltonian,
        #:flow_vector_field,
        #:optimal_control_problem
        )
        @testset "$(name)" begin
            test_name = Symbol(:test_, name)
            include("$(test_name).jl")
            @eval $test_name()
        end
    end
end