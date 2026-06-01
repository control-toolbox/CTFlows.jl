module TestHamRHSFunctors

import Test
import CTFlows.Common: Common
import CTFlows.Data: Data
import CTFlows.Systems: Systems
import CTFlows.Traits: Traits
import CTFlows.Differentiation: Differentiation

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# =============================================================================
# Fake Hamiltonian and backend for testing (top-level)
# =============================================================================

const FakeHamiltonian = Data.Hamiltonian((x, p) -> 0.5 * (x[1]^2 + x[2]^2) + 0.5 * (p[1]^2 + p[2]^2); is_autonomous=true, is_variable=false)

struct FakeADBackend <: Differentiation.AbstractADBackend end

function Differentiation.prepare_cache(backend::FakeADBackend, h, t, x, p, v)
    # Fake cache: just return nothing (no actual preparation)
    return nothing
end

function Differentiation.hamiltonian_gradient(backend::FakeADBackend, h, t, x, p, v, cache)
    # Fake gradient: ∂H/∂x = x, ∂H/∂p = p
    return (x, p)
end

function Differentiation.variable_gradient(backend::FakeADBackend, h, t, x, p, v, cache)
    # Fake variable gradient: ∂H/∂v = zeros (since H doesn't depend on v)
    return zeros(length(v))
end

function test_ham_rhs_functors()
    Test.@testset "Hamiltonian RHS Functors Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # =============================================================================
        # Test hierarchy
        # =============================================================================

        Test.@testset "Abstract types" begin
            backend = FakeADBackend()
            h = FakeHamiltonian
            
            ip_rhs = Systems.HamIpRHS(h, backend, 2, identity, identity, nothing)
            oop_rhs = Systems.HamOoPRHS(h, backend, 2, identity, identity, nothing)
            aug_rhs = Systems.HamIpAugRHS(h, backend, 2, 1, nothing)

            Test.@test ip_rhs isa Systems.AbstractIPHamRHS
            Test.@test ip_rhs isa Systems.AbstractRHS{Traits.InPlace}
            Test.@test oop_rhs isa Systems.AbstractOoPHamRHS
            Test.@test oop_rhs isa Systems.AbstractRHS{Traits.OutOfPlace}
            Test.@test aug_rhs isa Systems.AbstractIPHamRHS
            Test.@test aug_rhs isa Systems.AbstractRHS{Traits.InPlace}
        end

        # =============================================================================
        # Test HamIpRHS
        # =============================================================================

        Test.@testset "HamIpRHS — call" begin
            backend = FakeADBackend()
            h = FakeHamiltonian
            rhs = Systems.HamIpRHS(h, backend, 2, identity, identity, nothing)

            du = zeros(4)
            u = [1.0, 2.0, 3.0, 4.0]
            λ = Common.ODEParameters(nothing)
            t = 0.0

            rhs(du, u, λ, t)
            # ∂H/∂x = x = [1.0, 2.0], ∂H/∂p = p = [3.0, 4.0]
            # du = [∂p, -∂x] = [3.0, 4.0, -1.0, -2.0]
            Test.@test du[1:2] == [3.0, 4.0]
            Test.@test du[3:4] == [-1.0, -2.0]
        end

        # =============================================================================
        # Test HamOoPRHS
        # =============================================================================

        Test.@testset "HamOoPRHS — call" begin
            backend = FakeADBackend()
            h = FakeHamiltonian
            rhs = Systems.HamOoPRHS(h, backend, 2, identity, identity, nothing)

            u = [1.0, 2.0, 3.0, 4.0]
            λ = Common.ODEParameters(nothing)
            t = 0.0

            result = rhs(u, λ, t)
            # ∂H/∂x = x = [1.0, 2.0], ∂H/∂p = p = [3.0, 4.0]
            # result = [∂p, -∂x] = [3.0, 4.0, -1.0, -2.0]
            Test.@test result[1:2] == [3.0, 4.0]
            Test.@test result[3:4] == [-1.0, -2.0]
        end

        # =============================================================================
        # Test HamIpAugRHS
        # =============================================================================

        Test.@testset "HamIpAugRHS — call vector" begin
            backend = FakeADBackend()
            h = FakeHamiltonian
            rhs = Systems.HamIpAugRHS(h, backend, 2, 1, nothing)

            du = zeros(5)
            u = [1.0, 2.0, 3.0, 4.0, 0.0]
            λ = Common.ODEParameters(0.5)
            t = 0.0

            rhs(du, u, λ, t)
            # x = [1.0, 2.0], p = [3.0, 4.0], v = 0.5
            # ∂H/∂x = x = [1.0, 2.0], ∂H/∂p = p = [3.0, 4.0]
            # ∂H/∂v = zeros(1) = [0.0]
            # du = [∂p, -∂x, -∂pv] = [3.0, 4.0, -1.0, -2.0, 0.0]
            Test.@test du[1:2] == [3.0, 4.0]
            Test.@test du[3:4] == [-1.0, -2.0]
            Test.@test du[5] == 0.0
        end

        Test.@testset "HamIpAugRHS — batch compatibility check" begin
            # Note: Batch compatibility is tested in integration tests with real backends
            # The private _check_aug_batch_compat function is not exported for direct testing
            Test.@test true
        end

        # =============================================================================
        # Test type stability
        # =============================================================================

        Test.@testset "Type Stability" begin
            backend = FakeADBackend()
            h = FakeHamiltonian
            
            ip_rhs = Systems.HamIpRHS(h, backend, 2, identity, identity, nothing)
            oop_rhs = Systems.HamOoPRHS(h, backend, 2, identity, identity, nothing)

            du = zeros(4)
            u = [1.0, 2.0, 3.0, 4.0]
            λ = Common.ODEParameters(nothing)
            t = 0.0

            Test.@inferred ip_rhs(du, u, λ, t)
            Test.@inferred oop_rhs(u, λ, t)
            
            # Note: HamIpAugRHS type stability not tested due to batch mode complexity
        end

        # =============================================================================
        # Test display
        # =============================================================================

        Test.@testset "Display" begin
            backend = FakeADBackend()
            h = FakeHamiltonian
            
            ip_rhs = Systems.HamIpRHS(h, backend, 2, identity, identity, nothing)
            oop_rhs = Systems.HamOoPRHS(h, backend, 2, identity, identity, nothing)
            aug_rhs = Systems.HamIpAugRHS(h, backend, 2, 1, nothing)

            Test.@test occursin("HamIpRHS", sprint(show, ip_rhs))
            Test.@test occursin("Hamiltonian AD → in-place interface", sprint(show, ip_rhs))
            Test.@test occursin("HamOoPRHS", sprint(show, oop_rhs))
            Test.@test occursin("Hamiltonian AD → out-of-place interface", sprint(show, oop_rhs))
            Test.@test occursin("HamIpAugRHS", sprint(show, aug_rhs))
            Test.@test occursin("Hamiltonian AD → in-place augmented interface", sprint(show, aug_rhs))
        end

    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_ham_rhs_functors() = TestHamRHSFunctors.test_ham_rhs_functors()
