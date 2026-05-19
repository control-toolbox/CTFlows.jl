"""
Unit and error tests for the AD backend contract and DifferentiationInterface strategy.
"""

module TestADBackend

import Test
import CTFlows.Differentiation
import CTBase.Exceptions
import CTSolvers
import ADTypes

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake AD Backend for Testing (at module top-level)
# ==============================================================================

struct FakeADBackend <: Differentiation.AbstractADBackend
    options::CTSolvers.Strategies.StrategyOptions
end

FakeADBackend() = FakeADBackend(CTSolvers.Strategies.StrategyOptions())

function test_ad_backend()
    Test.@testset "AD Backend Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ==============================================================================
        # Unit Tests
        # ==============================================================================

        Test.@testset "Unit: AbstractADBackend abstract type" begin
            backend = FakeADBackend()
            Test.@test backend isa Differentiation.AbstractADBackend
            Test.@test backend isa CTSolvers.Strategies.AbstractStrategy
        end

        Test.@testset "Unit: DifferentiationInterface construction" begin
            # Default construction
            di = Differentiation.DifferentiationInterface()
            Test.@test di isa Differentiation.DifferentiationInterface
            Test.@test di isa Differentiation.AbstractADBackend

            # Default backend is AutoForwardDiff
            metadata = CTSolvers.Strategies.metadata(Differentiation.DifferentiationInterface)
            Test.@test metadata[:ad_backend].default === ADTypes.AutoForwardDiff()

            # Custom backend
            di_custom = Differentiation.DifferentiationInterface(backend=ADTypes.AutoZygote())
            Test.@test di_custom isa Differentiation.DifferentiationInterface
        end

        Test.@testset "Unit: CTSolvers.Strategies contract" begin
            # id
            Test.@test CTSolvers.Strategies.id(Differentiation.DifferentiationInterface) ===
                  :differentiation_interface

            # description
            desc = CTSolvers.Strategies.description(Differentiation.DifferentiationInterface)
            Test.@test desc isa String
            Test.@test !isempty(desc)

            # metadata
            metadata = CTSolvers.Strategies.metadata(Differentiation.DifferentiationInterface)
            Test.@test metadata isa CTSolvers.Strategies.StrategyMetadata
            Test.@test length(metadata) > 0
            Test.@test :ad_backend in keys(metadata)
        end

        Test.@testset "Unit: build_ad_backend" begin
            backend = Differentiation.build_ad_backend()
            Test.@test backend isa Differentiation.DifferentiationInterface
        end

        # ==============================================================================
        # Error Tests
        # ==============================================================================

        Test.@testset "Error: hamiltonian_gradient stub throws NotImplemented" begin
            backend = FakeADBackend()
            h = nothing  # Dummy Hamiltonian
            t = 0.0
            x = [1.0, 2.0]
            p = [3.0, 4.0]
            v = 5.0

            try
                Differentiation.hamiltonian_gradient(backend, h, t, x, p, v)
                Test.@test false  # Should not reach here
            catch err
                Test.@test err isa Exceptions.NotImplemented
                Test.@test occursin("hamiltonian_gradient", err.required_method)
            end
        end

        Test.@testset "Error: variable_gradient stub throws NotImplemented" begin
            backend = FakeADBackend()
            h = nothing
            t = 0.0
            x = [1.0, 2.0]
            p = [3.0, 4.0]
            v = 5.0

            try
                Differentiation.variable_gradient(backend, h, t, x, p, v)
                Test.@test false  # Should not reach here
            catch err
                Test.@test err isa Exceptions.NotImplemented
                Test.@test occursin("variable_gradient", err.required_method)
            end
        end

        Test.@testset "Error: prepare_cache stub throws NotImplemented" begin
            backend = FakeADBackend()
            h = nothing
            typical_x = [1.0, 2.0]
            typical_p = [3.0, 4.0]
            typical_v = 5.0

            try
                Differentiation.prepare_cache(backend, h, typical_x, typical_p, typical_v)
                Test.@test false  # Should not reach here
            catch err
                Test.@test err isa Exceptions.NotImplemented
                Test.@test occursin("prepare_cache", err.required_method)
            end
        end

    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_ad_backend() = TestADBackend.test_ad_backend()

