module TestHamiltonianSystem

import Test
import CTBase.Exceptions
import CTFlows.Data: Data
import CTFlows.Common: Common
import CTFlows.Traits: Traits
import CTFlows.Systems: Systems
import CTFlows.Differentiation: Differentiation

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# Fake AD backend for testing (no actual AD, just a stub)
struct FakeADBackend <: Differentiation.AbstractADBackend end

function Differentiation.hamiltonian_gradient(backend::FakeADBackend, h, t, x, p, v, cache)
    # Fake gradient: ∂H/∂x = x, ∂H/∂p = p (for H = 0.5*(x^2 + p^2))
    return (x, p)
end

function Differentiation.variable_gradient(backend::FakeADBackend, h, t, x, p, v, cache)
    # Fake gradient: ∂H/∂v = v (for H = 0.5*v^2), or 0.0 if v is nothing
    return v === nothing ? 0.0 : v
end

function test_hamiltonian_system()
    Test.@testset "Hamiltonian System Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Construction
        # ====================================================================

        Test.@testset "Construction" begin
            h = Data.Hamiltonian((t, x, p, v) -> 0.5 * sum(x.^2) + sum(p.^2); is_autonomous=true, is_variable=false)
            backend = FakeADBackend()

            # Build system without state_dimension (lazy inference)
            sys = Systems.HamiltonianSystem(h, backend)
            Test.@test sys isa Systems.HamiltonianSystem
            Test.@test sys isa Systems.AbstractHamiltonianSystem
        end

        # ====================================================================
        # UNIT TESTS - ad_trait
        # ====================================================================

        Test.@testset "ad_trait" begin
            h = Data.Hamiltonian((t, x, p, v) -> 0.5 * sum(x.^2) + sum(p.^2); is_autonomous=true, is_variable=false)
            backend = FakeADBackend()
            sys = Systems.HamiltonianSystem(h, backend)

            Test.@test Traits.ad_trait(sys) === Traits.WithAD
        end

        # ====================================================================
        # UNIT TESTS - build_rhs (lazy in-place)
        # ====================================================================

        Test.@testset "build_rhs" begin
            h = Data.Hamiltonian((t, x, p, v) -> 0.5 * sum(x.^2) + sum(p.^2); is_autonomous=true, is_variable=false)
            backend = FakeADBackend()
            sys = Systems.HamiltonianSystem(h, backend)

            x0 = [1.0, 2.0]
            p0 = [3.0, 4.0]
            rhs = Systems.build_rhs(sys, x0, p0)
            Test.@test rhs isa Function

            # Test RHS call with vector
            u = [1.0, 2.0, 3.0, 4.0]  # x = [1, 2], p = [3, 4]
            du = zeros(4)
            p = Common.ODEParameters(nothing)
            rhs(du, u, p, 0.0)

            # ∂H/∂x = x = [1, 2], ∂H/∂p = p = [3, 4], so du = [∂p, -∂x] = [3, 4, -1, -2]
            Test.@test du[1:2] == [3.0, 4.0]
            Test.@test du[3:4] == [-1.0, -2.0]

            # Test RHS call with matrix
            x0_mat = [1.0 2.0; 3.0 4.0]
            p0_mat = [5.0 6.0; 7.0 8.0]
            rhs_mat = Systems.build_rhs(sys, x0_mat, p0_mat)
            u_mat = [1.0 2.0; 3.0 4.0; 5.0 6.0; 7.0 8.0]  # x = [1 2; 3 4], p = [5 6; 7 8]
            du_mat = zeros(4, 2)
            rhs_mat(du_mat, u_mat, p, 0.0)
            Test.@test du_mat ≈ [5.0 6.0; 7.0 8.0; -1.0 -2.0; -3.0 -4.0] atol=1e-10
        end

        # ====================================================================
        # UNIT TESTS - build_oop_rhs (lazy out-of-place)
        # ====================================================================

        Test.@testset "build_oop_rhs" begin
            h = Data.Hamiltonian((t, x, p, v) -> 0.5 * sum(x.^2) + sum(p.^2); is_autonomous=true, is_variable=false)
            backend = FakeADBackend()
            sys = Systems.HamiltonianSystem(h, backend)

            x0 = [1.0, 2.0]
            p0 = [3.0, 4.0]
            rhs_oop = Systems.build_oop_rhs(sys, x0, p0)
            Test.@test rhs_oop isa Function

            # Test OOP call with vector
            u = [1.0, 2.0, 3.0, 4.0]  # x = [1, 2], p = [3, 4]
            p = Common.ODEParameters(nothing)
            du = rhs_oop(u, p, 0.0)

            # ∂H/∂x = x = [1, 2], ∂H/∂p = p = [3, 4], so du = vcat(∂p, -∂x) = [3, 4, -1, -2]
            Test.@test du == [3.0, 4.0, -1.0, -2.0]
        end

        # ====================================================================
        # UNIT TESTS - build_rhs_augmented
        # ====================================================================

        Test.@testset "build_rhs_augmented" begin
            h = Data.Hamiltonian((t, x, p, v) -> 0.5 * sum(x.^2) + sum(p.^2) + 0.5 * v^2; is_autonomous=true, is_variable=false)
            backend = FakeADBackend()
            sys = Systems.HamiltonianSystem(h, backend)

            # Vector case (n_x=2, n_v=1)
            rhs_aug = Systems.build_rhs_augmented(sys, 2, 1)
            Test.@test rhs_aug isa Function

            u = [1.0, 2.0, 3.0, 4.0, 0.5]  # x = [1, 2], p = [3, 4], pv = [0.5]
            du = zeros(5)
            p = Common.ODEParameters(0.5)  # variable is 0.5 (matches pv in u)
            rhs_aug(du, u, p, 0.0)

            # ∂H/∂x = x = [1, 2], ∂H/∂p = p = [3, 4], ∂H/∂v = v = 0.5
            # du = [∂p, -∂x, -∂v] = [3, 4, -1, -2, -0.5]
            Test.@test du[1:2] == [3.0, 4.0]
            Test.@test du[3:4] == [-1.0, -2.0]
            Test.@test du[5] == -0.5

            # Matrix compatible case (10×3, v matrice 1×3)
            u_mat = [1.0 2.0 3.0; 4.0 5.0 6.0; 7.0 8.0 9.0; 10.0 11.0 12.0; 0.5 0.6 0.7]
            du_mat = zeros(5, 3)
            p_mat = Common.ODEParameters([0.5 0.6 0.7])  # v as matrix with 3 columns
            rhs_aug(du_mat, u_mat, p_mat, 0.0)
            Test.@test size(du_mat, 2) == 3  # no error, compatible

            # Matrix incompatible case (10×3, v matrice 1×2) → PreconditionError
            u_mat2 = [1.0 2.0; 4.0 5.0; 7.0 8.0; 10.0 11.0; 0.5 0.6]
            du_mat2 = zeros(5, 2)
            p_mat2 = Common.ODEParameters([0.5 0.6 0.7])  # v has 3 columns, u has 2
            Test.@test_throws Exceptions.PreconditionError rhs_aug(du_mat2, u_mat2, p_mat2, 0.0)

            # u Matrix, v Vector (no-op check)
            u_mat3 = [1.0 2.0; 4.0 5.0; 7.0 8.0; 10.0 11.0; 0.5 0.6]
            du_mat3 = zeros(5, 2)
            p_vec = Common.ODEParameters(0.5)  # v as scalar (not a matrix)
            rhs_aug(du_mat3, u_mat3, p_vec, 0.0)  # no error, no-op check
        end

        # ====================================================================
        # UNIT TESTS - _aug_split
        # ====================================================================

        Test.@testset "_aug_split" begin
            # Vector case
            u_vec = [1.0, 2.0, 3.0, 4.0, 0.5]
            x, p, pv = Systems._aug_split(u_vec, 2, 1)
            Test.@test x == [1.0, 2.0]
            Test.@test p == [3.0, 4.0]
            Test.@test pv == [0.5]

            # Matrix case
            u_mat = [1.0 2.0; 3.0 4.0; 5.0 6.0; 7.0 8.0; 0.5 0.6]
            x_mat, p_mat, pv_mat = Systems._aug_split(u_mat, 2, 1)
            Test.@test x_mat == [1.0 2.0; 3.0 4.0]
            Test.@test p_mat == [5.0 6.0; 7.0 8.0]
            Test.@test pv_mat == [0.5 0.6]
        end

        # ====================================================================
        # UNIT TESTS - _check_aug_batch_compat
        # ====================================================================

        Test.@testset "_check_aug_batch_compat" begin
            # Compatible matrices
            u = [1.0 2.0; 3.0 4.0]
            v = [0.5 0.6]
            Test.@test Systems._check_aug_batch_compat(u, v) === nothing  # no error

            # Incompatible matrices
            u2 = [1.0 2.0; 3.0 4.0]
            v2 = [0.5 0.6 0.7]
            Test.@test_throws Exceptions.PreconditionError Systems._check_aug_batch_compat(u2, v2)

            # Non-matrix cases (no-op)
            u3 = [1.0, 2.0, 3.0]
            v3 = [0.5]
            Test.@test Systems._check_aug_batch_compat(u3, v3) === nothing

            u4 = [1.0 2.0; 3.0 4.0]
            v4 = 0.5
            Test.@test Systems._check_aug_batch_compat(u4, v4) === nothing
        end

        # ====================================================================
        # UNIT TESTS - build_system overloads
        # ====================================================================

        Test.@testset "build_system" begin
            h = Data.Hamiltonian((t, x, p, v) -> 0.5 * sum(x.^2) + sum(p.^2); is_autonomous=true, is_variable=false)
            backend = FakeADBackend()

            # Build system without state_dimension (lazy inference)
            sys = Systems.build_system(h, backend)
            Test.@test sys isa Systems.HamiltonianSystem
        end

        # ====================================================================
        # UNIT TESTS - Type Stability
        # ====================================================================

        Test.@testset "Type Stability" begin
            h = Data.Hamiltonian((t, x, p, v) -> 0.5 * sum(x.^2) + sum(p.^2); is_autonomous=true, is_variable=false)
            backend = FakeADBackend()

            sys = Systems.HamiltonianSystem(h, backend)
            Test.@test Test.@inferred Traits.ad_trait(sys) === Traits.WithAD
        end

        # ====================================================================
        # REGRESSION TEST - HamiltonianVectorFieldSystem unaffected
        # ====================================================================

        Test.@testset "Regression: HamiltonianVectorFieldSystem" begin
            hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
            sys = Systems.HamiltonianVectorFieldSystem(hvf)
            Test.@test sys isa Systems.HamiltonianVectorFieldSystem
            Test.@test sys isa Systems.AbstractHamiltonianSystem
            Test.@test Traits.ad_trait(sys) === Traits.WithoutAD
        end
    end
end

end # module

test_hamiltonian_system() = TestHamiltonianSystem.test_hamiltonian_system()
