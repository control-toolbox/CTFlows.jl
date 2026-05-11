module TestHamiltonianVectorFieldSystem

import Test
import CTBase.Exceptions
import CTFlows.Data: Data
import CTFlows.Common: Common
import CTFlows.Systems: Systems
import CTFlows.Solutions: Solutions
import StaticArrays: SA, StaticArrays

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_hamiltonian_vector_field_system()
    Test.@testset "Hamiltonian Vector Field System Tests" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # ====================================================================
        # UNIT TESTS - Construction
        # ====================================================================
        
        Test.@testset "Construction" begin
            # From HamiltonianVectorField without dimension
            hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
            sys1 = Systems.HamiltonianVectorFieldSystem(hvf)
            Test.@test sys1 isa Systems.HamiltonianVectorFieldSystem
            Test.@test sys1 isa Systems.AbstractHamiltonianSystem
            Test.@test Systems.state_dimension(sys1) === nothing
            
            # From HamiltonianVectorField with dimension
            sys2 = Systems.HamiltonianVectorFieldSystem(hvf, 3)
            Test.@test sys2 isa Systems.HamiltonianVectorFieldSystem
            Test.@test Systems.state_dimension(sys2) == 3
        end
        
        # ====================================================================
        # UNIT TESTS - build_system
        # ====================================================================
        
        Test.@testset "build_system" begin
            hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
            
            # Without dimension
            sys1 = Systems.build_system(hvf)
            Test.@test sys1 isa Systems.HamiltonianVectorFieldSystem
            Test.@test Systems.state_dimension(sys1) === nothing
            
            # With dimension
            sys2 = Systems.build_system(hvf, 3)
            Test.@test sys2 isa Systems.HamiltonianVectorFieldSystem
            Test.@test Systems.state_dimension(sys2) == 3
        end
        
        # ====================================================================
        # UNIT TESTS - rhs (in-place)
        # ====================================================================
        
        Test.@testset "rhs" begin
            hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
            sys = Systems.HamiltonianVectorFieldSystem(hvf)
            
            rhs = Systems.rhs(sys)
            Test.@test rhs isa Function
            
            # Test RHS call with vector
            u = [1.0, 2.0, 3.0, 4.0]  # x = [1, 2], p = [3, 4]
            du = zeros(4)
            p = Common.ODEParameters(nothing)
            rhs(du, u, p, 0.0)
            
            # dx = x = [1, 2], dp = -p = [-3, -4]
            Test.@test du[1:2] == [1.0, 2.0]
            Test.@test du[3:4] == [-3.0, -4.0]

            # Test RHS call with matrix
            u_mat = [1.0 2.0; 3.0 4.0; 5.0 6.0; 7.0 8.0]  # x = [1 2; 3 4], p = [5 6; 7 8]
            du_mat = zeros(4, 2)
            rhs(du_mat, u_mat, p, 0.0)
            Test.@test du_mat ≈ [1.0 2.0; 3.0 4.0; -5.0 -6.0; -7.0 -8.0]  atol=1e-10
        end
        
        # ====================================================================
        # UNIT TESTS - rhs_oop (out-of-place)
        # ====================================================================
        
        Test.@testset "rhs_oop" begin
            hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
            sys = Systems.HamiltonianVectorFieldSystem(hvf)
            
            rhs_oop = Systems.rhs_oop(sys)
            Test.@test rhs_oop isa Function
            
            # Test RHS OOP call with vector
            u = [1.0, 2.0, 3.0, 4.0]  # x = [1, 2], p = [3, 4]
            p = Common.ODEParameters(nothing)
            du = rhs_oop(u, p, 0.0)
            
            # dx = x = [1, 2], dp = -p = [-3, -4]
            Test.@test du[1:2] == [1.0, 2.0]
            Test.@test du[3:4] == [-3.0, -4.0]

            # Test RHS OOP call with matrix
            u_mat = [1.0 2.0; 3.0 4.0; 5.0 6.0; 7.0 8.0]  # x = [1 2; 3 4], p = [5 6; 7 8]
            du_mat = rhs_oop(u_mat, p, 0.0)
            Test.@test du_mat ≈ [1.0 2.0; 3.0 4.0; -5.0 -6.0; -7.0 -8.0]  atol=1e-10
        end
        
        # ====================================================================
        # UNIT TESTS - Complex numbers
        # ====================================================================

        Test.@testset "Complex numbers" begin
            hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
            sys = Systems.HamiltonianVectorFieldSystem(hvf)
            rhs     = Systems.rhs(sys)
            rhs_oop = Systems.rhs_oop(sys)
            p_param = Common.ODEParameters(nothing)

            Test.@testset "rhs - complex vector" begin
                # x = [1+2im], p = [3+4im]  →  dx = x, dp = -p
                u  = [1.0+2.0im, 3.0+4.0im]
                du = zeros(ComplexF64, 2)
                rhs(du, u, p_param, 0.0)
                Test.@test du ≈ [1.0+2.0im, -3.0-4.0im]  atol=1e-10
            end

            Test.@testset "rhs_oop - complex vector" begin
                u  = [1.0+2.0im, 3.0+4.0im]
                du = rhs_oop(u, p_param, 0.0)
                Test.@test du ≈ [1.0+2.0im, -3.0-4.0im]  atol=1e-10
            end

            Test.@testset "rhs - complex matrix" begin
                # x = [1+2im  5+6im], p = [3+4im  7+8im]
                u  = [1.0+2.0im  5.0+6.0im; 3.0+4.0im  7.0+8.0im]
                du = zeros(ComplexF64, 2, 2)
                rhs(du, u, p_param, 0.0)
                # dx = x = rows 1, dp = -p = rows 2 negated
                Test.@test du ≈ [1.0+2.0im  5.0+6.0im; -3.0-4.0im  -7.0-8.0im]  atol=1e-10
            end

            Test.@testset "rhs_oop - complex matrix" begin
                u  = [1.0+2.0im  5.0+6.0im; 3.0+4.0im  7.0+8.0im]
                du = rhs_oop(u, p_param, 0.0)
                Test.@test du ≈ [1.0+2.0im  5.0+6.0im; -3.0-4.0im  -7.0-8.0im]  atol=1e-10
            end
        end

        # ====================================================================
        # UNIT TESTS - SVector unit
        # ====================================================================

        Test.@testset "SVector unit" begin
            hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)

            # Call hvf with SVector
            x = SA[1.0, 2.0]
            p = SA[3.0, 4.0]
            dx, dp = hvf(x, p)
            Test.@test dx == SA[1.0, 2.0]
            Test.@test dp == SA[-3.0, -4.0]

            # Call hvf with complex SVector
            x_c = SA[1.0+2.0im, 3.0+4.0im]
            p_c = SA[5.0+6.0im, 7.0+8.0im]
            dx_c, dp_c = hvf(x_c, p_c)
            Test.@test dx_c == SA[1.0+2.0im, 3.0+4.0im]
            Test.@test dp_c == SA[-5.0-6.0im, -7.0-8.0im]

            # Call rhs_oop with SVector and N=2 (type-stable with extension)
            sys = Systems.HamiltonianVectorFieldSystem(hvf, 2)
            rhs_oop = Systems.rhs_oop(sys)
            u = SA[1.0, 2.0, 3.0, 4.0]
            p_param = Common.ODEParameters(nothing)
            du = rhs_oop(u, p_param, 0.0)
            Test.@test du == SA[1.0, 2.0, -3.0, -4.0]
            Test.@test du isa StaticArrays.SVector
        end

        # ====================================================================
        # UNIT TESTS - SMatrix / SVector _ham_split (all 4 dispatch cases)
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

            Test.@testset "SVector + N nothing" begin
                x, p = Systems._ham_split(u_vec, nothing)
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

            Test.@testset "SMatrix + N nothing" begin
                X, P = Systems._ham_split(u_mat, nothing)
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

            # Vector + nothing
            x2, pk2 = Systems._ham_split(u_vec, nothing)
            Test.@test x2 == @view(u_vec[1:2])
            Test.@test pk2 == @view(u_vec[3:4])

            # Matrix + N known
            u_mat = [1.0 5.0; 2.0 6.0; 3.0 7.0; 4.0 8.0]
            x3, pk3 = Systems._ham_split(u_mat, 2)
            Test.@test x3 == @view(u_mat[1:2, :])
            Test.@test pk3 == @view(u_mat[3:4, :])

            # Matrix + nothing
            x4, pk4 = Systems._ham_split(u_mat, nothing)
            Test.@test x4 == @view(u_mat[1:2, :])
            Test.@test pk4 == @view(u_mat[3:4, :])
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
        # UNIT TESTS - rhs_oop stored
        # ====================================================================

        Test.@testset "rhs_oop stored" begin
            hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)

            # With N known
            sys1 = Systems.HamiltonianVectorFieldSystem(hvf, 2)
            Test.@test sys1.rhs_oop isa Function
            Test.@test Systems.rhs_oop(sys1) === sys1.rhs_oop

            # Without N
            sys2 = Systems.HamiltonianVectorFieldSystem(hvf)
            Test.@test sys2.rhs_oop isa Function
            Test.@test Systems.rhs_oop(sys2) === sys2.rhs_oop
        end

        # ====================================================================
        # UNIT TESTS - Validation
        # ====================================================================

        Test.@testset "Validation" begin
            hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)

            # System with known dimension
            sys = Systems.HamiltonianVectorFieldSystem(hvf, 3)

            # Correct dimension (vector)
            Test.@test Systems._check_state_dimension(sys, [1.0, 2.0, 3.0]) == true

            # Correct dimension (matrix - uses size(x0, 1))
            Test.@test Systems._check_state_dimension(sys, [1.0 2.0; 3.0 4.0; 5.0 6.0]) == true

            # Wrong dimension (vector)
            Test.@test_throws Exceptions.IncorrectArgument Systems._check_state_dimension(sys, [1.0, 2.0])

            # Wrong dimension (matrix - uses size(x0, 1))
            Test.@test_throws Exceptions.IncorrectArgument Systems._check_state_dimension(sys, [1.0 2.0; 3.0 4.0])

            # System without known dimension — dispatches to {nothing} method, always true
            sys_no_dim = Systems.HamiltonianVectorFieldSystem(hvf)
            Test.@test Systems._check_state_dimension(sys_no_dim, [1.0, 2.0, 3.0]) == true
            Test.@test Systems._check_state_dimension(sys_no_dim, [1.0 2.0; 3.0 4.0]) == true
        end

        # ====================================================================
        # UNIT TESTS - Base.show
        # ====================================================================
        
        Test.@testset "Base.show" begin
            hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
            
            # Without dimension
            sys1 = Systems.HamiltonianVectorFieldSystem(hvf)
            Test.@test_nowarn sprint(show, sys1)
            
            # With dimension
            sys2 = Systems.HamiltonianVectorFieldSystem(hvf, 3)
            Test.@test_nowarn sprint(show, sys2)
        end
        
        # ====================================================================
        # UNIT TESTS - Type parameter N
        # ====================================================================
        
        Test.@testset "Type parameter N" begin
            hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
            
            sys_with_n = Systems.HamiltonianVectorFieldSystem(hvf, 3)
            Test.@test Systems.state_dimension(sys_with_n) == 3
            
            sys_without_n = Systems.HamiltonianVectorFieldSystem(hvf)
            Test.@test Systems.state_dimension(sys_without_n) === nothing
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_hamiltonian_vector_field_system() = TestHamiltonianVectorFieldSystem.test_hamiltonian_vector_field_system()
