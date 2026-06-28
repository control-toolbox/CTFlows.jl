module TestHamiltonianVectorFieldSystem

using Test: Test
import CTBase.Exceptions
import CTBase.Data: Data
import CTFlows.Common: Common
import CTBase.Traits: Traits
import CTFlows.Systems: Systems
import CTFlows.Configs: Configs
import CTFlows.Trajectories: Trajectories
import StaticArrays: SA, StaticArrays

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_hamiltonian_vector_field_system()
    Test.@testset "Hamiltonian Vector Field System Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Construction
        # ====================================================================

        Test.@testset "Construction" begin
            # From HamiltonianVectorField (lazy, no dimension)
            hvf = Data.HamiltonianVectorField(
                (x, p) -> (x, -p); is_autonomous=true, is_variable=false
            )
            sys = Systems.HamiltonianVectorFieldSystem(hvf)
            Test.@test sys isa Systems.HamiltonianVectorFieldSystem
            Test.@test sys isa Systems.AbstractHamiltonianSystem

            # Hierarchy check: supertype (2-param alias, AD via ad_trait)
            Test.@test sys isa
                Systems.AbstractHamiltonianSystem{Traits.Autonomous,Traits.Fixed}
        end

        Test.@testset "ad_trait" begin
            hvf = Data.HamiltonianVectorField(
                (x, p) -> (x, -p); is_autonomous=true, is_variable=false
            )
            sys = Systems.HamiltonianVectorFieldSystem(hvf)

            Test.@test Traits.ad_trait(sys) === Traits.WithoutAD
            Test.@test Test.@inferred Traits.ad_trait(sys) === Traits.WithoutAD
        end

        # ====================================================================
        # UNIT TESTS - build_system
        # ====================================================================

        Test.@testset "build_system" begin
            hvf = Data.HamiltonianVectorField(
                (x, p) -> (x, -p); is_autonomous=true, is_variable=false
            )

            # Build system without state_dimension (lazy inference)
            sys = Systems.build_system(hvf)
            Test.@test sys isa Systems.HamiltonianVectorFieldSystem
        end

        # ====================================================================
        # UNIT TESTS - get_ip_rhs (lazy in-place)
        # ====================================================================

        Test.@testset "get_ip_rhs" begin
            hvf = Data.HamiltonianVectorField(
                (x, p) -> (x, -p); is_autonomous=true, is_variable=false
            )
            sys = Systems.HamiltonianVectorFieldSystem(hvf)

            x0 = [1.0, 2.0]
            p0 = [3.0, 4.0]
            config = Configs.HamiltonianEndPointConfig(0.0, x0, p0, 1.0)
            rhs = Systems.get_ip_rhs(sys, config)
            Test.@test rhs isa Systems.AbstractIPHVFRHS

            # Test RHS call with vector
            u = [1.0, 2.0, 3.0, 4.0]  # x = [1, 2], p = [3, 4]
            du = zeros(4)
            p = Common.ODEParameters(nothing)
            rhs(du, u, p, 0.0)

            # dx = x = [1, 2], dp = -p = [-3, -4]
            Test.@test du[1:2] == [1.0, 2.0]
            Test.@test du[3:4] == [-3.0, -4.0]

            # Test RHS call with matrix
            x0_mat = [1.0 2.0; 3.0 4.0]
            p0_mat = [5.0 6.0; 7.0 8.0]
            config_mat = Configs.HamiltonianEndPointConfig(0.0, x0_mat, p0_mat, 1.0)
            rhs_mat = Systems.get_ip_rhs(sys, config_mat)
            u_mat = [1.0 2.0; 3.0 4.0; 5.0 6.0; 7.0 8.0]  # x = [1 2; 3 4], p = [5 6; 7 8]
            du_mat = zeros(4, 2)
            rhs_mat(du_mat, u_mat, p, 0.0)
            Test.@test du_mat ≈ [1.0 2.0; 3.0 4.0; -5.0 -6.0; -7.0 -8.0] atol=1e-10
        end

        # ====================================================================
        # UNIT TESTS - get_oop_rhs (lazy out-of-place)
        # ====================================================================

        Test.@testset "get_oop_rhs" begin
            hvf = Data.HamiltonianVectorField(
                (x, p) -> (x, -p); is_autonomous=true, is_variable=false
            )
            sys = Systems.HamiltonianVectorFieldSystem(hvf)

            x0 = [1.0, 2.0]
            p0 = [3.0, 4.0]
            config = Configs.HamiltonianEndPointConfig(0.0, x0, p0, 1.0)
            rhs_oop = Systems.get_oop_rhs(sys, config)
            Test.@test rhs_oop isa Systems.AbstractOoPHVFRHS

            # Test RHS OOP call with vector
            u = [1.0, 2.0, 3.0, 4.0]  # x = [1, 2], p = [3, 4]
            p = Common.ODEParameters(nothing)
            du = rhs_oop(u, p, 0.0)

            # dx = x = [1, 2], dp = -p = [-3, -4]
            Test.@test du[1:2] == [1.0, 2.0]
            Test.@test du[3:4] == [-3.0, -4.0]

            # Test RHS OOP call with matrix
            x0_mat = [1.0 2.0; 3.0 4.0]
            p0_mat = [5.0 6.0; 7.0 8.0]
            config_mat = Configs.HamiltonianEndPointConfig(0.0, x0_mat, p0_mat, 1.0)
            rhs_oop_mat = Systems.get_oop_rhs(sys, config_mat)
            u_mat = [1.0 2.0; 3.0 4.0; 5.0 6.0; 7.0 8.0]  # x = [1 2; 3 4], p = [5 6; 7 8]
            du_mat = rhs_oop_mat(u_mat, p, 0.0)
            Test.@test du_mat ≈ [1.0 2.0; 3.0 4.0; -5.0 -6.0; -7.0 -8.0] atol=1e-10
        end

        # ====================================================================
        # UNIT TESTS - Complex numbers
        # ====================================================================

        Test.@testset "Complex numbers" begin
            hvf = Data.HamiltonianVectorField(
                (x, p) -> (x, -p); is_autonomous=true, is_variable=false
            )
            sys = Systems.HamiltonianVectorFieldSystem(hvf)
            p_param = Common.ODEParameters(nothing)

            Test.@testset "get_ip_rhs - complex vector" begin
                x0 = [1.0+2.0im]
                p0 = [3.0+4.0im]
                config = Configs.HamiltonianEndPointConfig(0.0, x0, p0, 1.0)
                rhs = Systems.get_ip_rhs(sys, config)
                # x = [1+2im], p = [3+4im]  →  dx = x, dp = -p
                u = [1.0+2.0im, 3.0+4.0im]
                du = zeros(ComplexF64, 2)
                rhs(du, u, p_param, 0.0)
                Test.@test du ≈ [1.0+2.0im, -3.0-4.0im] atol=1e-10
            end

            Test.@testset "get_oop_rhs - complex vector" begin
                x0 = [1.0+2.0im]
                p0 = [3.0+4.0im]
                config = Configs.HamiltonianEndPointConfig(0.0, x0, p0, 1.0)
                rhs_oop = Systems.get_oop_rhs(sys, config)
                u = [1.0+2.0im, 3.0+4.0im]
                du = rhs_oop(u, p_param, 0.0)
                Test.@test du ≈ [1.0+2.0im, -3.0-4.0im] atol=1e-10
            end

            Test.@testset "get_ip_rhs - complex matrix" begin
                x0 = [1.0+2.0im 5.0+6.0im]
                p0 = [3.0+4.0im 7.0+8.0im]
                config = Configs.HamiltonianEndPointConfig(0.0, x0, p0, 1.0)
                rhs = Systems.get_ip_rhs(sys, config)
                # x = [1+2im  5+6im], p = [3+4im  7+8im]
                u = [1.0+2.0im 5.0+6.0im; 3.0+4.0im 7.0+8.0im]
                du = zeros(ComplexF64, 2, 2)
                rhs(du, u, p_param, 0.0)
                # dx = x = rows 1, dp = -p = rows 2 negated
                Test.@test du ≈ [1.0+2.0im 5.0+6.0im; -3.0-4.0im -7.0-8.0im] atol=1e-10
            end

            Test.@testset "get_oop_rhs - complex matrix" begin
                x0 = [1.0+2.0im 5.0+6.0im]
                p0 = [3.0+4.0im 7.0+8.0im]
                config = Configs.HamiltonianEndPointConfig(0.0, x0, p0, 1.0)
                rhs_oop = Systems.get_oop_rhs(sys, config)
                u = [1.0+2.0im 5.0+6.0im; 3.0+4.0im 7.0+8.0im]
                du = rhs_oop(u, p_param, 0.0)
                Test.@test du ≈ [1.0+2.0im 5.0+6.0im; -3.0-4.0im -7.0-8.0im] atol=1e-10
            end
        end

        # ====================================================================
        # UNIT TESTS - SVector unit
        # ====================================================================

        Test.@testset "SVector unit" begin
            hvf = Data.HamiltonianVectorField(
                (x, p) -> (x, -p); is_autonomous=true, is_variable=false
            )

            # Call hvf with SVector
            x = SA[1.0, 2.0]
            p = SA[3.0, 4.0]
            dx, dp = hvf(x, p)
            Test.@test dx == SA[1.0, 2.0]
            Test.@test dp == SA[-3.0, -4.0]

            # Call hvf with complex SVector
            x_c = SA[1.0 + 2.0im, 3.0 + 4.0im]
            p_c = SA[5.0 + 6.0im, 7.0 + 8.0im]
            dx_c, dp_c = hvf(x_c, p_c)
            Test.@test dx_c == SA[1.0 + 2.0im, 3.0 + 4.0im]
            Test.@test dp_c == SA[-5.0 - 6.0im, -7.0 - 8.0im]

            # Call get_oop_rhs with SVector (lazy builder)
            sys = Systems.HamiltonianVectorFieldSystem(hvf)
            x0 = SA[1.0, 2.0]
            p0 = SA[3.0, 4.0]
            config = Configs.HamiltonianEndPointConfig(0.0, x0, p0, 1.0)
            rhs_oop = Systems.get_oop_rhs(sys, config)
            u = SA[1.0, 2.0, 3.0, 4.0]
            p_param = Common.ODEParameters(nothing)
            du = rhs_oop(u, p_param, 0.0)
            Test.@test du == SA[1.0, 2.0, -3.0, -4.0]
            Test.@test du isa StaticArrays.SVector
        end

        # ====================================================================
        # UNIT TESTS - SMatrix / SVector _ham_split (only Int dispatch)
        # ====================================================================

        Test.@testset "Static _ham_split" begin
            # u = [X; P] with X = rows 1-2, P = rows 3-4 (column-major SMatrix{4,2})
            u_mat = SA[1.0 5.0; 2.0 6.0; 3.0 7.0; 4.0 8.0]
            u_vec = SA[1.0, 2.0, 3.0, 4.0]

            Test.@testset "SVector + N known" begin
                x, p = Systems._ham_split(u_vec, 2)
                Test.@test x == SA[1.0, 2.0]
                Test.@test p == SA[3.0, 4.0]
                Test.@test x isa StaticArrays.SVector
                Test.@test p isa StaticArrays.SVector
            end

            Test.@testset "SMatrix + N known" begin
                X, P = Systems._ham_split(u_mat, 2)
                Test.@test X == SA[1.0 5.0; 2.0 6.0]
                Test.@test P == SA[3.0 7.0; 4.0 8.0]
                Test.@test X isa StaticArrays.SMatrix
                Test.@test P isa StaticArrays.SMatrix
            end
        end

        # ====================================================================
        # UNIT TESTS - _ham_split
        # ====================================================================

        Test.@testset "_ham_split" begin
            # Vector + N known
            u_vec = [1.0, 2.0, 3.0, 4.0]
            x, pk = Systems._ham_split(u_vec, 2)
            Test.@test x == @view(u_vec[1:2])
            Test.@test pk == @view(u_vec[3:4])

            # Matrix + N known
            u_mat = [1.0 5.0; 2.0 6.0; 3.0 7.0; 4.0 8.0]
            x3, pk3 = Systems._ham_split(u_mat, 2)
            Test.@test x3 == @view(u_mat[1:2, :])
            Test.@test pk3 == @view(u_mat[3:4, :])
        end

        # ====================================================================
        # UNIT TESTS - _ham_assign!
        # ====================================================================

        Test.@testset "_ham_assign!" begin
            # Vector + N known
            du_vec = zeros(4)
            dx = [1.0, 2.0]
            dp = [-3.0, -4.0]
            Systems._ham_assign!(du_vec, dx, dp, 2)
            Test.@test du_vec == [1.0, 2.0, -3.0, -4.0]

            # Matrix + N known
            du_mat = zeros(4, 2)
            dx_mat = [1.0 5.0; 2.0 6.0]
            dp_mat = [-3.0 -7.0; -4.0 -8.0]
            Systems._ham_assign!(du_mat, dx_mat, dp_mat, 2)
            Test.@test du_mat == [1.0 5.0; 2.0 6.0; -3.0 -7.0; -4.0 -8.0]
        end

        # ====================================================================
        # UNIT TESTS - variable_costate_trait
        # ====================================================================

        Test.@testset "variable_costate_trait" begin
            # Fixed HVFSystem -> NoVariableCostate
            hvf_fixed = Data.HamiltonianVectorField(
                (x, p) -> (p, -x); is_autonomous=true, is_variable=false
            )
            sys_fixed = Systems.HamiltonianVectorFieldSystem(hvf_fixed)
            Test.@test Traits.variable_costate_trait(sys_fixed) === Traits.NoVariableCostate

            # NonFixed HVFSystem -> SupportsVariableCostate
            hvf_nonfixed = Data.HamiltonianVectorField(
                (x, p, v) -> (p ./ sum(v), -x); is_autonomous=true, is_variable=true
            )
            sys_nonfixed = Systems.HamiltonianVectorFieldSystem(hvf_nonfixed)
            Test.@test Traits.variable_costate_trait(sys_nonfixed) ===
                Traits.SupportsVariableCostate
        end

        # ====================================================================
        # UNIT TESTS - _aug_split and _aug_assign! (augmented)
        # ====================================================================

        Test.@testset "_aug_split" begin
            # Vector with n_x=2, n_v=1
            u_vec = [1.0, 2.0, 3.0, 4.0, 5.0]  # x=[1,2], p=[3,4], pv=[5]
            x, p, pv = Systems._aug_split(u_vec, 2, 1)
            Test.@test x == @view(u_vec[1:2])
            Test.@test p == @view(u_vec[3:4])
            Test.@test pv == @view(u_vec[5:5])

            # Matrix with n_x=2, n_v=1
            u_mat = [1.0 6.0; 2.0 7.0; 3.0 8.0; 4.0 9.0; 5.0 10.0]  # x=rows1-2, p=rows3-4, pv=row5
            x_m, p_m, pv_m = Systems._aug_split(u_mat, 2, 1)
            Test.@test x_m == @view(u_mat[1:2, :])
            Test.@test p_m == @view(u_mat[3:4, :])
            Test.@test pv_m == @view(u_mat[5:5, :])
        end

        Test.@testset "_aug_assign!" begin
            # Vector with n_x=2, n_v=1
            du_vec = zeros(5)
            dx = [1.0, 2.0]
            dp = [-3.0, -4.0]
            dpv = [5.0]
            Systems._aug_assign!(du_vec, dx, dp, dpv, 2, 1)
            Test.@test du_vec == [1.0, 2.0, -3.0, -4.0, 5.0]

            # Matrix with n_x=2, n_v=1
            du_mat = zeros(5, 2)
            dx_mat = [1.0 6.0; 2.0 7.0]
            dp_mat = [-3.0 -8.0; -4.0 -9.0]
            dpv_mat = [5.0 10.0]
            Systems._aug_assign!(du_mat, dx_mat, dp_mat, dpv_mat, 2, 1)
            Test.@test du_mat == [1.0 6.0; 2.0 7.0; -3.0 -8.0; -4.0 -9.0; 5.0 10.0]
        end

        # ====================================================================
        # UNIT TESTS - get_ip_rhs_augmented (just verify it builds without error)
        # ====================================================================

        Test.@testset "get_ip_rhs_augmented" begin
            # Simple test: just verify the function builds and can be called
            # without error. Full integration testing is done in test_variable_costate_flows.jl
            # OOP: signature is (x, p, v) for autonomous, (t, x, p, v) for non-autonomous
            hvf = Data.HamiltonianVectorField(
                (x, p, v) -> (p, -x); is_autonomous=true, is_variable=true
            )
            sys = Systems.HamiltonianVectorFieldSystem(hvf)

            Test.@testset "OOP builds" begin
                n_x, n_v = 2, 1
                x0, p0 = [1.0, 2.0], [3.0, 4.0]
                pv0 = [0.5]
                config = Configs.AugmentedHamiltonianEndPointConfig(0.0, x0, p0, pv0, 1.0)
                rhs_aug = Systems.get_ip_rhs_augmented(sys, config)
                Test.@test rhs_aug isa Systems.AbstractIPHVFRHS
            end

            Test.@testset "IP builds" begin
                # IP: signature is (dx, dp, x, p, v) for autonomous, (dx, dp, t, x, p, v) for non-autonomous
                hvf_ip = Data.HamiltonianVectorField(
                    (dx, dp, x, p, v; dpv=nothing, variable_costate::Bool=false) -> nothing;
                    is_autonomous=true,
                    is_variable=true,
                    is_inplace=true,
                )
                sys_ip = Systems.HamiltonianVectorFieldSystem(hvf_ip)
                n_x, n_v = 2, 1
                x0, p0 = [1.0, 2.0], [3.0, 4.0]
                pv0 = [0.5]
                config = Configs.AugmentedHamiltonianEndPointConfig(0.0, x0, p0, pv0, 1.0)
                rhs_aug_ip = Systems.get_ip_rhs_augmented(sys_ip, config)
                Test.@test rhs_aug_ip isa Systems.AbstractIPHVFRHS
            end
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
function test_hamiltonian_vector_field_system()
    return TestHamiltonianVectorFieldSystem.test_hamiltonian_vector_field_system()
end
