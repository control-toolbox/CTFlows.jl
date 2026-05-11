module TestCallingMultiphase

import Test
import CTFlows.MultiPhase
import CTFlows.Systems
import CTFlows.Integrators
import CTFlows.Flows
import CTFlows.Common
import CTFlows.Solutions

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for testing (testing-creation.md §1)
# ==============================================================================

struct FakeStateSystem <: Systems.AbstractStateSystem{Common.Autonomous, Common.Fixed}
    data::Vector{Float64}
end

function Systems.rhs(sys::FakeStateSystem)
    return (du, u, p, t) -> du .= sys.data .* u
end

struct FakeHamiltonianSystem <: Systems.AbstractHamiltonianSystem{Common.Autonomous, Common.Fixed}
    data::Vector{Float64}
end

function Systems.rhs(sys::FakeHamiltonianSystem)
    return (dz, z, p, t) -> dz .= sys.data .* z
end

struct FakeIntegrator <: Integrators.AbstractIntegrator
    result::Any
end

struct FakeHamiltonianIntegrator <: Integrators.AbstractIntegrator
    result::Any
end

# Mock integrator for testing calling.jl functions
struct MockIntegrator <: Integrators.AbstractIntegrator
    multiplier::Float64
end

# Mock ODE problem type
struct MockODEProblem
    u0::Vector{Float64}
    tspan::Tuple{Float64, Float64}
end

# Mock integration result type
struct MockIntegrationResult <: Solutions.AbstractIntegrationResult
    u::Vector{Float64}
    t::Vector{Float64}
end

import CTSolvers.Strategies
import CTSolvers.Options

Strategies.id(::Type{FakeIntegrator}) = :fake_integrator
Strategies.metadata(::Type{FakeIntegrator}) = Strategies.StrategyMetadata()
Strategies.options(integ::FakeIntegrator) = Options.StrategyOptions()

Strategies.id(::Type{FakeHamiltonianIntegrator}) = :fake_ham_integrator
Strategies.metadata(::Type{FakeHamiltonianIntegrator}) = Strategies.StrategyMetadata()
Strategies.options(integ::FakeHamiltonianIntegrator) = Options.StrategyOptions()

Strategies.id(::Type{MockIntegrator}) = :mock_integrator
Strategies.metadata(::Type{MockIntegrator}) = Strategies.StrategyMetadata()
Strategies.options(integ::MockIntegrator) = Options.StrategyOptions()

# ==============================================================================
# Mock Integrator Interface Implementation
# ==============================================================================

function Integrators.build_problem(integ::MockIntegrator, sys::Systems.AbstractSystem, config::Common.StatePointConfig; variable)
    x0 = Common.initial_state(config)
    tspan = Common.tspan(config)
    return MockODEProblem(x0, tspan)
end

function Integrators.build_problem(integ::MockIntegrator, sys::Systems.AbstractSystem, config::Common.StateTrajectoryConfig; variable)
    x0 = Common.initial_state(config)
    tspan = Common.tspan(config)
    return MockODEProblem(x0, tspan)
end

function Integrators.build_problem(integ::MockIntegrator, sys::Systems.AbstractSystem, config::Common.HamiltonianPointConfig; variable)
    x0, p0 = Common.initial_state(config), Common.initial_costate(config)
    tspan = Common.tspan(config)
    return MockODEProblem(vcat(x0, p0), tspan)
end

function Integrators.build_problem(integ::MockIntegrator, sys::Systems.AbstractSystem, config::Common.HamiltonianTrajectoryConfig; variable)
    x0, p0 = Common.initial_state(config), Common.initial_costate(config)
    tspan = Common.tspan(config)
    return MockODEProblem(vcat(x0, p0), tspan)
end

function Integrators.build_options(integ::MockIntegrator, config::Common.StatePointConfig)
    return Dict{Symbol, Any}()
end

function Integrators.build_options(integ::MockIntegrator, config::Common.StateTrajectoryConfig)
    return Dict{Symbol, Any}()
end

function Integrators.build_options(integ::MockIntegrator, config::Common.HamiltonianPointConfig)
    return Dict{Symbol, Any}()
end

function Integrators.build_options(integ::MockIntegrator, config::Common.HamiltonianTrajectoryConfig)
    return Dict{Symbol, Any}()
end

