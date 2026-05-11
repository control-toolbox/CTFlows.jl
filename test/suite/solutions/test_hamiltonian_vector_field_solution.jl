module TestHamiltonianVectorFieldSolution

import Test
import CTFlows.Integrators: Integrators
import CTFlows.Solutions: Solutions
import CTBase.Exceptions

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# =============================================================================
# Fake integration result for testing
# =============================================================================

struct FakeHamiltonianResult <: Integrators.AbstractIntegrationResult
    final_u::Vector{Float64}
    ts::Vector{Float64}
    us::Vector{Vector{Float64}}
end

# =============================================================================
# Fake HamiltonianVectorFieldSolution for testing plot stub
# =============================================================================

struct FakeHamiltonianVectorFieldSolution <: Solutions.AbstractHamiltonianVectorFieldSolution
    data::String
end

Integrators.final_state(r::FakeHamiltonianResult) = r.final_u
Integrators.times(r::FakeHamiltonianResult) = r.ts
function Integrators.evaluate_at(r::FakeHamiltonianResult, t::Real)
    idx = findfirst(≥(t), r.ts)
    if isnothing(idx)
        idx = length(r.ts)
    end
    return r.us[idx]
end

function test_hamiltonian_vector_field_solution()
    Test.@testset "Hamiltonian Vector Field Solution Tests" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # ====================================================================
        # UNIT TESTS - Construction
        # ====================================================================
        
        Test.@testset "Construction" begin
            result = FakeHamiltonianResult([1.0, 2.0, 3.0, 4.0], [0.0, 0.5, 1.0], [[1, 2, 3, 4], [1.5, 2.5, 3.5, 4.5], [2, 3, 4, 5]])
            sol = Solutions.HamiltonianVectorFieldSolution(result)
            Test.@test sol isa Solutions.HamiltonianVectorFieldSolution
            Test.@test sol isa Solutions.AbstractHamiltonianVectorFieldSolution
        end
        
        # ====================================================================
        # UNIT TESTS - sol(t) returns tuple
        # ====================================================================
        
        Test.@testset "sol(t) returns tuple" begin
            result = FakeHamiltonianResult([1.0, 2.0, 3.0, 4.0], [0.0, 0.5, 1.0], [[1, 2, 3, 4], [1.5, 2.5, 3.5, 4.5], [2, 3, 4, 5]])
            sol = Solutions.HamiltonianVectorFieldSolution(result)
            
            x, p = sol(0.0)
            Test.@test x == [1.0, 2.0]
            Test.@test p == [3.0, 4.0]
            
            x, p = sol(0.5)
            Test.@test x == [1.5, 2.5]
            Test.@test p == [3.5, 4.5]
            
            x, p = sol(1.0)
            Test.@test x == [2.0, 3.0]
            Test.@test p == [4.0, 5.0]
        end
        
        # ====================================================================
        # UNIT TESTS - state and costate accessors
        # ====================================================================
        
        Test.@testset "state and costate accessors" begin
            result = FakeHamiltonianResult([1.0, 2.0, 3.0, 4.0], [0.0, 0.5, 1.0], [[1, 2, 3, 4], [1.5, 2.5, 3.5, 4.5], [2, 3, 4, 5]])
            sol = Solutions.HamiltonianVectorFieldSolution(result)
            
            x_func = Solutions.state(sol)
            Test.@test x_func isa Function
            Test.@test x_func(0.0) == [1.0, 2.0]
            
            p_func = Solutions.costate(sol)
            Test.@test p_func isa Function
            Test.@test p_func(0.0) == [3.0, 4.0]
        end
        
        # ====================================================================
        # UNIT TESTS - final_state
        # ====================================================================
        
        Test.@testset "final_state" begin
            result = FakeHamiltonianResult([1.0, 2.0, 3.0, 4.0], [0.0, 0.5, 1.0], [[1, 2, 3, 4], [1.5, 2.5, 3.5, 4.5], [2, 3, 4, 5]])
            sol = Solutions.HamiltonianVectorFieldSolution(result)
            
            x, p = Integrators.final_state(sol)
            Test.@test x == [1.0, 2.0]
            Test.@test p == [3.0, 4.0]
        end
        
        # ====================================================================
        # UNIT TESTS - time_grid
        # ====================================================================
        
        Test.@testset "time_grid" begin
            result = FakeHamiltonianResult([1.0, 2.0, 3.0, 4.0], [0.0, 0.5, 1.0], [[1, 2, 3, 4], [1.5, 2.5, 3.5, 4.5], [2, 3, 4, 5]])
            sol = Solutions.HamiltonianVectorFieldSolution(result)
            
            tg = Solutions.time_grid(sol)
            Test.@test tg == [0.0, 0.5, 1.0]
        end
        
        # ====================================================================
        # UNIT TESTS - Plot stub
        # ====================================================================
        
        Test.@testset "Plot stub" begin
            Test.@testset "throws ExtensionError without Plots extension" begin
                fake_sol = FakeHamiltonianVectorFieldSolution("test data")
                
                Test.@test_throws Exceptions.ExtensionError Solutions.plot(fake_sol)
            end
            
            Test.@testset "error message mentions Plots extension" begin
                fake_sol = FakeHamiltonianVectorFieldSolution("test data")
                
                try
                    Solutions.plot(fake_sol)
                    Test.@test false  # Should not reach here
                catch err
                    Test.@test err isa Exceptions.ExtensionError
                    msg = sprint(showerror, err)
                    Test.@test occursin("Plots", msg)
                end
            end
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_hamiltonian_vector_field_solution() = TestHamiltonianVectorFieldSolution.test_hamiltonian_vector_field_solution()
