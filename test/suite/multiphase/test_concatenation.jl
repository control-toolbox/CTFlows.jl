module TestConcatenation

import Test
import CTFlows.MultiPhase
import CTFlows.Systems
import CTFlows.Integrators
import CTFlows.Flows
import CTFlows.Common

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for testing
# ==============================================================================

struct FakeStateSystem <: Systems.AbstractStateSystem{Common.Autonomous, Common.Fixed}
    data::Vector{Float64}
end

function Systems.rhs(sys::FakeStateSystem)
    return (du, u, p, t) -> du .= sys.data .* u
end

struct FakeIntegrator <: Integrators.AbstractIntegrator
    result::Any
end

import CTSolvers.Strategies
import CTSolvers.Options

Strategies.id(::Type{FakeIntegrator}) = :fake_integrator
Strategies.metadata(::Type{FakeIntegrator}) = Strategies.StrategyMetadata()
Strategies.options(integ::FakeIntegrator) = Options.StrategyOptions()

# ==============================================================================
# Test function
# ==============================================================================

function test_concatenation()
    Test.@testset "Concatenation Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        Test.@testset "StateFlow concatenation" begin
            sys = FakeStateSystem([1.0, 2.0])
            integ = FakeIntegrator(:fake_result)
            flow1 = Flows.StateFlow(sys, integ)
            flow2 = Flows.StateFlow(sys, integ)

            Test.@testset "StateFlow * (t_switch, StateFlow)" begin
                mpf = flow1 * (0.5, flow2)
                Test.@test mpf isa MultiPhase.MultiPhaseStateFlow
                Test.@test length(mpf.flows) == 2
                Test.@test mpf.switching_times == [0.5]
                Test.@test mpf.jumps == [nothing]
            end

            Test.@testset "StateFlow * (t_switch, jump, StateFlow)" begin
                mpf = flow1 * (0.5, [1.0, 0.0], flow2)
                Test.@test mpf isa MultiPhase.MultiPhaseStateFlow
                Test.@test length(mpf.flows) == 2
                Test.@test mpf.switching_times == [0.5]
                Test.@test mpf.jumps == [[1.0, 0.0]]
            end
        end

        Test.@testset "MultiPhaseStateFlow concatenation" begin
            sys = FakeStateSystem([1.0, 2.0])
            integ = FakeIntegrator(:fake_result)
            flow1 = Flows.StateFlow(sys, integ)
            flow2 = Flows.StateFlow(sys, integ)
            flow3 = Flows.StateFlow(sys, integ)

            mpf1 = flow1 * (0.5, flow2)
            mpf2 = mpf1 * (1.0, flow3)

            Test.@testset "chaining" begin
                Test.@test mpf2 isa MultiPhase.MultiPhaseStateFlow
                Test.@test length(mpf2.flows) == 3
                Test.@test mpf2.switching_times == [0.5, 1.0]
            end
        end
    end
end

end # module

test_concatenation() = TestConcatenation.test_concatenation()
