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
struct FakeFlow{S} <: Flows.AbstractFlow
    sys::S
    integ::Any
end

"""
Fake system for Fixed systems.
"""
struct FixedSystem end

"""
Fake system for NonFixed systems.
"""
struct NonFixedSystem end

# Trait types for dispatch (matching real Flow pattern)
struct Fixed end
struct NonFixed end

# Attach traits to fake systems
function Systems.variable_dependence(::FixedSystem)
    return Fixed()
end

function Systems.variable_dependence(::NonFixedSystem)
    return NonFixed()
end

function Flows.system(flow::FakeFlow)
    return flow.sys
end

function Flows.integrator(flow::FakeFlow)
    return flow.integ
end

# Config-based callable - Fixed systems (no variable kwarg)
function (flow::FakeFlow{FixedSystem})(config::Common.PointConfig)
    return flow.integ.result
end

# Config-based callable - NonFixed systems (require variable kwarg)
function (flow::FakeFlow{NonFixedSystem})(config::Common.PointConfig; variable)
    return flow.integ.result
end

# Fixed systems - no variable kwarg
function (flow::FakeFlow{FixedSystem})(t0, x0, tf)
    return flow.integ.result
end

function (flow::FakeFlow{FixedSystem})(tspan::Tuple, x0)
    return flow.integ.result
end

# NonFixed systems - require variable kwarg
function (flow::FakeFlow{NonFixedSystem})(t0, x0, tf; variable)
    return flow.integ.result
end

function (flow::FakeFlow{NonFixedSystem})(tspan::Tuple, x0; variable)
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
            sys = FixedSystem()
            integ = FakeIntegrator(:solution)
            flow = FakeFlow{FixedSystem}(sys, integ)

            Test.@testset "call with PointConfig" begin
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                result = flow(config)
                Test.@test result === :solution
            end

            Test.@testset "call with (t0, x0, tf)" begin
                result = flow(0.0, [1.0, 0.0], 1.0)
                Test.@test result === :solution
            end

            Test.@testset "call with (tspan, x0)" begin
                result = flow((0.0, 1.0), [1.0, 0.0])
                Test.@test result === :solution
            end

            Test.@testset "ERROR: call with variable kwarg (not allowed for Fixed)" begin
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                Test.@test_throws MethodError flow(config; variable = 0.5)
            end
        end

        # ====================================================================
        # UNIT TESTS - Flow Callable (NonFixed systems)
        # ====================================================================

        Test.@testset "Flow Callable - NonFixed Systems" begin
            sys = NonFixedSystem()
            integ = FakeIntegrator(:solution)
            flow = FakeFlow{NonFixedSystem}(sys, integ)

            Test.@testset "call with PointConfig and variable" begin
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                result = flow(config; variable = 0.5)
                Test.@test result === :solution
            end

            Test.@testset "call with (t0, x0, tf; variable)" begin
                result = flow(0.0, [1.0, 0.0], 1.0; variable = 0.5)
                Test.@test result === :solution
            end

            Test.@testset "call with (tspan, x0; variable)" begin
                result = flow((0.0, 1.0), [1.0, 0.0]; variable = 0.5)
                Test.@test result === :solution
            end

            Test.@testset "ERROR: call without variable kwarg (required for NonFixed)" begin
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                Test.@test_throws UndefKeywordError flow(config)
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
