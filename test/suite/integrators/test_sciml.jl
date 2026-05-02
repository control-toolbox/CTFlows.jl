module TestSciML

import Test
import CTBase.Exceptions
import CTFlows.Integrators
import CTFlows.Common
import CTSolvers: CTSolvers

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for testing stubs
# ==============================================================================

"""
Fake SciML tag for testing stub methods on AbstractTag.
"""
struct FakeSciMLTag <: Common.AbstractTag end

"""
Fake SciML integrator for testing stub methods on AbstractSciMLIntegrator.
"""
struct FakeSciMLIntegrator <: Integrators.AbstractSciMLIntegrator
    data::String
end

"""
Fake SciML strategy for testing constructor stub.
"""
struct FakeSciML <: Integrators.AbstractSciMLIntegrator
    options::CTSolvers.Strategies.StrategyOptions
end

# Fake constructor that throws ExtensionError
function FakeSciML(; kwargs...)
    throw(
        Exceptions.ExtensionError(
            :SciML;
            message="SciML extension not loaded",
            feature="SciML integrator",
            context="FakeSciML constructor - extension availability check",
        ),
    )
end

# ==============================================================================
# Test function
# ==============================================================================

function test_sciml()
    Test.@testset "SciML Integrator Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Type Hierarchy
        # ====================================================================

        Test.@testset "Type Hierarchy" begin
            Test.@test Integrators.SciMLTag <: Common.AbstractTag
        end

        # ====================================================================
        # UNIT TESTS - AbstractStrategy Contract
        # ====================================================================

        Test.@testset "AbstractStrategy Contract" begin

            Test.@testset "id returns :sciml" begin
                Test.@test CTSolvers.Strategies.id(Integrators.SciML) === :sciml
            end

            Test.@testset "description returns non-empty string" begin
                desc = CTSolvers.Strategies.description(Integrators.SciML)
                Test.@test desc isa String
                Test.@test !isempty(desc)
                Test.@test occursin("SciML", desc)
            end
        end

        # ====================================================================
        # UNIT TESTS - Extension Error Stubs
        # ====================================================================

        Test.@testset "Extension Error Stubs" begin

            Test.@testset "metadata throws ExtensionError" begin
                fake_integrator = FakeSciMLIntegrator("test")
                Test.@test_throws Exceptions.ExtensionError CTSolvers.Strategies.metadata(typeof(fake_integrator))
            end

            Test.@testset "build_sciml_integrator throws ExtensionError" begin
                Test.@test_throws Exceptions.ExtensionError Integrators.build_sciml_integrator(FakeSciMLTag)
            end
        end

        # ====================================================================
        # UNIT TESTS - Error Messages
        # ====================================================================

        Test.@testset "Error Messages" begin

            Test.@testset "constructor error mentions SciML" begin
                try
                    FakeSciML()
                    Test.@test false  # Should not reach here
                catch err
                    Test.@test err isa Exceptions.ExtensionError
                    msg = sprint(showerror, err)
                    Test.@test occursin("SciML", msg)
                end
            end

            Test.@testset "metadata error mentions OrdinaryDiffEqTsit5" begin
                fake_integrator = FakeSciMLIntegrator("test")
                try
                    CTSolvers.Strategies.metadata(typeof(fake_integrator))
                    Test.@test false  # Should not reach here
                catch err
                    Test.@test err isa Exceptions.ExtensionError
                    msg = sprint(showerror, err)
                    Test.@test occursin("OrdinaryDiffEqTsit5", msg)
                end
            end
        end
    end
end

end # module

test_sciml() = TestSciML.test_sciml()