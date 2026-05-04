module TestCalling

import Test
import CTFlows.Systems
import CTFlows.Flows
import CTFlows.Integrators
import CTFlows.Solutions
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
Fake integration result.
"""
struct FakeIntegrationResultForCalling <: Solutions.AbstractIntegrationResult end

Solutions.final_state(::FakeIntegrationResultForCalling) = :fake_flow_solution

"""
Fake integrator for testing the calling workflow.
Tracks which methods were called.
"""
mutable struct FakeIntegratorForCalling <: Integrators.AbstractIntegrator
    build_problem_called::Bool
    build_options_called::Bool
    solve_problem_called::Bool
    problem_result::Any
    ode_solution::Any
end

function FakeIntegratorForCalling()
    return FakeIntegratorForCalling(false, false, false, nothing, nothing)
end

# Implement named functions instead of callables
function Integrators.build_problem(integ::FakeIntegratorForCalling, system::Systems.AbstractSystem, config::Common.AbstractConfig; variable=nothing)
    integ.build_problem_called = true
    p = Common.ODEParameters(variable)
    integ.problem_result = :fake_ode_problem
    return integ.problem_result
end

function Integrators.build_options(integ::FakeIntegratorForCalling, config::Union{Common.AbstractConfig, Nothing})
    integ.build_options_called = true
    return Dict{Symbol,Any}()
end

function Integrators.solve_problem(integ::FakeIntegratorForCalling, prob, options::Dict{Symbol,Any}; unsafe=false)
    integ.solve_problem_called = true
    integ.ode_solution = FakeIntegrationResultForCalling()
    return integ.ode_solution
end

function Solutions.build_solution(
    result::FakeIntegrationResultForCalling,
    system::FakeSystemForCalling,
    config::Common.PointConfig
)
    return Solutions.final_state(result)
end

function Solutions.build_solution(
    result::FakeIntegrationResultForCalling,
    system::FakeSystemForCalling,
    config::Common.TrajectoryConfig
)
    return :fake_vector_field_solution
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
                result = Flows.call(flow, config; variable=nothing, unsafe=false)
                
                # Verify all steps were called
                Test.@test integ.build_problem_called === true
                Test.@test integ.build_options_called === true
                Test.@test integ.solve_problem_called === true
                
                # Verify result - for PointConfig it unwraps the vector
                Test.@test result == :fake_flow_solution
            end

            Test.@testset "call with variable parameter (Fixed system)" begin
                sys = FakeSystemForCalling(2)
                integ = FakeIntegratorForCalling()
                flow = FakeFlowForCalling{Common.Autonomous, Common.Fixed, typeof(sys), typeof(integ)}(sys, integ)
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                
                # Call with variable (should be accepted even for Fixed)
                result = Flows.call(flow, config; variable=0.5, unsafe=false)
                
                Test.@test integ.build_problem_called === true
                Test.@test integ.build_options_called === true
                Test.@test integ.solve_problem_called === true
                Test.@test result == :fake_flow_solution
            end

            Test.@testset "call with TrajectoryConfig" begin
                sys = FakeSystemForCalling(2)
                integ = FakeIntegratorForCalling()
                flow = FakeFlowForCalling{Common.Autonomous, Common.Fixed, typeof(sys), typeof(integ)}(sys, integ)
                config = Common.TrajectoryConfig((0.0, 1.0), [1.0, 0.0])

                result = Flows.call(flow, config; variable=nothing, unsafe=false)

                Test.@test integ.build_problem_called === true
                Test.@test integ.build_options_called === true
                Test.@test integ.solve_problem_called === true
                Test.@test result === :fake_vector_field_solution
            end

            Test.@testset "call with unsafe kwarg" begin
                sys = FakeSystemForCalling(2)
                integ = FakeIntegratorForCalling()
                flow = FakeFlowForCalling{Common.Autonomous, Common.Fixed, typeof(sys), typeof(integ)}(sys, integ)
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)

                # Call with unsafe=true
                result = Flows.call(flow, config; variable=nothing, unsafe=true)

                Test.@test integ.build_problem_called === true
                Test.@test integ.build_options_called === true
                Test.@test integ.solve_problem_called === true
                Test.@test result == :fake_flow_solution
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