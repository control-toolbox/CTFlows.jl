module TestBuildFlow

import Test
import CTFlows.Systems
import CTFlows.Flows
import CTFlows.Modelers
import CTFlows.Integrators
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

struct FakeIntegrator <: Integrators.AbstractODEIntegrator
    options::CTSolvers.Strategies.StrategyOptions
end

function FakeIntegrator()
    return FakeIntegrator(CTSolvers.Strategies.StrategyOptions())
end

struct FakeModeler <: Modelers.AbstractFlowModeler
    options::CTSolvers.Strategies.StrategyOptions
end

function FakeModeler()
    return FakeModeler(CTSolvers.Strategies.StrategyOptions())
end

function (modeler::FakeModeler)(input, ad_backend)
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

function test_build_flow()
    Test.@testset "build_flow Pipeline Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Atomic Form
        # ====================================================================

        Test.@testset "Atomic Form" begin
            sys = FakeSystem(2)
            integ = FakeIntegrator()

            Test.@testset "returns Flow" begin
                flow = Pipelines.build_flow(sys, integ)
                Test.@test flow isa Flows.Flow
                Test.@test flow isa Flows.AbstractFlow
            end

            Test.@testset "stores system" begin
                flow = Pipelines.build_flow(sys, integ)
                Test.@test Flows.system(flow) === sys
            end

            Test.@testset "stores integrator" begin
                flow = Pipelines.build_flow(sys, integ)
                Test.@test Flows.integrator(flow) === integ
            end
        end

        # ====================================================================
        # UNIT TESTS - Pipeline Alias
        # ====================================================================

        Test.@testset "Pipeline Alias" begin
            modeler = FakeModeler()
            integ = FakeIntegrator()
            ad_backend = FakeADBackend()
            input = :fake_input

            Test.@testset "returns Flow" begin
                flow = Pipelines.build_flow(input, modeler, integ, ad_backend)
                Test.@test flow isa Flows.Flow
                Test.@test flow isa Flows.AbstractFlow
            end

            Test.@testset "system from modeler" begin
                flow = Pipelines.build_flow(input, modeler, integ, ad_backend)
                Test.@test Flows.system(flow) isa FakeSystem
            end

            Test.@testset "stores integrator" begin
                flow = Pipelines.build_flow(input, modeler, integ, ad_backend)
                Test.@test Flows.integrator(flow) === integ
            end
        end
    end
end

end # module

test_build_flow() = TestBuildFlow.test_build_flow()
