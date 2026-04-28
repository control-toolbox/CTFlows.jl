module TestAbstractFlow

import Test
import CTBase.Exceptions
import CTFlows.Systems
import CTFlows.Flows

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Fake types for contract testing
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
Fake flow for testing the AbstractFlow contract.

This minimal implementation provides the required contract methods to test
routing and default behavior without full flow complexity.
"""
struct FakeFlow <: Flows.AbstractFlow
    sys::Systems.AbstractSystem
    integ::Any
end

function Flows.system(f::FakeFlow)
    return f.sys
end

function Flows.integrator(f::FakeFlow)
    return f.integ
end

function (f::FakeFlow)(t0, x0, tf)
    return :fake_trajectory
end

function (f::FakeFlow)(t0, x0, p0, tf)
    return :fake_trajectory_with_costate
end

"""
Minimal flow that does not implement the contract (for error testing).
"""
struct MinimalFlow <: Flows.AbstractFlow
    sys::Systems.AbstractSystem
end

# ==============================================================================
# Test function
# ==============================================================================

function test_abstract_flow()
    Test.@testset "Abstract Flow Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            sys = FakeSystem(2)
            Test.@test FakeFlow(sys, :fake_integ) isa Flows.AbstractFlow
            Test.@test MinimalFlow(sys) isa Flows.AbstractFlow
        end

        # ====================================================================
        # UNIT TESTS - Contract Implementation
        # ====================================================================

        Test.@testset "Contract Implementation" begin
            sys = FakeSystem(2)
            flow = FakeFlow(sys, :fake_integ)

            Test.@testset "system returns system" begin
                Test.@test Flows.system(flow) === sys
            end

            Test.@testset "integrator returns integrator" begin
                Test.@test Flows.integrator(flow) === :fake_integ
            end

            Test.@testset "callable (t0, x0, tf)" begin
                result = flow(0.0, [1.0, 0.0], 1.0)
                Test.@test result === :fake_trajectory
            end

            Test.@testset "callable (t0, x0, p0, tf)" begin
                result = flow(0.0, [1.0, 0.0], [0.0, 0.0], 1.0)
                Test.@test result === :fake_trajectory_with_costate
            end
        end

        # ====================================================================
        # UNIT TESTS - NotImplemented Errors
        # ====================================================================

        Test.@testset "NotImplemented Errors" begin
            sys = FakeSystem(2)
            flow = MinimalFlow(sys)

            Test.@testset "system throws NotImplemented" begin
                Test.@test_throws Exceptions.NotImplemented Flows.system(flow)
            end

            Test.@testset "integrator throws NotImplemented" begin
                Test.@test_throws Exceptions.NotImplemented Flows.integrator(flow)
            end

            Test.@testset "callable (t0, x0, tf) throws NotImplemented" begin
                Test.@test_throws Exceptions.NotImplemented flow(0.0, [1.0, 0.0], 1.0)
            end

            Test.@testset "callable (t0, x0, p0, tf) throws NotImplemented" begin
                Test.@test_throws Exceptions.NotImplemented flow(0.0, [1.0, 0.0], [0.0, 0.0], 1.0)
            end
        end

        # ====================================================================
        # UNIT TESTS - Base.show
        # ====================================================================

        Test.@testset "Base.show" begin
            sys = FakeSystem(2)
            flow = FakeFlow(sys, :fake_integ)

            Test.@testset "MIME text/plain" begin
                io = IOBuffer()
                show(io, MIME("text/plain"), flow)
                output = String(take!(io))
                Test.@test occursin("FakeFlow", output)
                Test.@test occursin("system", output)
            end

            Test.@testset "compact" begin
                io = IOBuffer()
                show(io, flow)
                output = String(take!(io))
                Test.@test occursin("FakeFlow", output)
                Test.@test occursin("system", output)
            end
        end
    end
end

end # module

test_abstract_flow() = TestAbstractFlow.test_abstract_flow()
