module TestHamiltonianVectorFieldSystem

import Test
import CTBase.Exceptions
import CTFlows.Data: Data
import CTFlows.Common: Common
import CTFlows.Systems: Systems
import CTFlows.Solutions: Solutions
import StaticArrays: SA

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
            
            # Test RHS call
            u = [1.0, 2.0, 3.0, 4.0]  # x = [1, 2], p = [3, 4]
            du = zeros(4)
            p = Common.ODEParameters(nothing)
            rhs(du, u, p, 0.0)
            
            # dx = x = [1, 2], dp = -p = [-3, -4]
            Test.@test du[1:2] == [1.0, 2.0]
            Test.@test du[3:4] == [-3.0, -4.0]
        end
        
        # ====================================================================
        # UNIT TESTS - rhs_oop (out-of-place)
        # ====================================================================
        
        Test.@testset "rhs_oop" begin
            hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
            sys = Systems.HamiltonianVectorFieldSystem(hvf)
            
            rhs_oop = Systems.rhs_oop(sys)
            Test.@test rhs_oop isa Function
            
            # Test RHS OOP call
            u = [1.0, 2.0, 3.0, 4.0]  # x = [1, 2], p = [3, 4]
            p = Common.ODEParameters(nothing)
            du = rhs_oop(u, p, 0.0)
            
            # dx = x = [1, 2], dp = -p = [-3, -4]
            Test.@test du[1:2] == [1.0, 2.0]
            Test.@test du[3:4] == [-3.0, -4.0]
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
            
            # Call rhs_oop with SVector
            sys = Systems.HamiltonianVectorFieldSystem(hvf)
            rhs_oop = Systems.rhs_oop(sys)
            u = SA[1.0, 2.0, 3.0, 4.0]
            p_param = Common.ODEParameters(nothing)
            du = rhs_oop(u, p_param, 0.0)
            Test.@test du == SA[1.0, 2.0, -3.0, -4.0]
        end
        
        # ====================================================================
        # UNIT TESTS - Validation
        # ====================================================================
        
        Test.@testset "Validation" begin
            hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
            
            # System with known dimension
            sys = Systems.HamiltonianVectorFieldSystem(hvf, 3)
            
            # Correct dimension
            Test.@test Systems._check_state_dimension(sys, [1.0, 2.0, 3.0]) == true
            
            # Wrong dimension
            Test.@test_throws Exceptions.IncorrectArgument Systems._check_state_dimension(sys, [1.0, 2.0])
            
            # System without known dimension - should skip validation
            sys_no_dim = Systems.HamiltonianVectorFieldSystem(hvf)
            Test.@test Systems._check_state_dimension(sys_no_dim, [1.0, 2.0, 3.0]) == true
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
        
        # ====================================================================
        # UNIT TESTS - Validation
        # ====================================================================
        
        Test.@testset "Validation" begin
            hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
            
            # System with known dimension
            sys = Systems.HamiltonianVectorFieldSystem(hvf, 3)
            
            # Correct dimension
            Test.@test Systems._check_state_dimension(sys, [1.0, 2.0, 3.0]) == true
            
            # Wrong dimension
            Test.@test_throws Exceptions.IncorrectArgument Systems._check_state_dimension(sys, [1.0, 2.0])
            
            # System without known dimension - should skip validation
            sys_no_dim = Systems.HamiltonianVectorFieldSystem(hvf)
            Test.@test Systems._check_state_dimension(sys_no_dim, [1.0, 2.0, 3.0]) == true
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_hamiltonian_vector_field_system() = TestHamiltonianVectorFieldSystem.test_hamiltonian_vector_field_system()
