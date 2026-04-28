module TestBuildSystem

import Test
import CTFlows.Systems
import CTFlows.Modelers
import CTFlows.ADBackends
import CTFlows.Pipelines
import CTSolvers: CTSolvers

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Fake types for testing
# ==============================================================================

"""
Fake system for testing.
"""
struct FakeSystem <: Systems.AbstractSystem
    state_dim::Int
end

function Systems.rhs!(sys::FakeSystem)
    return (du, u, p, t) -> nothing
end

function Systems.dimensions(sys::FakeSystem)
    return (n_x=sys.state_dim, n_p=sys.state_dim, n_u=0, n_v=0)
end

function Systems.build_solution(sys::FakeSystem, ode_sol)
    return ode_sol
end

struct FakeModeler <: Modelers.AbstractFlowModeler
    options::CTSolvers.Strategies.StrategyOptions
    captured_input::Ref{Any}
    captured_ad::Ref{Any}
end

function FakeModeler()
    return FakeModeler(CTSolvers.Strategies.StrategyOptions(), Ref{Any}(nothing), Ref{Any}(nothing))
end

function (modeler::FakeModeler)(input, ad_backend)
    modeler.captured_input[] = input
    modeler.captured_ad[] = ad_backend
    return FakeSystem(2)
end

struct FakeADBackend <: ADBackends.AbstractADBackend
    options::CTSolvers.Strategies.StrategyOptions
end

function FakeADBackend()
    return FakeADBackend(CTSolvers.Strategies.StrategyOptions())
end

# ==============================================================================
# Test function
# ==============================================================================

function test_build_system()
    Test.@testset "build_system Pipeline Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Pipeline Delegation
        # ====================================================================

        Test.@testset "Pipeline Delegation" begin
            modeler = FakeModeler()
            ad_backend = FakeADBackend()
            input = :fake_input

            Test.@testset "delegates to modeler callable" begin
                result = Pipelines.build_system(input, modeler, ad_backend)
                Test.@test result isa Systems.AbstractSystem
                Test.@test result isa FakeSystem
            end

            Test.@testset "passes input to modeler" begin
                modeler = FakeModeler()
                Pipelines.build_system(:test_input, modeler, ad_backend)
                Test.@test modeler.captured_input[] === :test_input
            end

            Test.@testset "passes ad_backend to modeler" begin
                modeler = FakeModeler()
                Pipelines.build_system(input, modeler, ad_backend)
                Test.@test modeler.captured_ad[] === ad_backend
            end
        end
    end
end

end # module

test_build_system() = TestBuildSystem.test_build_system()
