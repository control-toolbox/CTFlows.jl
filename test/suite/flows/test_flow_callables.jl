module TestFlowCallables

import Test
import CTFlows.Systems
import CTFlows.Flows
import CTFlows.Integrators
import CTFlows.Solutions
import CTFlows.Common

using StaticArrays: SA

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for testing flow callables
# ==============================================================================

struct FakeStateSystemFC <: Systems.AbstractStateSystem{Common.Autonomous, Common.Fixed}
    n::Int
end

struct FakeHamSysFC <: Systems.AbstractHamiltonianSystem{Common.Autonomous, Common.Fixed, Common.WithoutAD}
    n::Int
end

struct FakeResultFC <: Solutions.AbstractIntegrationResult end

Solutions.final_state(::FakeResultFC) = [0.0, 0.0]

mutable struct FakeIntegFC <: Integrators.AbstractIntegrator
    last_config::Any
end

function FakeIntegFC()
    return FakeIntegFC(nothing)
end

function Integrators.build_problem(integ::FakeIntegFC, sys::Systems.AbstractSystem, config::Common.AbstractConfig; variable=nothing, cache=nothing)
    integ.last_config = config
    return :fake_prob
end

function Integrators.build_options(integ::FakeIntegFC, config::Union{Common.AbstractConfig, Nothing})
    return Dict{Symbol,Any}()
end

function Integrators.solve_problem(integ::FakeIntegFC, prob, options::Dict{Symbol,Any}; unsafe=false)
    return FakeResultFC()
end

function Solutions.build_solution(result::FakeResultFC, sys::FakeStateSystemFC, config::Common.StatePointConfig)
    return :state_point_sol
end

function Solutions.build_solution(result::FakeResultFC, sys::FakeStateSystemFC, config::Common.StateTrajectoryConfig)
    return :state_traj_sol
end

function Solutions.build_solution(result::FakeResultFC, sys::FakeHamSysFC, config::Common.HamiltonianPointConfig)
    return :ham_point_sol
end

function Solutions.build_solution(result::FakeResultFC, sys::FakeHamSysFC, config::Common.HamiltonianTrajectoryConfig)
    return :ham_traj_sol
end

# ==============================================================================
# Test function
# ==============================================================================

