module TestHamRHSFunctors

using Test: Test
import CTBase.Exceptions
import CTFlows.Common: Common
import CTBase.Data: Data
import CTFlows.Systems: Systems
import CTBase.Traits: Traits
import CTBase.Differentiation

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# =============================================================================
# Fake Hamiltonian and backend for testing (top-level)
# =============================================================================

const FakeHamiltonian = Data.Hamiltonian(
    (x, p) -> 0.5 * (x[1]^2 + x[2]^2) + 0.5 * (p[1]^2 + p[2]^2);
    is_autonomous=true,
    is_variable=false,
)
const FakeHamiltonianNF = Data.Hamiltonian(
    (x, p, v) -> 0.5 * (x[1]^2 + x[2]^2) + 0.5 * (p[1]^2 + p[2]^2) + 0.5 * v^2;
    is_autonomous=true,
    is_variable=true,
)

struct FakeADBackend <: Differentiation.AbstractADBackend end

function Differentiation.hamiltonian_gradient(
    backend::FakeADBackend, h::Data.AbstractHamiltonian, t, x, p, v
)
    return (x, p)
end

function Differentiation.variable_gradient(
    backend::FakeADBackend, h::Data.AbstractHamiltonian, t, x, p, v
)
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

            ip_rhs = Systems.HamIpRHS(h, backend, 2, identity, identity)
            oop_rhs = Systems.HamOoPRHS(h, backend, 2, identity, identity)
            aug_rhs = Systems.HamIpAugRHS(h, backend, 2, 1, identity, identity)

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
            rhs = Systems.HamIpRHS(h, backend, 2, identity, identity)

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

        Test.@testset "HamIpRHS — NonFixed call" begin
            backend = FakeADBackend()
            h = FakeHamiltonianNF
            rhs = Systems.HamIpRHS(h, backend, 2, identity, identity)

            du = zeros(4)
            u = [1.0, 2.0, 3.0, 4.0]
            λ = Common.ODEParameters(0.5)
            t = 0.0

            rhs(du, u, λ, t)
            # ∂H/∂x = x = [1.0, 2.0], ∂H/∂p = p = [3.0, 4.0] (v doesn't affect these gradients)
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
            rhs = Systems.HamOoPRHS(h, backend, 2, identity, identity)

            u = [1.0, 2.0, 3.0, 4.0]
            λ = Common.ODEParameters(nothing)
            t = 0.0

            result = rhs(u, λ, t)
            # ∂H/∂x = x = [1.0, 2.0], ∂H/∂p = p = [3.0, 4.0]
            # result = [∂p, -∂x] = [3.0, 4.0, -1.0, -2.0]
            Test.@test result[1:2] == [3.0, 4.0]
            Test.@test result[3:4] == [-1.0, -2.0]
        end

        Test.@testset "HamOoPRHS — NonFixed call" begin
            backend = FakeADBackend()
            h = FakeHamiltonianNF
            rhs = Systems.HamOoPRHS(h, backend, 2, identity, identity)

            u = [1.0, 2.0, 3.0, 4.0]
            λ = Common.ODEParameters(0.5)
            t = 0.0

            result = rhs(u, λ, t)
            # ∂H/∂x = x = [1.0, 2.0], ∂H/∂p = p = [3.0, 4.0] (v doesn't affect these gradients)
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
            rhs = Systems.HamIpAugRHS(h, backend, 2, 1, identity, identity)

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
            # Compatible matrices
            u = [1.0 2.0; 3.0 4.0]
            v = [0.5 0.6]
            Test.@test Systems._check_aug_batch_compat(u, v) === nothing

            # Incompatible matrices
            u2 = [1.0 2.0; 3.0 4.0]
            v2 = [0.5 0.6 0.7]
            Test.@test_throws Exceptions.PreconditionError Systems._check_aug_batch_compat(
                u2, v2
            )

            # Non-matrix cases (no-op)
            u3 = [1.0, 2.0, 3.0]
            v3 = [0.5]
            Test.@test Systems._check_aug_batch_compat(u3, v3) === nothing

            u4 = [1.0 2.0; 3.0 4.0]
            v4 = 0.5
            Test.@test Systems._check_aug_batch_compat(u4, v4) === nothing
        end

        # =============================================================================
        # Test type stability
        # =============================================================================

        Test.@testset "Type Stability" begin
            backend = FakeADBackend()
            h = FakeHamiltonian

            ip_rhs = Systems.HamIpRHS(h, backend, 2, identity, identity)
            oop_rhs = Systems.HamOoPRHS(h, backend, 2, identity, identity)

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

            ip_rhs = Systems.HamIpRHS(h, backend, 2, identity, identity)
            oop_rhs = Systems.HamOoPRHS(h, backend, 2, identity, identity)
            aug_rhs = Systems.HamIpAugRHS(h, backend, 2, 1, identity, identity)

            Test.@test occursin("HamIpRHS", sprint(show, ip_rhs))
            Test.@test occursin("Hamiltonian AD → in-place interface", sprint(show, ip_rhs))
            Test.@test occursin("HamOoPRHS", sprint(show, oop_rhs))
            Test.@test occursin(
                "Hamiltonian AD → out-of-place interface", sprint(show, oop_rhs)
            )
            Test.@test occursin("HamIpAugRHS", sprint(show, aug_rhs))
            Test.@test occursin(
                "Hamiltonian AD → in-place augmented interface", sprint(show, aug_rhs)
            )
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_ham_rhs_functors() = TestHamRHSFunctors.test_ham_rhs_functors()
