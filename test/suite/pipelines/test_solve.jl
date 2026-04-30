module TestSolve

import Test
import CTFlows.Systems
import CTFlows.Flows
import CTFlows.Pipelines
import CTFlows.Common

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

function Systems.build_solution(sys::FakeSystem, ode_sol, flow, config)
    return (:packaged, ode_sol)
end

function Systems.ode_problem(sys::FakeSystem, config; kwargs...)
    return :fake_ode_problem
end

function Systems.variable_dependence(sys::FakeSystem)
    return Common.Fixed
end

struct FakeFlow <: Flows.AbstractFlow
    sys::Systems.AbstractSystem
    captured_config::Ref{Any}
end

function Flows.system(flow::FakeFlow)
    return flow.sys
end

function Flows.integrator(flow::FakeFlow)
    # Fake integrator that returns a fake ODE solution
    return FakeIntegrator(:fake_ode_sol)
end

struct FakeIntegrator
    result::Any
end

function (integ::FakeIntegrator)(prob)
    return integ.result
end

function FakeFlow(sys)
    return FakeFlow(sys, Ref{Any}(nothing))
end

function (f::FakeFlow)(config)
    f.captured_config[] = config
    return :fake_ode_sol
end

# ==============================================================================
# Test function
# ==============================================================================

function test_solve()
    Test.@testset "solve Pipeline Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Config-based Solve
        # ====================================================================

        Test.@testset "Config-based Solve" begin
            sys = FakeSystem(2)
            flow = FakeFlow(sys)

            Test.@testset "performs integration + build solution" begin
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                result = Pipelines.solve(flow, config)
                Test.@test result === (:packaged, :fake_ode_sol)
            end

            Test.@testset "solve() calls ode_problem, integrator, build_solution" begin
                sys = FakeSystem(2)
                flow = FakeFlow(sys)
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                result = Pipelines.solve(flow, config)
                Test.@test result === (:packaged, :fake_ode_sol)
            end
        end

        # ====================================================================
        # UNIT TESTS - solve() does integration + build
        # ====================================================================

        Test.@testset "solve() does integration + build solution" begin
            Test.@testset "calls ode_problem, integrator, build_solution" begin
                sys = FakeSystem(2)
                flow = FakeFlow(sys)
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                result = Pipelines.solve(flow, config)
                Test.@test result === (:packaged, :fake_ode_sol)
            end
        end

        # ====================================================================
        # UNIT TESTS - VectorFieldSolution
        # ====================================================================

        Test.@testset "VectorFieldSolution" begin
            Test.@testset "constructs with raw ODE solution" begin
                raw_ode_sol = (t = [0.0, 1.0], u = [[1.0], [2.0]])
                sol = Systems.VectorFieldSolution(raw_ode_sol)
                Test.@test sol isa Systems.VectorFieldSolution
                Test.@test sol.raw === raw_ode_sol
            end
        end
    end
end

end # module

test_solve() = TestSolve.test_solve()