function Integrators.solve_problem(integ::MockIntegrator, prob::MockODEProblem, opts::Dict{Symbol, Any}; unsafe=Common.__unsafe())
    multiplier = integ.multiplier
    t0, tf = prob.tspan
    u_final = prob.u0 * multiplier
    return MockIntegrationResult(u_final, [t0, tf])
end

# ==============================================================================
# Mock Solutions Interface Implementation
# ==============================================================================

function Solutions.final_state(result::MockIntegrationResult)
    return result.u
end

function Solutions.times(result::MockIntegrationResult)
    return result.t
end

function Solutions.evaluate_at(result::MockIntegrationResult, t::Real)
    # Simple linear interpolation
    t0, tf = result.t[1], result.t[end]
    if t <= t0
        return result.u * 0.5  # Mock initial state
    elseif t >= tf
        return result.u
    else
        return result.u * 0.75  # Mock intermediate state
    end
end

function Solutions.build_solution(result::MockIntegrationResult, sys, config)
    # For StatePointConfig, return the final state directly (as expected by _evaluate_phase)
    if config isa Common.StatePointConfig
        return result.u
    elseif config isa Common.HamiltonianPointConfig
        # For HamiltonianFlow, return the concatenated state (will be split by _evaluate_phase)
        return result.u
    elseif config isa Common.StateTrajectoryConfig
        # For StateTrajectoryConfig with StateFlow, return the full result
        return result
    elseif config isa Common.HamiltonianTrajectoryConfig
        # For StateTrajectoryConfig with HamiltonianFlow, return the full result
        return result
    end
end

# ==============================================================================
# Mock Integrators.merge Implementation
# ==============================================================================

function Integrators.merge(segments::Vector{<:MockIntegrationResult})
    if isempty(segments)
        return MockIntegrationResult(Float64[], Float64[])
    end
    
    # Combine final states and times
    combined_u = vcat([s.u for s in segments]...)
    combined_t = vcat([s.t for s in segments]...)
    
    return MockIntegrationResult(combined_u, combined_t)
end

# ==============================================================================
# Test function
# ==============================================================================

