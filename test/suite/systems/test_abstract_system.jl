module TestAbstractSystem

import Test
import CTBase.Exceptions
import CTFlows.Systems
import CTFlows.Common

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for contract testing
# ==============================================================================

"""
Fake system for testing the AbstractSystem contract.

This minimal implementation provides the required contract methods to test
routing and default behavior without full system complexity.
"""
struct FakeSystem <: Systems.AbstractSystem
    state_dim::Int
    costate_dim::Int
    control_dim::Int
    variable_dim::Int
end

# Implement contract
function Systems.rhs!(sys::FakeSystem)
    return (du, u, p, t) -> nothing
end

function Systems.build_solution(sys::FakeSystem, ode_sol, flow, config)
    return ode_sol  # Return as-is for testing
end

function Systems.ode_problem(sys::FakeSystem, config)
    return :fake_ode_problem
end

"""
Minimal system that does not implement the contract (for error testing).
"""
struct MinimalSystem <: Systems.AbstractSystem
    state_dim::Int
end

# ==============================================================================
# Test function
# ==============================================================================

function test_abstract_system()
    Test.@testset "Abstract System Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            Test.@test FakeSystem(2, 2, 1, 0) isa Systems.AbstractSystem
            Test.@test MinimalSystem(2) isa Systems.AbstractSystem
        end

        # ====================================================================
        # UNIT TESTS - Contract Implementation
        # ====================================================================

        Test.@testset "Contract Implementation" begin
            sys = FakeSystem(2, 2, 1, 0)

            Test.@testset "rhs! returns callable" begin
                rhs = Systems.rhs!(sys)
                Test.@test rhs isa Function
            end

            Test.@testset "build_solution returns input" begin
                ode_sol = :fake_solution
                flow = :fake_flow
                config = Common.PointConfig(0.0, [1.0], 1.0)
                result = Systems.build_solution(sys, ode_sol, flow, config)
                Test.@test result === ode_sol
            end

            Test.@testset "ode_problem returns fake problem" begin
                config = Common.PointConfig(0.0, [1.0], 1.0)
                result = Systems.ode_problem(sys, config)
                Test.@test result === :fake_ode_problem
            end

            Test.@testset "variable_dependence defaults to Fixed" begin
                Test.@test Systems.variable_dependence(sys) === Common.Fixed
            end
        end

        # ====================================================================
        # UNIT TESTS - NotImplemented Errors
        # ====================================================================

        Test.@testset "NotImplemented Errors" begin
            sys = MinimalSystem(2)

            Test.@testset "rhs! throws NotImplemented" begin
                Test.@test_throws Exceptions.NotImplemented Systems.rhs!(sys)
            end

            Test.@testset "build_solution throws NotImplemented" begin
                Test.@test_throws Exceptions.NotImplemented Systems.build_solution(sys, :fake_sol, :fake_flow, Common.PointConfig(0.0, [1.0], 1.0))
            end

            Test.@testset "ode_problem throws NotImplemented" begin
                Test.@test_throws Exceptions.NotImplemented Systems.ode_problem(sys, Common.PointConfig(0.0, [1.0], 1.0))
            end
        end

        # ====================================================================
        # UNIT TESTS - Base.show
        # ====================================================================

        Test.@testset "Base.show" begin
            sys = FakeSystem(2, 2, 1, 0)

            Test.@testset "MIME text/plain" begin
                io = IOBuffer()
                show(io, MIME("text/plain"), sys)
                output = String(take!(io))
                Test.@test occursin("FakeSystem", output)
                Test.@test occursin("n_x: 2", output)
            end

            Test.@testset "compact" begin
                io = IOBuffer()
                show(io, sys)
                output = String(take!(io))
                Test.@test occursin("FakeSystem", output)
                Test.@test occursin("n_x=2", output)
            end
        end
    end
end

end # module

test_abstract_system() = TestAbstractSystem.test_abstract_system()
