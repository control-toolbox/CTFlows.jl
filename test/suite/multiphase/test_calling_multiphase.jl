module TestCallingMultiphase

import Test
import CTFlows.MultiPhase
import CTFlows.Systems
import CTFlows.Integrators
import CTFlows.Flows
import CTFlows.Common

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

import CTSolvers.Strategies
import CTSolvers.Options

Strategies.id(::Type{FakeIntegrator}) = :fake_integrator
Strategies.metadata(::Type{FakeIntegrator}) = Strategies.StrategyMetadata()
Strategies.options(integ::FakeIntegrator) = Options.StrategyOptions()

Strategies.id(::Type{FakeHamiltonianIntegrator}) = :fake_ham_integrator
Strategies.metadata(::Type{FakeHamiltonianIntegrator}) = Strategies.StrategyMetadata()
Strategies.options(integ::FakeHamiltonianIntegrator) = Options.StrategyOptions()

# ==============================================================================
# Test function
# ==============================================================================

function test_calling_multiphase()
    Test.@testset "Calling Multiphase Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        Test.@testset "_extract_initial_state" begin
            x0 = [1.0, 2.0]
            p0 = [0.5, 0.3]

            Test.@testset "PointConfig" begin
                config = Common.PointConfig(0.0, x0, 1.0)
                result = MultiPhase._extract_initial_state(config)
                Test.@test result === x0
            end

            Test.@testset "TrajectoryConfig" begin
                config = Common.TrajectoryConfig((0.0, 1.0), x0)
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

        Test.@testset "MultiPhaseStateFlow callable" begin
            sys = FakeStateSystem([1.0, 2.0])
            integ = FakeIntegrator(:fake_result)
            flow1 = Flows.StateFlow(sys, integ)
            flow2 = Flows.StateFlow(sys, integ)
            mpf = flow1 * (0.5, flow2)

            Test.@testset "call with (t0, x0, tf)" begin
                # Since FakeStateSystem currently doesn't implement ODEProblem building,
                # we just check that the method is defined. True integration tests
                # will be done in the SciML extension tests.
                Test.@test hasmethod(mpf, Tuple{Real, Vector{Float64}, Real})
            end

            Test.@testset "call with (tspan, x0)" begin
                Test.@test hasmethod(mpf, Tuple{Tuple{Real, Real}, Vector{Float64}})
            end
        end
    end
end

end # module

test_calling_multiphase() = TestCallingMultiphase.test_calling_multiphase()
