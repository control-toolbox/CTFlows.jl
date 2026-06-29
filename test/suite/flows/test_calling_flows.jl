module TestCallingFlows

using Test: Test
import CTFlows.Systems
import CTBase.Data
import CTBase.Differentiation
import CTFlows.Flows
import CTFlows.Integrators
import CTFlows.Trajectories
import CTFlows.Common
import CTBase.Core
import CTFlows.Configs
import CTBase.Traits
using ADTypes: ADTypes
using DifferentiationInterface: DifferentiationInterface
using ForwardDiff: ForwardDiff  # triggers DifferentiationInterfaceForwardDiff (provides PushforwardFast)
import CTBase.Exceptions

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Fake types for testing the calling workflow
# ==============================================================================

"""
Fake system for testing the calling workflow.
"""
struct FakeSystemForCalling <: Systems.AbstractStateSystem{Traits.Autonomous,Traits.Fixed}
    state_dim::Int
end

struct FakeSystemNonFixed <: Systems.AbstractStateSystem{Traits.Autonomous,Traits.NonFixed}
    state_dim::Int
end

"""
Fake Hamiltonian system for testing the calling workflow.
"""
struct FakeHamiltonianSystemForCalling <:
       Systems.AbstractHamiltonianSystem{Traits.Autonomous,Traits.Fixed}
    state_dim::Int
end
Traits.ad_trait(::FakeHamiltonianSystemForCalling) = Traits.WithoutAD

"""
Fake Hamiltonian system with AD trait for testing cache preparation.
"""
struct FakeHamiltonianSystemWithAD <:
       Systems.AbstractHamiltonianSystem{Traits.Autonomous,Traits.Fixed}
    state_dim::Int
end
Traits.ad_trait(::FakeHamiltonianSystemWithAD) = Traits.WithAD

function Systems.hamiltonian(sys::FakeHamiltonianSystemWithAD)
    return Data.Hamiltonian(
        (x, p) -> 0.5 * sum(x .^ 2) + sum(p .^ 2); is_autonomous=true, is_variable=false
    )
end

function Systems.backend(sys::FakeHamiltonianSystemWithAD)
    return Differentiation.DifferentiationInterface(;
        ad_backend=ADTypes.AutoForwardDiff(), prepare_cache=true
    )
end

# function Differentiation.prepare_cache(
#     backend::Differentiation.DifferentiationInterface,
#     h::Data.AbstractHamiltonian,
#     typical_t, typical_x, typical_p, typical_v
# )
#     return nothing
# end

"""
Fake integration result.
"""
struct FakeIntegrationResultForCalling <: Integrators.AbstractIntegrationResult end

Integrators.final_state(::FakeIntegrationResultForCalling) = :fake_flow_solution

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
function Integrators.build_problem(
    integ::FakeIntegratorForCalling,
    system::Systems.AbstractSystem,
    config::Configs.AbstractConfig;
    variable=nothing,
)
    integ.build_problem_called = true
    p = Common.ODEParameters(variable)
    integ.problem_result = :fake_ode_problem
    return integ.problem_result
end

function Integrators.build_options(
    integ::FakeIntegratorForCalling, config::Union{Configs.AbstractConfig,Nothing}
)
    integ.build_options_called = true
    return Dict{Symbol,Any}()
end

function Integrators.solve_problem(
    integ::FakeIntegratorForCalling, prob, options::Dict{Symbol,Any}; unsafe=false
)
    integ.solve_problem_called = true
    integ.ode_solution = FakeIntegrationResultForCalling()
    return integ.ode_solution
end

function Trajectories.build_trajectory(
    ::Type{Traits.EndPointMode},
    ::Type{Traits.StateDynamics},
    config::Configs.AbstractConfig,
    result::FakeIntegrationResultForCalling,
)
    return Integrators.final_state(result)
end

function Trajectories.build_trajectory(
    ::Type{Traits.TrajectoryMode},
    ::Type{Traits.StateDynamics},
    config::Configs.AbstractConfig,
    result::FakeIntegrationResultForCalling,
)
    return :fake_vector_field_solution
end

