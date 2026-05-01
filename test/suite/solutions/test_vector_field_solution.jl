module TestVectorFieldSolution

import Test
import CTFlows.Solutions
import CTBase.Exceptions

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for testing
# ==============================================================================

"""
Fake ODE solution for testing VectorFieldSolution.
"""
struct FakeODESolution
    t::Vector{Float64}
    u::Vector{Vector{Float64}}
end

# ==============================================================================
# Test function
# ==============================================================================

function test_vector_field_solution()
    Test.@testset "VectorFieldSolution Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Construction
        # ====================================================================

        Test.@testset "Construction" begin
            Test.@testset "constructs from ODE solution" begin
                ode_sol = FakeODESolution([0.0, 0.5, 1.0], [[1.0], [0.5], [0.25]])
                sol = Solutions.VectorFieldSolution(ode_sol)
                Test.@test sol isa Solutions.VectorFieldSolution
            end
        end

        # ====================================================================
        # UNIT TESTS - raw getter
        # ====================================================================

        Test.@testset "raw getter" begin
            Test.@testset "returns underlying ODE solution" begin
                ode_sol = FakeODESolution([0.0, 0.5, 1.0], [[1.0], [0.5], [0.25]])
                sol = Solutions.VectorFieldSolution(ode_sol)
                Test.@test Solutions.raw(sol) === ode_sol
            end
        end

        # ====================================================================
        # UNIT TESTS - Callable
        # ====================================================================

        Test.@testset "Callable" begin
            Test.@testset "delegates to raw ODE solution" begin
                ode_sol = FakeODESolution([0.0, 0.5, 1.0], [[1.0], [0.5], [0.25]])
                sol = Solutions.VectorFieldSolution(ode_sol)
                # The callable should delegate to raw(sol)
                Test.@test sol(0.5) === ode_sol(0.5)
            end
        end

        # ====================================================================
        # UNIT TESTS - Plot stub
        # ====================================================================

        Test.@testset "Plot stub" begin
            Test.@testset "throws IncorrectArgument without Plots extension" begin
                ode_sol = FakeODESolution([0.0, 0.5, 1.0], [[1.0], [0.5], [0.25]])
                sol = Solutions.VectorFieldSolution(ode_sol)
                
                Test.@test_throws Exceptions.IncorrectArgument Solutions.plot(sol)
            end

            Test.@testset "error message mentions Plots extension" begin
                ode_sol = FakeODESolution([0.0, 0.5, 1.0], [[1.0], [0.5], [0.25]])
                sol = Solutions.VectorFieldSolution(ode_sol)
                
                try
                    Solutions.plot(sol)
                    Test.@test false  # Should not reach here
                catch err
                    Test.@test err isa Exceptions.IncorrectArgument
                    Test.@test occursin("Plots", err.msg)
                end
            end
        end

        # ====================================================================
        # UNIT TESTS - Base.show
        # ====================================================================

        Test.@testset "Base.show" begin
            Test.@testset "MIME text/plain" begin
                ode_sol = FakeODESolution([0.0, 1.0], [[1.0, 2.0], [0.5, 1.0]])
                sol = Solutions.VectorFieldSolution(ode_sol)
                
                io = IOBuffer()
                show(io, MIME("text/plain"), sol)
                output = String(take!(io))
                Test.@test occursin("VectorFieldSolution", output)
            end

            Test.@testset "compact" begin
                ode_sol = FakeODESolution([0.0, 1.0], [[1.0, 2.0], [0.5, 1.0]])
                sol = Solutions.VectorFieldSolution(ode_sol)
                
                io = IOBuffer()
                show(io, sol)
                output = String(take!(io))
                Test.@test occursin("VectorFieldSolution", output)
            end
        end

        # ====================================================================
        # UNIT TESTS - Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "VectorFieldSolution is exported" begin
                Test.@test isdefined(Solutions, :VectorFieldSolution)
            end

            Test.@testset "raw is exported" begin
                Test.@test isdefined(Solutions, :raw)
            end
        end
    end
end

end # module

test_vector_field_solution() = TestVectorFieldSolution.test_vector_field_solution()