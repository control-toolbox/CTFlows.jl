module TestBuildFlow

import Test
import CTFlows.Systems
import CTFlows.Flows
import CTFlows.Integrators
import CTFlows.Pipelines
import CTSolvers: CTSolvers

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

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
        # UNIT TESTS - Flow Constructor from VectorField
        # ====================================================================

        Test.@testset "Flow Constructor from VectorField" begin
            Test.@testset "builds system then flow" begin
                vf = Systems.VectorField(x -> -x, Systems.Autonomous, Systems.Fixed)
                flow = Pipelines.Flow(vf, :sciml)
                Test.@test flow isa Flows.Flow
                Test.@test Flows.system(flow) isa Systems.VectorFieldSystem
            end

            Test.@testset "with options" begin
                vf = Systems.VectorField(x -> -x, Systems.Autonomous, Systems.Fixed)
                flow = Pipelines.Flow(vf, :sciml; reltol=1e-8)
                Test.@test flow isa Flows.Flow
            end

            Test.@testset "NonFixed VectorField" begin
                vf = Systems.VectorField((x, v) -> x .+ v, Systems.Autonomous, Systems.NonFixed)
                flow = Pipelines.Flow(vf, :sciml)
                Test.@test flow isa Flows.Flow
                sys = Flows.system(flow)
                Test.@test Systems.variable_dependence(sys) === Systems.NonFixed
            end
        end
    end
end

end # module

test_build_flow() = TestBuildFlow.test_build_flow()
