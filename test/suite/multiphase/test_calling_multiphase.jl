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

function test_calling_multiphase()
    Test.@testset "Calling Multiphase Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

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