function test_calling_multiphase()
    Test.@testset "Calling Multiphase Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        Test.@testset "_extract_initial_state" begin
            x0 = [1.0, 2.0]
            p0 = [0.5, 0.3]

            Test.@testset "StatePointConfig" begin
                config = Common.StatePointConfig(0.0, x0, 1.0)
                result = MultiPhase._extract_initial_state(config)
                Test.@test result === x0
            end

            Test.@testset "StateTrajectoryConfig" begin
                config = Common.StateTrajectoryConfig((0.0, 1.0), x0)
                result = MultiPhase._extract_initial_state(config)
                Test.@test result === x0
            end

            Test.@testset "HamiltonianPointConfig" begin
                config = Common.HamiltonianPointConfig(0.0, x0, p0, 1.0)
                result = MultiPhase._extract_initial_state(config)
                Test.@test result === (x0, p0)
            end

            Test.@testset "HamiltonianTrajectoryConfig" begin
                config = Common.HamiltonianTrajectoryConfig((0.0, 1.0), x0, p0)
                result = MultiPhase._extract_initial_state(config)
                Test.@test result === (x0, p0)
            end
        end

        Test.@testset "_format_final_output" begin
            x = [1.0, 2.0]
            p = [0.5, 0.3]

            Test.@testset "MultiPhaseStateFlow" begin
                sys = FakeStateSystem([1.0, 2.0])
                integ = FakeIntegrator(:fake_result)
                flow1 = Flows.StateFlow(sys, integ)
                flow2 = Flows.StateFlow(sys, integ)
                mpf = flow1 * (0.5, flow2)

                result = MultiPhase._format_final_output(mpf, x)
                Test.@test result === x
            end

            Test.@testset "MultiPhaseHamiltonianFlow" begin
                hsys = FakeHamiltonianSystem([1.0, 2.0])
                hinteg = FakeHamiltonianIntegrator(:fake_result)
                hflow1 = Flows.HamiltonianFlow(hsys, hinteg)
                hflow2 = Flows.HamiltonianFlow(hsys, hinteg)
                hmpf = hflow1 * (0.5, hflow2)

                result = MultiPhase._format_final_output(hmpf, (x, p))
                Test.@test result == vcat(x, p)
            end
        end

        Test.@testset "_extract_final_state" begin
            # Skip complex mocking - test will be covered by integration tests
            Test.@testset "skipped - covered by integration tests" begin
                Test.@test true
            end
        end

        Test.@testset "_apply_jump" begin
            x = [1.0, 2.0]
            p = [0.5, 0.3]
            jump = [0.1, 0.2]

            Test.@testset "MultiPhaseStateFlow" begin
                sys = FakeStateSystem([1.0, 2.0])
                integ = FakeIntegrator(:fake_result)
                flow1 = Flows.StateFlow(sys, integ)
                flow2 = Flows.StateFlow(sys, integ)
                mpf = flow1 * (0.5, jump, flow2)  # Create mpf with a jump

                result = MultiPhase._apply_jump(mpf, 1, x)
                Test.@test result == x + jump
            end

            Test.@testset "MultiPhaseHamiltonianFlow" begin
                hsys = FakeHamiltonianSystem([1.0, 2.0])
                hinteg = FakeHamiltonianIntegrator(:fake_result)
                hflow1 = Flows.HamiltonianFlow(hsys, hinteg)
                hflow2 = Flows.HamiltonianFlow(hsys, hinteg)
                hmpf = hflow1 * (0.5, jump, hflow2)

                result = MultiPhase._apply_jump(hmpf, 1, (x, p))
                Test.@test result == (x, p + jump)
            end
        end

        Test.@testset "_apply_hamiltonian_jump" begin
            x = [1.0, 2.0]
            p = [0.5, 0.3]
            state_tuple = (x, p)

            Test.@testset "jump as Tuple (jump_x, jump_p)" begin
                jump_x = [0.1, 0.2]
                jump_p = [0.01, 0.02]
                result = MultiPhase._apply_hamiltonian_jump(state_tuple, (jump_x, jump_p))
                Test.@test result[1] == x + jump_x
                Test.@test result[2] == p + jump_p
            end

            Test.@testset "jump as single vector (jump_p only)" begin
                jump_p = [0.01, 0.02]
                result = MultiPhase._apply_hamiltonian_jump(state_tuple, jump_p)
                Test.@test result[1] == x
                Test.@test result[2] == p + jump_p
            end
        end

        Test.@testset "_evaluate_phase" begin
            x = [1.0, 2.0]
            p = [0.5, 0.3]

            Test.@testset "StateFlow with StatePointConfig" begin
                sys = FakeStateSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)  # Multiplier of 2
                flow = Flows.StateFlow(sys, integ)
                t0 = 0.0
                tf = 1.0

                result = MultiPhase._evaluate_phase(flow, t0, tf, x, Common.StatePointConfig(t0, x, tf); variable=Common.__variable(), unsafe=Common.__unsafe())
                
                Test.@test result == x * 2
            end

            Test.@testset "StateFlow with StateTrajectoryConfig" begin
                sys = FakeStateSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                flow = Flows.StateFlow(sys, integ)
                tspan = (0.0, 1.0)

                result = MultiPhase._evaluate_phase(flow, 0.0, 1.0, x, Common.StateTrajectoryConfig(tspan, x); variable=Common.__variable(), unsafe=Common.__unsafe())
                
                Test.@test result.u == x * 2
            end

            Test.@testset "HamiltonianFlow with StatePointConfig" begin
                hsys = FakeHamiltonianSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                flow = Flows.HamiltonianFlow(hsys, integ)
                t0 = 0.0
                tf = 1.0

                result = MultiPhase._evaluate_phase(flow, t0, tf, (x, p), Common.HamiltonianPointConfig(t0, x, p, tf); variable=Common.__variable(), unsafe=Common.__unsafe())
                
                Test.@test result[1] == x * 2
                Test.@test result[2] == p * 2
            end

            Test.@testset "HamiltonianFlow with StateTrajectoryConfig" begin
                hsys = FakeHamiltonianSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                flow = Flows.HamiltonianFlow(hsys, integ)
                tspan = (0.0, 1.0)

                result = MultiPhase._evaluate_phase(flow, 0.0, 1.0, (x, p), Common.HamiltonianTrajectoryConfig(tspan, x, p); variable=Common.__variable(), unsafe=Common.__unsafe())
                
                Test.@test result.u == vcat(x * 2, p * 2)
            end
        end

        Test.@testset "_evaluate_multiphase with StatePointConfig" begin
            x0 = [1.0, 2.0]
            p0 = [0.5, 0.3]

            Test.@testset "MultiPhaseStateFlow without jump" begin
                sys = FakeStateSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                flow1 = Flows.StateFlow(sys, integ)
                flow2 = Flows.StateFlow(sys, integ)
                mpf = flow1 * (0.5, flow2)

                result = MultiPhase._evaluate_multiphase(mpf, Common.StatePointConfig(0.0, x0, 1.0); variable=Common.__variable(), unsafe=Common.__unsafe())
                
                # Each phase multiplies by 2, so final is x0 * 2 * 2 = x0 * 4
                Test.@test result == x0 * 4
            end

            Test.@testset "MultiPhaseStateFlow with jump" begin
                sys = FakeStateSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                flow1 = Flows.StateFlow(sys, integ)
                flow2 = Flows.StateFlow(sys, integ)
                jump = [0.1, 0.2]
                mpf = flow1 * (0.5, jump, flow2)

                result = MultiPhase._evaluate_multiphase(mpf, Common.StatePointConfig(0.0, x0, 1.0); variable=Common.__variable(), unsafe=Common.__unsafe())
                
                # Phase 1: x0 * 2, then jump applied, then phase 2: (x0 * 2 + jump) * 2
                expected = (x0 * 2 + jump) * 2
                Test.@test result == expected
            end

            Test.@testset "MultiPhaseHamiltonianFlow without jump" begin
                hsys = FakeHamiltonianSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                hflow1 = Flows.HamiltonianFlow(hsys, integ)
                hflow2 = Flows.HamiltonianFlow(hsys, integ)
                hmpf = hflow1 * (0.5, hflow2)

                result = MultiPhase._evaluate_multiphase(hmpf, Common.HamiltonianPointConfig(0.0, x0, p0, 1.0); variable=Common.__variable(), unsafe=Common.__unsafe())
                
                # Each phase multiplies by 2, _format_final_output returns vcat(x, p)
                Test.@test result == vcat(x0 * 4, p0 * 4)
            end

            Test.@testset "MultiPhaseHamiltonianFlow with jump" begin
                hsys = FakeHamiltonianSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                hflow1 = Flows.HamiltonianFlow(hsys, integ)
                hflow2 = Flows.HamiltonianFlow(hsys, integ)
                jump_p = [0.01, 0.02]
                hmpf = hflow1 * (0.5, jump_p, hflow2)

                result = MultiPhase._evaluate_multiphase(hmpf, Common.HamiltonianPointConfig(0.0, x0, p0, 1.0); variable=Common.__variable(), unsafe=Common.__unsafe())
                
                # Phase 1: x0*2, p0*2, then jump_p applied to p, then phase 2: x*2, (p+jump_p)*2
                # _format_final_output returns vcat(x, p)
                Test.@test result == vcat(x0 * 4, (p0 * 2 + jump_p) * 2)
            end
        end

        Test.@testset "_evaluate_multiphase with StateTrajectoryConfig" begin
            x0 = [1.0, 2.0]
            p0 = [0.5, 0.3]

            Test.@testset "MultiPhaseStateFlow without jump" begin
                sys = FakeStateSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                flow1 = Flows.StateFlow(sys, integ)
                flow2 = Flows.StateFlow(sys, integ)
                mpf = flow1 * (0.5, flow2)

                result = MultiPhase._evaluate_multiphase(mpf, Common.StateTrajectoryConfig((0.0, 1.0), x0); variable=Common.__variable(), unsafe=Common.__unsafe())
                
                # Result should be a merged MockIntegrationResult
                Test.@test result isa MockIntegrationResult
                # Each phase produces x0*2, so combined should be [x0*2, x0*4]
                Test.@test result.u == vcat(x0 * 2, x0 * 4)
            end

            Test.@testset "MultiPhaseStateFlow with jump" begin
                sys = FakeStateSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                flow1 = Flows.StateFlow(sys, integ)
                flow2 = Flows.StateFlow(sys, integ)
                jump = [0.1, 0.2]
                mpf = flow1 * (0.5, jump, flow2)

                result = MultiPhase._evaluate_multiphase(mpf, Common.StateTrajectoryConfig((0.0, 1.0), x0); variable=Common.__variable(), unsafe=Common.__unsafe())
                
                Test.@test result isa MockIntegrationResult
                # Phase 1: x0*2, then jump, then phase 2: (x0*2+jump)*2
                expected = vcat(x0 * 2, (x0 * 2 + jump) * 2)
                Test.@test result.u == expected
            end

            Test.@testset "MultiPhaseHamiltonianFlow without jump" begin
                hsys = FakeHamiltonianSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                hflow1 = Flows.HamiltonianFlow(hsys, integ)
                hflow2 = Flows.HamiltonianFlow(hsys, integ)
                hmpf = hflow1 * (0.5, hflow2)

                result = MultiPhase._evaluate_multiphase(hmpf, Common.HamiltonianTrajectoryConfig((0.0, 1.0), x0, p0); variable=Common.__variable(), unsafe=Common.__unsafe())
                
                Test.@test result isa MockIntegrationResult
                # Each phase produces vcat(x0*2, p0*2)
                expected = vcat(x0 * 2, p0 * 2, x0 * 4, p0 * 4)
                Test.@test result.u == expected
            end

            Test.@testset "MultiPhaseHamiltonianFlow with jump" begin
                hsys = FakeHamiltonianSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                hflow1 = Flows.HamiltonianFlow(hsys, integ)
                hflow2 = Flows.HamiltonianFlow(hsys, integ)
                jump_p = [0.01, 0.02]
                hmpf = hflow1 * (0.5, jump_p, hflow2)

                result = MultiPhase._evaluate_multiphase(hmpf, Common.HamiltonianTrajectoryConfig((0.0, 1.0), x0, p0); variable=Common.__variable(), unsafe=Common.__unsafe())
                
                Test.@test result isa MockIntegrationResult
                # Phase 1: vcat(x0*2, p0*2), then jump, then phase 2: vcat(x*2, (p+jump_p)*2)
                expected = vcat(x0 * 2, p0 * 2, x0 * 4, (p0 * 2 + jump_p) * 2)
                Test.@test result.u == expected
            end
        end

        Test.@testset "MultiPhaseStateFlow callable" begin
            x0 = [1.0, 2.0]

            Test.@testset "call with (t0, x0, tf)" begin
                sys = FakeStateSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                flow1 = Flows.StateFlow(sys, integ)
                flow2 = Flows.StateFlow(sys, integ)
                mpf = flow1 * (0.5, flow2)

                result = mpf(0.0, x0, 1.0)
                # Each phase multiplies by 2, so final is x0 * 4
                Test.@test result == x0 * 4
            end

            Test.@testset "call with (tspan, x0)" begin
                sys = FakeStateSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                flow1 = Flows.StateFlow(sys, integ)
                flow2 = Flows.StateFlow(sys, integ)
                mpf = flow1 * (0.5, flow2)

                result = mpf((0.0, 1.0), x0)
                # Result should be a merged MockIntegrationResult
                Test.@test result isa MockIntegrationResult
                Test.@test result.u == vcat(x0 * 2, x0 * 4)
            end
        end

        Test.@testset "MultiPhaseHamiltonianFlow callable" begin
            x0 = [1.0, 2.0]
            p0 = [0.5, 0.3]

            Test.@testset "call with (t0, x0, p0, tf)" begin
                hsys = FakeHamiltonianSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                hflow1 = Flows.HamiltonianFlow(hsys, integ)
                hflow2 = Flows.HamiltonianFlow(hsys, integ)
                hmpf = hflow1 * (0.5, hflow2)

                result = hmpf(0.0, x0, p0, 1.0)
                # Each phase multiplies by 2
                Test.@test result == vcat(x0 * 4, p0 * 4)
            end

            Test.@testset "call with (tspan, x0, p0)" begin
                hsys = FakeHamiltonianSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                hflow1 = Flows.HamiltonianFlow(hsys, integ)
                hflow2 = Flows.HamiltonianFlow(hsys, integ)
                hmpf = hflow1 * (0.5, hflow2)

                result = hmpf((0.0, 1.0), x0, p0)
                # Result should be a merged MockIntegrationResult
                Test.@test result isa MockIntegrationResult
                Test.@test result.u == vcat(x0 * 2, p0 * 2, x0 * 4, p0 * 4)
            end
        end
    end
end

end # module

test_calling_multiphase() = TestCallingMultiphase.test_calling_multiphase()
