module TestAbstractSystem

import Test
import CTBase.Exceptions
import CTFlows.Systems

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

function Systems.dimensions(sys::FakeSystem)
    return (n_x=sys.state_dim, n_p=sys.costate_dim, n_u=sys.control_dim, n_v=sys.variable_dim)
end

function Systems.build_solution(sys::FakeSystem, ode_sol)
    return ode_sol  # Return as-is for testing
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

            Test.@testset "dimensions returns NamedTuple" begin
                dims = Systems.dimensions(sys)
                Test.@test dims isa NamedTuple
                Test.@test dims.n_x == 2
                Test.@test dims.n_p == 2
                Test.@test dims.n_u == 1
                Test.@test dims.n_v == 0
            end

            Test.@testset "build_solution returns input" begin
                ode_sol = :fake_solution
                result = Systems.build_solution(sys, ode_sol)
                Test.@test result === ode_sol
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

            Test.@testset "dimensions throws NotImplemented" begin
                Test.@test_throws Exceptions.NotImplemented Systems.dimensions(sys)
            end

            Test.@testset "build_solution throws NotImplemented" begin
                Test.@test_throws Exceptions.NotImplemented Systems.build_solution(sys, :fake_sol)
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