function test_flow_callables()
    Test.@testset "Flow Callables Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - StateFlow (t0, x0, tf) -> StatePointConfig
        # ====================================================================

        Test.@testset "StateFlow (t0, x0, tf) -> StatePointConfig" begin
            integ = FakeIntegFC(nothing)
            sys = FakeStateSystemFC(2)
            flow = Flows.StateFlow(sys, integ)

            Test.@testset "scalar x0" begin
                x0 = 1.0
                result = flow(0.0, x0, 1.0)
                Test.@test integ.last_config isa Common.StatePointConfig
                Test.@test integ.last_config.t0 == 0.0
                Test.@test integ.last_config.tf == 1.0
                Test.@test integ.last_config.x0 === x0
                Test.@test result === :state_point_sol
            end

            Test.@testset "vector x0" begin
                x0 = [1.0, 0.0]
                result = flow(0.0, x0, 1.0)
                Test.@test integ.last_config isa Common.StatePointConfig
                Test.@test integ.last_config.t0 == 0.0
                Test.@test integ.last_config.tf == 1.0
                Test.@test integ.last_config.x0 === x0
                Test.@test result === :state_point_sol
            end

            Test.@testset "SVector x0" begin
                x0 = SA[1.0, 0.0]
                result = flow(0.0, x0, 1.0)
                Test.@test integ.last_config isa Common.StatePointConfig
                Test.@test integ.last_config.t0 == 0.0
                Test.@test integ.last_config.tf == 1.0
                Test.@test integ.last_config.x0 === x0
                Test.@test result === :state_point_sol
            end

            Test.@testset "matrix x0" begin
                x0 = [1.0 2.0; 3.0 4.0]
                result = flow(0.0, x0, 1.0)
                Test.@test integ.last_config isa Common.StatePointConfig
                Test.@test integ.last_config.t0 == 0.0
                Test.@test integ.last_config.tf == 1.0
                Test.@test integ.last_config.x0 === x0
                Test.@test result === :state_point_sol
            end
        end

        # ====================================================================
        # UNIT TESTS - StateFlow (tspan, x0) -> StateTrajectoryConfig
        # ====================================================================

        Test.@testset "StateFlow (tspan, x0) -> StateTrajectoryConfig" begin
            integ = FakeIntegFC(nothing)
            sys = FakeStateSystemFC(2)
            flow = Flows.StateFlow(sys, integ)

            Test.@testset "vector x0" begin
                x0 = [1.0, 0.0]
                result = flow((0.0, 1.0), x0)
                Test.@test integ.last_config isa Common.StateTrajectoryConfig
                Test.@test integ.last_config.tspan == (0.0, 1.0)
                Test.@test integ.last_config.x0 === x0
                Test.@test result === :state_traj_sol
            end

            Test.@testset "SVector x0" begin
                x0 = SA[1.0, 0.0]
                result = flow((0.0, 1.0), x0)
                Test.@test integ.last_config isa Common.StateTrajectoryConfig
                Test.@test integ.last_config.tspan == (0.0, 1.0)
                Test.@test integ.last_config.x0 === x0
                Test.@test result === :state_traj_sol
            end

            Test.@testset "matrix x0" begin
                x0 = [1.0 2.0; 3.0 4.0]
                result = flow((0.0, 1.0), x0)
                Test.@test integ.last_config isa Common.StateTrajectoryConfig
                Test.@test integ.last_config.tspan == (0.0, 1.0)
                Test.@test integ.last_config.x0 === x0
                Test.@test result === :state_traj_sol
            end
        end

        # ====================================================================
        # UNIT TESTS - HamiltonianFlow (t0, x0, p0, tf) -> HamiltonianPointConfig
        # ====================================================================

        Test.@testset "HamiltonianFlow (t0, x0, p0, tf) -> HamiltonianPointConfig" begin
            integ = FakeIntegFC(nothing)
            sys = FakeHamSysFC(2)
            flow = Flows.HamiltonianFlow(sys, integ)

            Test.@testset "scalar x0, p0" begin
                x0 = 1.0
                p0 = 0.0
                result = flow(0.0, x0, p0, 1.0)
                Test.@test integ.last_config isa Common.HamiltonianPointConfig
                Test.@test integ.last_config.t0 == 0.0
                Test.@test integ.last_config.tf == 1.0
                Test.@test integ.last_config.x0 === x0
                Test.@test integ.last_config.p0 === p0
                Test.@test result === :ham_point_sol
            end

            Test.@testset "vector x0, p0" begin
                x0 = [1.0, 0.0]
                p0 = [0.0, 1.0]
                result = flow(0.0, x0, p0, 1.0)
                Test.@test integ.last_config isa Common.HamiltonianPointConfig
                Test.@test integ.last_config.t0 == 0.0
                Test.@test integ.last_config.tf == 1.0
                Test.@test integ.last_config.x0 === x0
                Test.@test integ.last_config.p0 === p0
                Test.@test result === :ham_point_sol
            end

            Test.@testset "SVector x0, p0" begin
                x0 = SA[1.0, 0.0]
                p0 = SA[0.0, 1.0]
                result = flow(0.0, x0, p0, 1.0)
                Test.@test integ.last_config isa Common.HamiltonianPointConfig
                Test.@test integ.last_config.t0 == 0.0
                Test.@test integ.last_config.tf == 1.0
                Test.@test integ.last_config.x0 === x0
                Test.@test integ.last_config.p0 === p0
                Test.@test result === :ham_point_sol
            end
        end

        # ====================================================================
        # UNIT TESTS - HamiltonianFlow (tspan, x0, p0) -> HamiltonianTrajectoryConfig
        # ====================================================================

        Test.@testset "HamiltonianFlow (tspan, x0, p0) -> HamiltonianTrajectoryConfig" begin
            integ = FakeIntegFC(nothing)
            sys = FakeHamSysFC(2)
            flow = Flows.HamiltonianFlow(sys, integ)

            Test.@testset "vector x0, p0" begin
                x0 = [1.0, 0.0]
                p0 = [0.0, 1.0]
                result = flow((0.0, 1.0), x0, p0)
                Test.@test integ.last_config isa Common.HamiltonianTrajectoryConfig
                Test.@test integ.last_config.tspan == (0.0, 1.0)
                Test.@test integ.last_config.x0 === x0
                Test.@test integ.last_config.p0 === p0
                Test.@test result === :ham_traj_sol
            end

            Test.@testset "SVector x0, p0" begin
                x0 = SA[1.0, 0.0]
                p0 = SA[0.0, 1.0]
                result = flow((0.0, 1.0), x0, p0)
                Test.@test integ.last_config isa Common.HamiltonianTrajectoryConfig
                Test.@test integ.last_config.tspan == (0.0, 1.0)
                Test.@test integ.last_config.x0 === x0
                Test.@test integ.last_config.p0 === p0
                Test.@test result === :ham_traj_sol
            end
        end

        # ====================================================================
        # UNIT TESTS - variable and unsafe kwarg propagation
        # ====================================================================

        Test.@testset "variable and unsafe kwarg propagation" begin
            Test.@testset "StateFlow with variable kwarg" begin
                integ = FakeIntegFC(nothing)
                sys = FakeStateSystemFC(2)
                flow = Flows.StateFlow(sys, integ)
                result = flow(0.0, [1.0, 0.0], 1.0; variable=0.5, unsafe=true)
                Test.@test result === :state_point_sol
            end

            Test.@testset "HamiltonianFlow with variable kwarg" begin
                integ = FakeIntegFC(nothing)
                sys = FakeHamSysFC(2)
                flow = Flows.HamiltonianFlow(sys, integ)
                result = flow(0.0, [1.0, 0.0], [0.0, 1.0], 1.0; variable=0.5, unsafe=true)
                Test.@test result === :ham_point_sol
            end
        end

        # ====================================================================
        # UNIT TESTS - Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "StateFlow is exported" begin
                Test.@test isdefined(Flows, :StateFlow)
            end

            Test.@testset "HamiltonianFlow is exported" begin
                Test.@test isdefined(Flows, :HamiltonianFlow)
            end
        end
    end
end

end # module

test_flow_callables() = TestFlowCallables.test_flow_callables()
