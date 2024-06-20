using CTFlows
using Test
using Plots
using CTBase
using OrdinaryDiffEq
using LinearAlgebra

#
const GeneralVectorField = CTFlows.GeneralVectorField
#
const System = CTFlows.System
const AbstractSystem = CTFlows.AbstractSystem
const AbstractHamiltonianSystem = CTFlows.AbstractHamiltonianSystem
const HamiltonianSystem = CTFlows.HamiltonianSystem
const HamiltonianVectorFieldSystem = CTFlows.HamiltonianVectorFieldSystem
const VectorFieldSystem = CTFlows.VectorFieldSystem
const GeneralVectorFieldSystem = CTFlows.GeneralVectorFieldSystem
#
const AbstractFlow = CTFlows.AbstractFlow
const HamiltonianFlow = CTFlows.HamiltonianFlow
const VectorFieldFlow = CTFlows.VectorFieldFlow


#
struct DummySystem <: AbstractSystem{Any, Any} end

@testset verbose = true showtiming = true "CTFlows" begin
    for name ∈ (
        :default,
        #:abstract_system,
        :hamiltonian_system,
        :hamiltonian_flow,
        :vector_field_system,
        :vector_field_flow,
        )
        @testset "$(name)" begin
            test_name = Symbol(:test_, name)
            include("$(test_name).jl")
            @eval $test_name()
        end
    end
end