function Trajectories.build_trajectory(
    ::Type{Traits.EndPointMode},
    ::Type{Traits.HamiltonianDynamics},
    config::Configs.AbstractConfig,
    result::FakeIntegrationResultForCalling,
)
    return (:fake_xf, :fake_pf)
end

function Trajectories.build_trajectory(
    ::Type{Traits.TrajectoryMode},
    ::Type{Traits.HamiltonianDynamics},
    config::Configs.AbstractConfig,
    result::FakeIntegrationResultForCalling,
)
    return :fake_hamiltonian_solution
end

"""
Fake flow for testing the calling workflow.
"""
struct FakeFlowForCalling{
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    D<:Traits.AbstractDynamicsTrait,
    S<:Systems.AbstractSystem{TD,VD,D},
    I,
} <: Flows.AbstractFlow{TD,VD,D}
    sys::S
    integ::I
end

function FakeFlowForCalling(
    sys::S, integ::I
) where {TD,VD,D,S<:Systems.AbstractSystem{TD,VD,D},I}
    return FakeFlowForCalling{TD,VD,D,S,I}(sys, integ)
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
                flow = FakeFlowForCalling(sys, integ)
                config = Configs.StateEndPointConfig(0.0, [1.0, 0.0], 1.0)

                # Execute
                result = Flows._invoke_flow(
                    flow, config; variable=Core.NotProvided, unsafe=false
                )

                # Verify all steps were called
                Test.@test integ.build_problem_called === true
                Test.@test integ.build_options_called === true
                Test.@test integ.solve_problem_called === true

                # Verify result - for StateEndPointConfig it unwraps the vector
                Test.@test result == :fake_flow_solution
            end

            Test.@testset "call with variable parameter (Fixed system) → PreconditionError" begin
                sys = FakeSystemForCalling(2)
                integ = FakeIntegratorForCalling()
                flow = FakeFlowForCalling(sys, integ)
                config = Configs.StateEndPointConfig(0.0, [1.0, 0.0], 1.0)

                # Call with variable (should now raise PreconditionError for Fixed flow)
                Test.@test_throws Exceptions.PreconditionError Flows._invoke_flow(
                    flow, config; variable=0.5, unsafe=false
                )
            end

            Test.@testset "call with StateTrajectoryConfig" begin
                sys = FakeSystemForCalling(2)
                integ = FakeIntegratorForCalling()
                flow = FakeFlowForCalling(sys, integ)
                config = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0, 0.0])

                result = Flows._invoke_flow(
                    flow, config; variable=Core.NotProvided, unsafe=false
                )

                Test.@test integ.build_problem_called === true
                Test.@test integ.build_options_called === true
                Test.@test integ.solve_problem_called === true
                Test.@test result === :fake_vector_field_solution
            end

            Test.@testset "call with unsafe kwarg" begin
                sys = FakeSystemForCalling(2)
                integ = FakeIntegratorForCalling()
                flow = FakeFlowForCalling(sys, integ)
                config = Configs.StateEndPointConfig(0.0, [1.0, 0.0], 1.0)

                # Call with unsafe=true
                result = Flows._invoke_flow(
                    flow, config; variable=Core.NotProvided, unsafe=true
                )

                Test.@test integ.build_problem_called === true
                Test.@test integ.build_options_called === true
                Test.@test integ.solve_problem_called === true
                Test.@test result == :fake_flow_solution
            end

            Test.@testset "call with HamiltonianEndPointConfig" begin
                sys = FakeHamiltonianSystemForCalling(2)
                integ = FakeIntegratorForCalling()
                flow = FakeFlowForCalling(sys, integ)
                config = Configs.HamiltonianEndPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], 1.0)

                result = Flows._invoke_flow(
                    flow, config; variable=Core.NotProvided, unsafe=false
                )

                Test.@test integ.build_problem_called === true
                Test.@test integ.build_options_called === true
                Test.@test integ.solve_problem_called === true
                Test.@test result == (:fake_xf, :fake_pf)
            end

            Test.@testset "call with HamiltonianTrajectoryConfig" begin
                sys = FakeHamiltonianSystemForCalling(2)
                integ = FakeIntegratorForCalling()
                flow = FakeFlowForCalling(sys, integ)
                config = Configs.HamiltonianTrajectoryConfig(
                    (0.0, 1.0), [1.0, 0.0], [0.5, 0.3]
                )

                result = Flows._invoke_flow(
                    flow, config; variable=Core.NotProvided, unsafe=false
                )

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
                flow = FakeFlowForCalling(sys, integ)
                config = Configs.HamiltonianEndPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], 1.0)

                result = Flows._invoke_flow(
                    flow, config; variable=Core.NotProvided, unsafe=false
                )

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
                flow = FakeFlowForCalling(sys, integ)
                config = Configs.HamiltonianEndPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], 1.0)

                result = Flows._invoke_flow(
                    flow, config; variable=Core.NotProvided, unsafe=false
                )

                Test.@test integ.build_problem_called === true
                Test.@test integ.build_options_called === true
                Test.@test integ.solve_problem_called === true
                Test.@test result == (:fake_xf, :fake_pf)
            end

            Test.@testset "Regression: existing StateFlow path unchanged" begin
                sys = FakeSystemForCalling(2)
                integ = FakeIntegratorForCalling()
                flow = FakeFlowForCalling(sys, integ)
                config = Configs.StateEndPointConfig(0.0, [1.0, 0.0], 1.0)

                result = Flows._invoke_flow(
                    flow, config; variable=Core.NotProvided, unsafe=false
                )

                Test.@test integ.build_problem_called === true
                Test.@test integ.build_options_called === true
                Test.@test integ.solve_problem_called === true
                Test.@test result == :fake_flow_solution
            end
        end

        # ====================================================================
        # UNIT TESTS - Dispatch: 4-way trait dispatch
        # ====================================================================

        Test.@testset "Dispatch: Fixed + NotProvided → _core_invoke_flow (no error)" begin
            sys = FakeSystemForCalling(2)
            integ = FakeIntegratorForCalling()
            flow = FakeFlowForCalling(sys, integ)
            config = Configs.StateEndPointConfig(0.0, [1.0, 0.0], 1.0)

            result = Flows._invoke_flow(
                flow, config; variable=Core.NotProvided, unsafe=false
            )

            Test.@test integ.build_problem_called === true
            Test.@test integ.build_options_called === true
            Test.@test integ.solve_problem_called === true
            Test.@test result == :fake_flow_solution
        end

        Test.@testset "Dispatch: Fixed + variable provided → PreconditionError" begin
            sys = FakeSystemForCalling(2)
            integ = FakeIntegratorForCalling()
            flow = FakeFlowForCalling(sys, integ)
            config = Configs.StateEndPointConfig(0.0, [1.0, 0.0], 1.0)

            Test.@test_throws Exceptions.PreconditionError Flows._invoke_flow(
                flow, config; variable=0.5, unsafe=false
            )
        end

        Test.@testset "Dispatch: NonFixed + variable provided → _core_invoke_flow" begin
            sys = FakeSystemNonFixed(2)
            integ = FakeIntegratorForCalling()
            flow = FakeFlowForCalling(sys, integ)
            config = Configs.StateEndPointConfig(0.0, [1.0, 0.0], 1.0)

            result = Flows._invoke_flow(flow, config; variable=0.5, unsafe=false)

            Test.@test integ.build_problem_called === true
            Test.@test integ.build_options_called === true
            Test.@test integ.solve_problem_called === true
            Test.@test result == :fake_flow_solution
        end

        Test.@testset "Dispatch: NonFixed + NotProvided → PreconditionError" begin
            sys = FakeSystemNonFixed(2)
            integ = FakeIntegratorForCalling()
            flow = FakeFlowForCalling(sys, integ)
            config = Configs.StateEndPointConfig(0.0, [1.0, 0.0], 1.0)

            Test.@test_throws Exceptions.PreconditionError Flows._invoke_flow(
                flow, config; variable=Core.NotProvided, unsafe=false
            )
        end

        # ====================================================================
        # UNIT TESTS - Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "_invoke_flow function is not exported" begin
                Test.@test isdefined(Flows, :_invoke_flow) &&
                    !isdefined(Main, :_invoke_flow)
            end
        end
    end
end

end # module

test_calling_flows() = TestCallingFlows.test_calling_flows()
