module TestFlow

import Test
import CTFlows.Systems
import CTFlows.Flows
import CTFlows.Integrators
import CTFlows.Common

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for testing
# ==============================================================================

"""
Fake integrator for testing Flow.
"""
struct FakeIntegrator
    result::Any
end

"""
Fake flow for testing Flow contract without requiring SciML extension.
"""
struct FakeFlow <: Flows.AbstractFlow
    sys::Any
    integ::Any
end

function Flows.system(flow::FakeFlow)
    return flow.sys
end

function Flows.integrator(flow::FakeFlow)
    return flow.integ
end

function (flow::FakeFlow)(config::Common.PointConfig; variable=nothing)
    return flow.integ.result
end

# ==============================================================================
# Test function
# ==============================================================================

function test_flow()
    Test.@testset "Flow Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Flow Construction
        # ====================================================================

        Test.@testset "Flow Construction" begin
            sys = :fake_system
            integ = FakeIntegrator(:fake_ode_sol)
            flow = FakeFlow(sys, integ)

            Test.@testset "Flow is AbstractFlow" begin
                Test.@test flow isa Flows.AbstractFlow
            end

            Test.@testset "Flow stores system" begin
                Test.@test Flows.system(flow) === sys
            end

            Test.@testset "Flow stores integrator" begin
                Test.@test Flows.integrator(flow) === integ
            end
        end

        # ====================================================================
        # UNIT TESTS - Flow Callable (Fixed systems)
        # ====================================================================

        Test.@testset "Flow Callable - Fixed Systems" begin
            sys = :fake_system
            integ = FakeIntegrator(:solution)
            flow = FakeFlow(sys, integ)

            Test.@testset "call with PointConfig" begin
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                result = flow(config)
                Test.@test result === :solution
            end
        end

        # ====================================================================
        # UNIT TESTS - Flow Callable (NonFixed systems)
        # ====================================================================

        Test.@testset "Flow Callable - NonFixed Systems" begin
            sys = :fake_system
            integ = FakeIntegrator(:solution)
            flow = FakeFlow(sys, integ)

            Test.@testset "call with PointConfig and variable" begin
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                result = flow(config; variable = 0.5)
                Test.@test result === :solution
            end
        end

        # ====================================================================
        # UNIT TESTS - Base.show
        # ====================================================================

        Test.@testset "Base.show" begin
            sys = :fake_system
            integ = FakeIntegrator(:fake_ode_sol)
            flow = FakeFlow(sys, integ)

            Test.@testset "MIME text/plain" begin
                io = IOBuffer()
                show(io, MIME("text/plain"), flow)
                output = String(take!(io))
                Test.@test occursin("Flow", output)
                Test.@test occursin("system", output)
                Test.@test occursin("integrator", output)
            end

            Test.@testset "compact" begin
                io = IOBuffer()
                show(io, flow)
                output = String(take!(io))
                Test.@test occursin("Flow", output)
                Test.@test occursin("system", output)
                Test.@test occursin("integrator", output)
            end
        end
    end
end

end # module

test_flow() = TestFlow.test_flow()
