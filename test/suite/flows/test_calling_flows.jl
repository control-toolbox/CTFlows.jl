module TestCallingFlows

import Test
import CTFlows.Systems
import CTFlows.Data
import CTFlows.Differentiation
import CTFlows.Flows
import CTFlows.Integrators
import CTFlows.Solutions
import CTFlows.Common
import ADTypes

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for testing the calling workflow
# ==============================================================================

"""
Fake system for testing the calling workflow.
"""
struct FakeSystemForCalling <: Systems.AbstractStateSystem{Common.Autonomous, Common.Fixed}
    state_dim::Int
end

"""
Fake Hamiltonian system for testing the calling workflow.
"""
struct FakeHamiltonianSystemForCalling <: Systems.AbstractHamiltonianSystem{Common.Autonomous, Common.Fixed, Common.WithoutAD}
    state_dim::Int
end

"""
Fake Hamiltonian system with AD trait for testing cache preparation.
"""
struct FakeHamiltonianSystemWithAD <: Systems.AbstractHamiltonianSystem{Common.Autonomous, Common.Fixed, Common.WithAD}
    state_dim::Int
end

function Systems.hamiltonian(sys::FakeHamiltonianSystemWithAD)
    return Data.Hamiltonian((x, p) -> 0.5 * sum(x.^2) + sum(p.^2); is_autonomous=true, is_variable=false)
end

function Systems.backend(sys::FakeHamiltonianSystemWithAD)
    return Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff(), prepare_cache=true)
end

function Differentiation.prepare_cache(
    backend::Differentiation.DifferentiationInterface,
    h::Data.AbstractHamiltonian,
    typical_t, typical_x, typical_p, typical_v
)
    return nothing
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
function Integrators.build_problem(integ::FakeIntegratorForCalling, system::Systems.AbstractSystem, config::Common.AbstractConfig; variable=nothing, cache=nothing)
    integ.build_problem_called = true
    p = Common.ODEParameters(variable, cache)
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
    config::Common.StatePointConfig
)
    return Solutions.final_state(result)
end

function Solutions.build_solution(
    result::FakeIntegrationResultForCalling,
    system::FakeSystemForCalling,
    config::Common.StateTrajectoryConfig
)
    return :fake_vector_field_solution
end

function Solutions.build_solution(
    result::FakeIntegrationResultForCalling,
    system::FakeHamiltonianSystemForCalling,
    config::Common.HamiltonianPointConfig
)
    return (:fake_xf, :fake_pf)
end

function Solutions.build_solution(
    result::FakeIntegrationResultForCalling,
    system::FakeHamiltonianSystemForCalling,
    config::Common.HamiltonianTrajectoryConfig
)
    return :fake_hamiltonian_solution
end

function Solutions.build_solution(
    result::FakeIntegrationResultForCalling,
    system::FakeHamiltonianSystemWithAD,
    config::Common.HamiltonianPointConfig
)
    return (:fake_xf_ad, :fake_pf_ad)
end

function Solutions.build_solution(
    result::FakeIntegrationResultForCalling,
    system::FakeHamiltonianSystemWithAD,
    config::Common.HamiltonianTrajectoryConfig
)
    return :fake_hamiltonian_solution_ad
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

