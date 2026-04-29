module TestIntegrate

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

function Systems.dimensions(sys::FakeSystem)
    return (n_x=sys.state_dim, n_p=sys.state_dim, n_u=0, n_v=0)
end

function Systems.build_solution(sys::FakeSystem, ode_sol)
    return ode_sol
end

struct FakeFlow <: Flows.AbstractFlow
    sys::Systems.AbstractSystem
    captured_config::Ref{Any}
end

function FakeFlow(sys)
    return FakeFlow(sys, Ref{Any}(nothing))
end

function (f::FakeFlow)(config)
    f.captured_config[] = config
    return :fake_trajectory
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
        # UNIT TESTS - Config-based Integration
        # ====================================================================

        Test.@testset "Config-based Integration" begin
            sys = FakeSystem(2)
            flow = FakeFlow(sys)

            Test.@testset "delegates to flow callable with PointConfig" begin
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                result = Pipelines.integrate(flow, config)
                Test.@test result === :fake_trajectory
            end

            Test.@testset "passes config correctly" begin
                flow = FakeFlow(sys)
                config = Common.PointConfig(0.5, [1.0, 2.0], 2.5)
                Pipelines.integrate(flow, config)
                Test.@test flow.captured_config[] === config
            end

            Test.@testset "delegates to flow callable with TrajectoryConfig" begin
                config = Common.TrajectoryConfig((0.0, 1.0), [1.0, 0.0])
                result = Pipelines.integrate(flow, config)
                Test.@test result === :fake_trajectory
            end
        end
    end
end

end # module

test_integrate() = TestIntegrate.test_integrate()
