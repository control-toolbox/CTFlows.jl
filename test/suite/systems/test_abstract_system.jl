module TestAbstractSystem

using Test: Test
import CTBase.Exceptions
import CTFlows.Systems
import CTFlows.Common
import CTBase.Traits

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Fake types for contract testing
# ==============================================================================

"""
Fake system for testing the AbstractSystem contract.

This minimal implementation provides the required contract methods to test
routing and default behavior without full system complexity.
"""
struct FakeSystem <:
       Systems.AbstractSystem{Traits.Autonomous,Traits.Fixed,Traits.StateDynamics}
    data::Vector{Float64}
end

# Implement contract: get_ip_rhs
function Systems.get_ip_rhs(sys::FakeSystem, _)
    return (du, u, p, t) -> du .= sys.data .* u
end

# Fake subtypes for hierarchy testing
struct FakeStateSystem <: Systems.AbstractStateSystem{Traits.Autonomous,Traits.Fixed}
    data::Vector{Float64}
end

function Systems.get_ip_rhs(sys::FakeStateSystem, _)
    return (du, u, p, t) -> du .= sys.data .* u
end

struct FakeHamiltonianSystem <:
       Systems.AbstractHamiltonianSystem{Traits.Autonomous,Traits.Fixed}
    data::Vector{Float64}
end

function Systems.get_ip_rhs(sys::FakeHamiltonianSystem, _)
    return (du, u, p, t) -> du .= sys.data .* u
end

"""
Minimal system that does not implement the contract (for error testing).
"""
struct MinimalSystem <:
       Systems.AbstractSystem{Traits.Autonomous,Traits.Fixed,Traits.StateDynamics}
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

        Test.@testset "Hierarchy" begin
            Test.@test FakeStateSystem([1.0, 2.0]) isa Systems.AbstractStateSystem
            Test.@test FakeStateSystem([1.0, 2.0]) isa Systems.AbstractSystem
            Test.@test FakeHamiltonianSystem([1.0, 2.0]) isa
                Systems.AbstractHamiltonianSystem
            Test.@test FakeHamiltonianSystem([1.0, 2.0]) isa Systems.AbstractSystem
            # Verify the two subtypes are not related to each other
            Test.@test !(FakeStateSystem([1.0, 2.0]) isa Systems.AbstractHamiltonianSystem)
            Test.@test !(FakeHamiltonianSystem([1.0, 2.0]) isa Systems.AbstractStateSystem)
        end

        # ====================================================================
        # UNIT TESTS - Contract Implementation
        # ====================================================================

        Test.@testset "Contract Implementation" begin
            dummy_config = nothing
            sys = FakeSystem([1.0, 2.0])

            Test.@testset "get_ip_rhs returns callable" begin
                rhs = Systems.get_ip_rhs(sys, dummy_config)
                Test.@test rhs isa Function
            end

            Test.@testset "get_ip_rhs function has correct signature (du, u, p, t)" begin
                rhs = Systems.get_ip_rhs(sys, dummy_config)
                du = zeros(2)
                u = [3.0, 4.0]
                p = []
                t = 0.0
                # Should not throw - signature is correct
                rhs(du, u, p, t)
                Test.@test du ≈ [3.0, 8.0] atol=1e-10
            end

            Test.@testset "get_ip_rhs function fills du in place" begin
                rhs = Systems.get_ip_rhs(sys, dummy_config)
                du = zeros(2)
                rhs(du, [3.0, 4.0], [], 0.0)
                Test.@test du ≈ [3.0, 8.0] atol=1e-10
            end

            Test.@testset "get_ip_rhs function uses system data" begin
                sys1 = FakeSystem([2.0, 3.0])
                sys2 = FakeSystem([0.5, 1.0])
                rhs1 = Systems.get_ip_rhs(sys1, dummy_config)
                rhs2 = Systems.get_ip_rhs(sys2, dummy_config)
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
                Test.@test Traits.has_time_dependence_trait(sys) === true
                Test.@test Traits.has_time_dependence_trait(sys2) === true
            end

            Test.@testset "has_variable_dependence_trait returns true" begin
                Test.@test Traits.has_variable_dependence_trait(sys) === true
                Test.@test Traits.has_variable_dependence_trait(sys2) === true
            end

            Test.@testset "time_dependence extracts trait from type parameter" begin
                Test.@test Traits.time_dependence(sys) === Traits.Autonomous
                Test.@test Traits.time_dependence(sys2) === Traits.Autonomous
            end

            Test.@testset "variable_dependence extracts trait from type parameter" begin
                Test.@test Traits.variable_dependence(sys) === Traits.Fixed
                Test.@test Traits.variable_dependence(sys2) === Traits.Fixed
            end

            Test.@testset "trait methods work for all AbstractSystem subtypes" begin
                # Verify that the trait methods work for any AbstractSystem subtype
                for sys_instance in [sys, sys2]
                    Test.@test Traits.has_time_dependence_trait(sys_instance) === true
                    Test.@test Traits.has_variable_dependence_trait(sys_instance) === true
                end
            end
        end

        # ====================================================================
        # UNIT TESTS - NotImplemented Errors
        # ====================================================================

        Test.@testset "NotImplemented Errors" begin
            dummy_config = nothing
            sys = MinimalSystem(2)

            Test.@testset "get_ip_rhs throws NotImplemented" begin
                try
                    Systems.get_ip_rhs(sys, dummy_config)
                    Test.@test false  # Should not reach here
                catch err
                    Test.@test err isa Exceptions.NotImplemented
                    Test.@test occursin("get_ip_rhs", err.msg)
                end
            end

            Test.@testset "get_oop_rhs throws NotImplemented" begin
                try
                    Systems.get_oop_rhs(sys, dummy_config)
                    Test.@test false  # Should not reach here
                catch err
                    Test.@test err isa Exceptions.NotImplemented
                    Test.@test occursin("get_oop_rhs", err.msg)
                end
            end

            Test.@testset "NotImplemented error contains required fields" begin
                try
                    Systems.get_ip_rhs(sys, dummy_config)
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
                Test.@test isdefined(Systems, :AbstractStateSystem)
                Test.@test isdefined(Systems, :AbstractHamiltonianSystem)
            end
        end
    end
end

end # module

test_abstract_system() = TestAbstractSystem.test_abstract_system()
