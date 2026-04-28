module TestFlow

import Test
import CTFlows.Systems
import CTFlows.Flows

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Fake types for testing
# ==============================================================================

"""
Fake system for testing.
"""
struct FakeSystem <: Systems.AbstractSystem
    state_dim::Int
end

function Systems.rhs!(sys::FakeSystem)
    return (du, u, p, t) -> nothing
end

function Systems.dimensions(sys::FakeSystem)
    return (n_x=sys.state_dim, n_p=sys.state_dim, n_u=0, n_v=0)
end

function Systems.build_solution(sys::FakeSystem, ode_sol)
    return ode_sol
end

"""
Fake integrator for testing Flow.
"""
struct FakeIntegrator
    result::Any
end

function (integ::FakeIntegrator)(ode_problem, tspan)
    return integ.result
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
            sys = FakeSystem(2)
            integ = FakeIntegrator(:fake_ode_sol)
            flow = Flows.Flow(sys, integ)

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
        # UNIT TESTS - Base.show
        # ====================================================================

        Test.@testset "Base.show" begin
            sys = FakeSystem(2)
            integ = FakeIntegrator(:fake_ode_sol)
            flow = Flows.Flow(sys, integ)

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