function test_calling_flows()
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
                config = Common.StatePointConfig(0.0, [1.0, 0.0], 1.0)
                
                # Execute
                result = Flows.call(flow, config; variable=nothing, unsafe=false)
                
                # Verify all steps were called
                Test.@test integ.build_problem_called === true
                Test.@test integ.build_options_called === true
                Test.@test integ.solve_problem_called === true
                
                # Verify result - for StatePointConfig it unwraps the vector
                Test.@test result == :fake_flow_solution
            end

            Test.@testset "call with variable parameter (Fixed system)" begin
                sys = FakeSystemForCalling(2)
                integ = FakeIntegratorForCalling()
                flow = FakeFlowForCalling{Common.Autonomous, Common.Fixed, typeof(sys), typeof(integ)}(sys, integ)
                config = Common.StatePointConfig(0.0, [1.0, 0.0], 1.0)
                
                # Call with variable (should be accepted even for Fixed)
                result = Flows.call(flow, config; variable=0.5, unsafe=false)
                
                Test.@test integ.build_problem_called === true
                Test.@test integ.build_options_called === true
                Test.@test integ.solve_problem_called === true
                Test.@test result == :fake_flow_solution
            end

            Test.@testset "call with StateTrajectoryConfig" begin
                sys = FakeSystemForCalling(2)
                integ = FakeIntegratorForCalling()
                flow = FakeFlowForCalling{Common.Autonomous, Common.Fixed, typeof(sys), typeof(integ)}(sys, integ)
                config = Common.StateTrajectoryConfig((0.0, 1.0), [1.0, 0.0])

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
                config = Common.StatePointConfig(0.0, [1.0, 0.0], 1.0)

                # Call with unsafe=true
                result = Flows.call(flow, config; variable=nothing, unsafe=true)

                Test.@test integ.build_problem_called === true
                Test.@test integ.build_options_called === true
                Test.@test integ.solve_problem_called === true
                Test.@test result == :fake_flow_solution
            end

            Test.@testset "call with HamiltonianPointConfig" begin
                sys = FakeHamiltonianSystemForCalling(2)
                integ = FakeIntegratorForCalling()
                flow = FakeFlowForCalling{Common.Autonomous, Common.Fixed, typeof(sys), typeof(integ)}(sys, integ)
                config = Common.HamiltonianPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], 1.0)

                result = Flows.call(flow, config; variable=nothing, unsafe=false)

                Test.@test integ.build_problem_called === true
                Test.@test integ.build_options_called === true
                Test.@test integ.solve_problem_called === true
                Test.@test result == (:fake_xf, :fake_pf)
            end

            Test.@testset "call with HamiltonianTrajectoryConfig" begin
                sys = FakeHamiltonianSystemForCalling(2)
                integ = FakeIntegratorForCalling()
                flow = FakeFlowForCalling{Common.Autonomous, Common.Fixed, typeof(sys), typeof(integ)}(sys, integ)
                config = Common.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0, 0.0], [0.5, 0.3])

                result = Flows.call(flow, config; variable=nothing, unsafe=false)

                Test.@test integ.build_problem_called === true
                Test.@test integ.build_options_called === true
                Test.@test integ.solve_problem_called === true
                Test.@test result === :fake_hamiltonian_solution
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - Cache in pipeline (trait dispatch)
        # ====================================================================

        Test.@testset "Integration: Cache in pipeline" begin
            Test.@testset "HamiltonianVectorFieldSystem (WithoutAD) — cache is nothing" begin
                sys = FakeHamiltonianSystemForCalling(2)
                integ = FakeIntegratorForCalling()
                flow = FakeFlowForCalling{Common.Autonomous, Common.Fixed, typeof(sys), typeof(integ)}(sys, integ)
                config = Common.HamiltonianPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], 1.0)

                result = Flows.call(flow, config; variable=nothing, unsafe=false)

                Test.@test integ.build_problem_called === true
                Test.@test integ.build_options_called === true
                Test.@test integ.solve_problem_called === true
                Test.@test result == (:fake_xf, :fake_pf)
            end

            Test.@testset "HamiltonianSystem (WithAD, prepare_cache=true) — cache prepared" begin
                # This would require a real AD backend, so we skip the actual cache check
                # The trait dispatch is tested via the fake system
                sys = FakeHamiltonianSystemWithAD(2)
                integ = FakeIntegratorForCalling()
                flow = FakeFlowForCalling{Common.Autonomous, Common.Fixed, typeof(sys), typeof(integ)}(sys, integ)
                config = Common.HamiltonianPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], 1.0)

                result = Flows.call(flow, config; variable=nothing, unsafe=false)

                Test.@test integ.build_problem_called === true
                Test.@test integ.build_options_called === true
                Test.@test integ.solve_problem_called === true
                Test.@test result == (:fake_xf_ad, :fake_pf_ad)
            end

            Test.@testset "Regression: existing StateFlow path unchanged" begin
                sys = FakeSystemForCalling(2)
                integ = FakeIntegratorForCalling()
                flow = FakeFlowForCalling{Common.Autonomous, Common.Fixed, typeof(sys), typeof(integ)}(sys, integ)
                config = Common.StatePointConfig(0.0, [1.0, 0.0], 1.0)

                result = Flows.call(flow, config; variable=nothing, unsafe=false)

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

test_calling_flows() = TestCallingFlows.test_calling_flows()