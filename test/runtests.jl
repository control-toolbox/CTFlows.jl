using CTFlows
using Test
using Plots
using CTBase
using OrdinaryDiffEq
using LinearAlgebra

#
const AbstractSystem = CTFlows.AbstractSystem
const AbstractFlow = CTFlows.AbstractFlow
const System = CTFlows.System
const HamiltonianSystem = CTFlows.HamiltonianSystem
const HamiltonianFlow = CTFlows.HamiltonianFlow

#
struct DummySystem <: AbstractSystem{Any, Any} end

@testset verbose = true showtiming = true "CTFlows" begin
    for name ∈ (
        :default,
        #:abstract_system,
        :hamiltonian_system,
        :hamiltonian_flow,
        )
        @testset "$(name)" begin
            test_name = Symbol(:test_, name)
            include("$(test_name).jl")
            @eval $test_name()
        end
    end
end
