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

Matches the new parametric Flow{TD, VD, S, I} structure.
"""
struct FakeFlow{TD<:Common.TimeDependence, VD<:Common.VariableDependence, S<:Systems.AbstractSystem{TD, VD}, I} <: Flows.AbstractFlow{TD, VD}
    sys::S
    integ::I
end

"""
Fake system for Fixed systems.
"""
struct FixedSystem <: Systems.AbstractSystem{Common.Autonomous, Common.Fixed} end

"""
Fake system for NonFixed systems.
"""
struct NonFixedSystem <: Systems.AbstractSystem{Common.Autonomous, Common.NonFixed} end

function Flows.system(flow::FakeFlow)
    return flow.sys
end

function Flows.integrator(flow::FakeFlow)
    return flow.integ
end

# Config-based callable - both Fixed and NonFixed require variable, unsafe
function (flow::FakeFlow)(config::Common.PointConfig; variable, unsafe)
    return flow.integ.result
end

function (flow::FakeFlow)(config::Common.TrajectoryConfig; variable, unsafe)
    return flow.integ.result
end

# Positional callable - both Fixed and NonFixed require variable, unsafe
function (flow::FakeFlow)(t0, x0, tf; variable, unsafe)
    return flow.integ.result
end

function (flow::FakeFlow)(tspan::Tuple, x0; variable, unsafe)
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
            Test.@testset "Fixed Flow" begin
                sys = FixedSystem()
                integ = FakeIntegrator(:fake_ode_sol)
                flow = FakeFlow{Common.Autonomous, Common.Fixed, FixedSystem, typeof(integ)}(sys, integ)

                Test.@testset "Flow is AbstractFlow{Autonomous, Fixed}" begin
                    Test.@test flow isa Flows.AbstractFlow{Common.Autonomous, Common.Fixed}
                end

                Test.@testset "Flow stores system" begin
                    Test.@test Flows.system(flow) === sys
                end

                Test.@testset "Flow stores integrator" begin
                    Test.@test Flows.integrator(flow) === integ
                end
            end

            Test.@testset "NonFixed Flow" begin
                sys = NonFixedSystem()
                integ = FakeIntegrator(:fake_ode_sol)
                flow = FakeFlow{Common.Autonomous, Common.NonFixed, NonFixedSystem, typeof(integ)}(sys, integ)

                Test.@testset "Flow is AbstractFlow{Autonomous, NonFixed}" begin
                    Test.@test flow isa Flows.AbstractFlow{Common.Autonomous, Common.NonFixed}
                end

                Test.@testset "Flow stores system" begin
                    Test.@test Flows.system(flow) === sys
                end

                Test.@testset "Flow stores integrator" begin
                    Test.@test Flows.integrator(flow) === integ
                end
            end
        end

        # ====================================================================
        # UNIT TESTS - Flow Callable (Fixed systems)
        # ====================================================================

        Test.@testset "Flow Callable - Fixed Systems" begin
            sys = FixedSystem()
            integ = FakeIntegrator(:solution)
            flow = FakeFlow{Common.Autonomous, Common.Fixed, FixedSystem, typeof(integ)}(sys, integ)

            Test.@testset "call with PointConfig" begin
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                result = flow(config; variable=nothing, unsafe=false)
                Test.@test result === :solution
            end

            Test.@testset "call with PointConfig and variable (ignored for Fixed)" begin
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                result = flow(config; variable=0.5, unsafe=false)
                Test.@test result === :solution
            end

            Test.@testset "call with (t0, x0, tf)" begin
                result = flow(0.0, [1.0, 0.0], 1.0; variable=nothing, unsafe=false)
                Test.@test result === :solution
            end

            Test.@testset "call with (t0, x0, tf; variable) (ignored for Fixed)" begin
                result = flow(0.0, [1.0, 0.0], 1.0; variable=0.5, unsafe=false)
                Test.@test result === :solution
            end

            Test.@testset "call with (tspan, x0)" begin
                result = flow((0.0, 1.0), [1.0, 0.0]; variable=nothing, unsafe=false)
                Test.@test result === :solution
            end

            Test.@testset "call with (tspan, x0; variable) (ignored for Fixed)" begin
                result = flow((0.0, 1.0), [1.0, 0.0]; variable=0.5, unsafe=false)
                Test.@test result === :solution
            end

            Test.@testset "call with unsafe kwarg" begin
                result = flow(0.0, [1.0, 0.0], 1.0; variable=nothing, unsafe=true)
                Test.@test result === :solution
            end
        end

        # ====================================================================
        # UNIT TESTS - Flow Callable (NonFixed systems)
        # ====================================================================

        Test.@testset "Flow Callable - NonFixed Systems" begin
            sys = NonFixedSystem()
            integ = FakeIntegrator(:solution)
            flow = FakeFlow{Common.Autonomous, Common.NonFixed, NonFixedSystem, typeof(integ)}(sys, integ)

            Test.@testset "call with PointConfig" begin
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                result = flow(config; variable=nothing, unsafe=false)
                Test.@test result === :solution
            end

            Test.@testset "call with PointConfig and variable" begin
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                result = flow(config; variable=0.5, unsafe=false)
                Test.@test result === :solution
            end

            Test.@testset "call with (t0, x0, tf)" begin
                result = flow(0.0, [1.0, 0.0], 1.0; variable=nothing, unsafe=false)
                Test.@test result === :solution
            end

            Test.@testset "call with (t0, x0, tf; variable)" begin
                result = flow(0.0, [1.0, 0.0], 1.0; variable=0.5, unsafe=false)
                Test.@test result === :solution
            end

            Test.@testset "call with (tspan, x0)" begin
                result = flow((0.0, 1.0), [1.0, 0.0]; variable=nothing, unsafe=false)
                Test.@test result === :solution
            end

            Test.@testset "call with (tspan, x0; variable)" begin
                result = flow((0.0, 1.0), [1.0, 0.0]; variable=0.5, unsafe=false)
                Test.@test result === :solution
            end

            Test.@testset "call with unsafe kwarg" begin
                result = flow(0.0, [1.0, 0.0], 1.0; variable=nothing, unsafe=true)
                Test.@test result === :solution
            end
        end

        # ====================================================================
        # UNIT TESTS - Trait Delegation
        # ====================================================================

        Test.@testset "Trait Delegation" begin
            Test.@testset "Fixed Flow traits" begin
                sys = FixedSystem()
                integ = FakeIntegrator(:solution)
                flow = FakeFlow{Common.Autonomous, Common.Fixed, FixedSystem, typeof(integ)}(sys, integ)

                Test.@testset "variable_dependence delegates to system" begin
                    Test.@test Common.variable_dependence(flow) === Common.Fixed
                end

                Test.@testset "time_dependence delegates to system" begin
                    Test.@test Common.time_dependence(flow) === Common.Autonomous
                end
            end

            Test.@testset "NonFixed Flow traits" begin
                sys = NonFixedSystem()
                integ = FakeIntegrator(:solution)
                flow = FakeFlow{Common.Autonomous, Common.NonFixed, NonFixedSystem, typeof(integ)}(sys, integ)

                Test.@testset "variable_dependence delegates to system" begin
                    Test.@test Common.variable_dependence(flow) === Common.NonFixed
                end

                Test.@testset "time_dependence delegates to system" begin
                    Test.@test Common.time_dependence(flow) === Common.Autonomous
                end
            end
        end

        # ====================================================================
        # UNIT TESTS - Base.show
        # ====================================================================

        Test.@testset "Base.show" begin
            sys = FixedSystem()
            integ = FakeIntegrator(:fake_ode_sol)
            flow = FakeFlow{Common.Autonomous, Common.Fixed, FixedSystem, typeof(integ)}(sys, integ)

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
