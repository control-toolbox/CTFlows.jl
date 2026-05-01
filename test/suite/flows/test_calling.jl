module TestCalling

import Test
import CTFlows.Systems
import CTFlows.Flows
import CTFlows.Integrators
import CTFlows.Common

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for testing the calling workflow
# ==============================================================================

"""
Fake system for testing the calling workflow.
"""
struct FakeSystemForCalling <: Systems.AbstractSystem{Common.Autonomous, Common.Fixed}
    state_dim::Int
end

"""
Fake integrator for testing the calling workflow.
Tracks which methods were called.
"""
mutable struct FakeIntegratorForCalling <: Integrators.AbstractIntegrator
    build_problem_called::Bool
    integrate_called::Bool
    build_solution_called::Bool
    problem_result::Any
    ode_solution::Any
    final_solution::Any
end

function FakeIntegratorForCalling()
    return FakeIntegratorForCalling(false, false, false, nothing, nothing, nothing)
end

# Implement integrator callable for building ODE problem
function (integ::FakeIntegratorForCalling)(system::Systems.AbstractSystem, config::Common.AbstractConfig; variable=nothing)
    integ.build_problem_called = true
    integ.problem_result = :fake_ode_problem
    return integ.problem_result
end

# Implement integrator callable for integration
function (integ::FakeIntegratorForCalling)(prob)
    integ.integrate_called = true
    integ.ode_solution = :fake_ode_solution
    return integ.ode_solution
end

# Implement integrator callable for building solution
function (integ::FakeIntegratorForCalling)(ode_sol, sys::Systems.AbstractSystem, config::Common.AbstractConfig)
    integ.build_solution_called = true
    integ.final_solution = :fake_flow_solution
    return integ.final_solution
end

"""
Fake flow for testing the calling workflow.
"""
struct FakeFlowForCalling{TD<:Common.TimeDependence, VD<:Common.VariableDependence, S<:Systems.AbstractSystem{TD, VD}, I} <: Flows.AbstractFlow{TD, VD}
    sys::S
    integ::I
end

function Flows.system(flow::FakeFlowForCalling)
    return flow.sys
end

function Flows.integrator(flow::FakeFlowForCalling)
    return flow.integ
end

# ==============================================================================
# Test function
# ==============================================================================

function test_calling()
    Test.@testset "Calling Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - call function workflow
        # ====================================================================

        Test.@testset "call function workflow" begin
            Test.@testset "all steps are executed in order" begin
                # Setup
                sys = FakeSystemForCalling(2)
                integ = FakeIntegratorForCalling()
                flow = FakeFlowForCalling{Common.Autonomous, Common.Fixed, typeof(sys), typeof(integ)}(sys, integ)
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                
                # Execute
                result = Flows.call(flow, config)
                
                # Verify all steps were called
                Test.@test integ.build_problem_called === true
                Test.@test integ.integrate_called === true
                Test.@test integ.build_solution_called === true
                
                # Verify result
                Test.@test result === :fake_flow_solution
            end

            Test.@testset "call with variable parameter (Fixed system)" begin
                sys = FakeSystemForCalling(2)
                integ = FakeIntegratorForCalling()
                flow = FakeFlowForCalling{Common.Autonomous, Common.Fixed, typeof(sys), typeof(integ)}(sys, integ)
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                
                # Call with variable (should be accepted even for Fixed)
                result = Flows.call(flow, config; variable=0.5)
                
                Test.@test integ.build_problem_called === true
                Test.@test integ.integrate_called === true
                Test.@test integ.build_solution_called === true
                Test.@test result === :fake_flow_solution
            end

            Test.@testset "call with TrajectoryConfig" begin
                sys = FakeSystemForCalling(2)
                integ = FakeIntegratorForCalling()
                flow = FakeFlowForCalling{Common.Autonomous, Common.Fixed, typeof(sys), typeof(integ)}(sys, integ)
                config = Common.TrajectoryConfig((0.0, 1.0), [1.0, 0.0])
                
                result = Flows.call(flow, config)
                
                Test.@test integ.build_problem_called === true
                Test.@test integ.integrate_called === true
                Test.@test integ.build_solution_called === true
                Test.@test result === :fake_flow_solution
            end
        end

        # ====================================================================
        # UNIT TESTS - Helper functions
        # ====================================================================

        Test.@testset "Helper functions" begin
            Test.@testset "build_ode_problem calls integrator" begin
                sys = FakeSystemForCalling(2)
                integ = FakeIntegratorForCalling()
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                
                prob = Flows.build_ode_problem(sys, config, integ; variable=nothing)
                
                Test.@test integ.build_problem_called === true
                Test.@test prob === :fake_ode_problem
            end

            Test.@testset "integrate calls integrator" begin
                integ = FakeIntegratorForCalling()
                fake_prob = :fake_problem
                
                ode_sol = Flows.integrate(fake_prob, integ)
                
                Test.@test integ.integrate_called === true
                Test.@test ode_sol === :fake_ode_solution
            end

            Test.@testset "build_flow_solution calls integrator" begin
                sys = FakeSystemForCalling(2)
                integ = FakeIntegratorForCalling()
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                fake_ode_sol = :fake_ode_sol
                
                flow_sol = Flows.build_flow_solution(fake_ode_sol, sys, config, integ)
                
                Test.@test integ.build_solution_called === true
                Test.@test flow_sol === :fake_flow_solution
            end
        end

        # ====================================================================
        # UNIT TESTS - Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "call function is exported" begin
                Test.@test isdefined(Flows, :call)
            end
        end
    end
end

end # module

test_calling() = TestCalling.test_calling()