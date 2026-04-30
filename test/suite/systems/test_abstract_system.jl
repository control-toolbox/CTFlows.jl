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
    data::Vector{Float64}
end

# Implement contract: rhs!
function Systems.rhs!(sys::FakeSystem)
    return (du, u, p, t) -> du .= sys.data .* u
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
            Test.@test FakeSystem([1.0, 2.0]) isa Systems.AbstractSystem
            Test.@test MinimalSystem(2) isa Systems.AbstractSystem
        end

        # ====================================================================
        # UNIT TESTS - Contract Implementation
        # ====================================================================

        Test.@testset "Contract Implementation" begin
            sys = FakeSystem([1.0, 2.0])

            Test.@testset "rhs! returns callable" begin
                rhs = Systems.rhs!(sys)
                Test.@test rhs isa Function
            end

            Test.@testset "rhs! function has correct signature (du, u, p, t)" begin
                rhs = Systems.rhs!(sys)
                du = zeros(2)
                u = [3.0, 4.0]
                p = []
                t = 0.0
                # Should not throw - signature is correct
                rhs(du, u, p, t)
                Test.@test du ≈ [3.0, 8.0] atol=1e-10
            end

            Test.@testset "rhs! function fills du in place" begin
                rhs = Systems.rhs!(sys)
                du = zeros(2)
                rhs(du, [3.0, 4.0], [], 0.0)
                Test.@test du ≈ [3.0, 8.0] atol=1e-10
            end

            Test.@testset "rhs! function uses system data" begin
                sys1 = FakeSystem([2.0, 3.0])
                sys2 = FakeSystem([0.5, 1.0])
                rhs1 = Systems.rhs!(sys1)
                rhs2 = Systems.rhs!(sys2)
                du1 = zeros(2)
                du2 = zeros(2)
                rhs1(du1, [1.0, 1.0], [], 0.0)
                rhs2(du2, [1.0, 1.0], [], 0.0)
                Test.@test du1 ≈ [2.0, 3.0] atol=1e-10
                Test.@test du2 ≈ [0.5, 1.0] atol=1e-10
            end
        end

        # ====================================================================
        # UNIT TESTS - Trait Methods
        # ====================================================================

        Test.@testset "Trait Methods" begin
            sys = FakeSystem([1.0, 2.0])
            sys2 = MinimalSystem(3)

            Test.@testset "has_time_dependence_trait returns true" begin
                Test.@test Common.has_time_dependence_trait(sys) === true
                Test.@test Common.has_time_dependence_trait(sys2) === true
            end

            Test.@testset "has_variable_dependence_trait returns true" begin
                Test.@test Common.has_variable_dependence_trait(sys) === true
                Test.@test Common.has_variable_dependence_trait(sys2) === true
            end

            Test.@testset "trait methods work for all AbstractSystem subtypes" begin
                # Verify that the trait methods work for any AbstractSystem subtype
                for sys_instance in [sys, sys2]
                    Test.@test Common.has_time_dependence_trait(sys_instance) === true
                    Test.@test Common.has_variable_dependence_trait(sys_instance) === true
                end
            end
        end

        # ====================================================================
        # UNIT TESTS - NotImplemented Errors
        # ====================================================================

        Test.@testset "NotImplemented Errors" begin
            sys = MinimalSystem(2)

            Test.@testset "rhs! throws NotImplemented" begin
                try
                    Systems.rhs!(sys)
                    Test.@test false  # Should not reach here
                catch err
                    Test.@test err isa Exceptions.NotImplemented
                    Test.@test occursin("rhs!", err.msg)
                end
            end

            Test.@testset "NotImplemented error contains required fields" begin
                try
                    Systems.rhs!(sys)
                    Test.@test false  # Should not reach here
                catch err
                    Test.@test err isa Exceptions.NotImplemented
                    Test.@test hasfield(typeof(err), :msg)
                    Test.@test hasfield(typeof(err), :context)
                end
            end
        end

        # ====================================================================
        # UNIT TESTS - Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "Exported types" begin
                Test.@test isdefined(Systems, :AbstractSystem)
            end
        end
    end
end

end # module

test_abstract_system() = TestAbstractSystem.test_abstract_system()
