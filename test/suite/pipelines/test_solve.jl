module TestSolve

import Test
import CTFlows.Systems
import CTFlows.Flows
import CTFlows.Pipelines

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
    return (:packaged, ode_sol)
end

struct FakeFlow <: Flows.AbstractFlow
    sys::Systems.AbstractSystem
    captured_tspan::Ref{Any}
    captured_x0::Ref{Any}
    captured_p0::Ref{Any}
end

function FakeFlow(sys)
    return FakeFlow(sys, Ref{Any}(nothing), Ref{Any}(nothing), Ref{Any}(nothing))
end

function (f::FakeFlow)(t0, x0, tf)
    f.captured_tspan[] = (t0, tf)
    f.captured_x0[] = x0
    return :fake_ode_sol
end

function (f::FakeFlow)(t0, x0, p0, tf)
    f.captured_tspan[] = (t0, tf)
    f.captured_x0[] = x0
    f.captured_p0[] = p0
    return :fake_ode_sol
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

function test_solve()
    Test.@testset "solve Pipeline Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - State Solve
        # ====================================================================

        Test.@testset "State Solve" begin
            sys = FakeSystem(2)
            flow = FakeFlow(sys)

            Test.@testset "returns packaged solution" begin
                result = Pipelines.solve(flow, (0.0, 1.0), [1.0, 0.0])
                Test.@test result == (:packaged, :fake_ode_sol)
            end

            Test.@testset "calls integrate with correct args" begin
                flow = FakeFlow(sys)
                Pipelines.solve(flow, (0.5, 2.5), [1.0, 2.0])
                Test.@test flow.captured_tspan[] == (0.5, 2.5)
                Test.@test flow.captured_x0[] == [1.0, 2.0]
            end

            Test.@testset "calls build_solution" begin
                result = Pipelines.solve(flow, (0.0, 1.0), [1.0, 0.0])
                Test.@test result isa Tuple && result[1] == :packaged
            end
        end

        # ====================================================================
        # UNIT TESTS - State + Costate Solve
        # ====================================================================

        Test.@testset "State + Costate Solve" begin
            sys = FakeSystem(2)
            flow = FakeFlow(sys)

            Test.@testset "returns packaged solution" begin
                result = Pipelines.solve(flow, (0.0, 1.0), [1.0, 0.0], [0.0, 0.0])
                Test.@test result == (:packaged, :fake_ode_sol)
            end

            Test.@testset "calls integrate with correct args" begin
                flow = FakeFlow(sys)
                Pipelines.solve(flow, (0.5, 2.5), [1.0, 2.0], [0.1, 0.2])
                Test.@test flow.captured_tspan[] == (0.5, 2.5)
                Test.@test flow.captured_x0[] == [1.0, 2.0]
                Test.@test flow.captured_p0[] == [0.1, 0.2]
            end

            Test.@testset "calls build_solution" begin
                result = Pipelines.solve(flow, (0.0, 1.0), [1.0, 0.0], [0.0, 0.0])
                Test.@test result isa Tuple && result[1] == :packaged
            end
        end
    end
end

end # module

test_solve() = TestSolve.test_solve()
