module TestIntegrate

import Test
import CTFlows.Systems
import CTFlows.Flows
import CTFlows.Pipelines

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

struct FakeFlow <: Flows.AbstractFlow
    sys::Systems.AbstractSystem
    captured_args::Ref{Vector{Any}}
end

function FakeFlow(sys)
    return FakeFlow(sys, Ref{Any}[])
end

function (f::FakeFlow)(t0, x0, tf)
    push!(f.captured_args[], (t0, x0, tf))
    return :fake_trajectory
end

function (f::FakeFlow)(t0, x0, p0, tf)
    push!(f.captured_args[], (t0, x0, p0, tf))
    return :fake_trajectory_with_costate
end

function Flows.system(f::FakeFlow)
    return f.sys
end

function Flows.integrator(f::FakeFlow)
    return :fake_integrator
end

# ==============================================================================
# Test function
# ==============================================================================

function test_integrate()
    Test.@testset "integrate Pipeline Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - State Integration
        # ====================================================================

        Test.@testset "State Integration" begin
            sys = FakeSystem(2)
            flow = FakeFlow(sys)

            Test.@testset "delegates to flow callable" begin
                result = Pipelines.integrate(flow, 0.0, [1.0, 0.0], 1.0)
                Test.@test result === :fake_trajectory
            end

            Test.@testset "passes arguments correctly" begin
                flow = FakeFlow(sys)
                Pipelines.integrate(flow, 0.5, [1.0, 2.0], 2.5)
                Test.@test length(flow.captured_args[]) == 1
                Test.@test flow.captured_args[][1] == (0.5, [1.0, 2.0], 2.5)
            end
        end

        # ====================================================================
        # UNIT TESTS - State + Costate Integration
        # ====================================================================

        Test.@testset "State + Costate Integration" begin
            sys = FakeSystem(2)
            flow = FakeFlow(sys)

            Test.@testset "delegates to flow callable" begin
                result = Pipelines.integrate(flow, 0.0, [1.0, 0.0], [0.0, 0.0], 1.0)
                Test.@test result === :fake_trajectory_with_costate
            end

            Test.@testset "passes arguments correctly" begin
                flow = FakeFlow(sys)
                Pipelines.integrate(flow, 0.5, [1.0, 2.0], [0.1, 0.2], 2.5)
                Test.@test length(flow.captured_args[]) == 1
                Test.@test flow.captured_args[][1] == (0.5, [1.0, 2.0], [0.1, 0.2], 2.5)
            end
        end
    end
end

end # module

test_integrate() = TestIntegrate.test_integrate()
