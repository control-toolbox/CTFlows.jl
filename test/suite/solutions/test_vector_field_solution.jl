module TestVectorFieldSolution

import Test
import CTFlows.Solutions
import CTBase.Exceptions
import CTFlows.Common

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for testing
# ==============================================================================

"""
Fake integration result for testing VectorFieldSolution callable interface.
"""
struct FakeIntegrationResult <: Solutions.AbstractIntegrationResult
    t::Vector{Float64}
    u::Vector{Vector{Float64}}
end

Solutions.times(r::FakeIntegrationResult) = r.t
Solutions.final_state(r::FakeIntegrationResult) = r.u[end]
function Solutions.evaluate_at(r::FakeIntegrationResult, t::Real)
    # Simple interpolation for testing
    return r.u[1]
end

"""
Fake VectorFieldSolution for testing stub methods on AbstractVectorFieldSolution.
"""
struct FakeVectorFieldSolution <: Solutions.AbstractVectorFieldSolution
    data::String
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
            Test.@testset "constructs from integration result" begin
                result = FakeIntegrationResult([0.0, 0.5, 1.0], [[1.0], [0.5], [0.25]])
                sol = Solutions.VectorFieldSolution(result)
                Test.@test sol isa Solutions.VectorFieldSolution
            end
        end

        # ====================================================================
        # UNIT TESTS - Callable & Delegation
        # ====================================================================

        Test.@testset "Callable & Delegation" begin
            Test.@testset "delegates evaluate_at to result" begin
                result = FakeIntegrationResult([0.0, 0.5, 1.0], [[1.0], [0.5], [0.25]])
                sol = Solutions.VectorFieldSolution(result)
                Test.@test sol(0.5) === Solutions.evaluate_at(result, 0.5)
            end

            Test.@testset "delegates times to result" begin
                result = FakeIntegrationResult([0.0, 0.5, 1.0], [[1.0], [0.5], [0.25]])
                sol = Solutions.VectorFieldSolution(result)
                Test.@test Solutions.times(sol) === Solutions.times(result)
            end

            Test.@testset "state accessor returns sol itself" begin
                result = FakeIntegrationResult([0.0, 0.5, 1.0], [[1.0], [0.5], [0.25]])
                sol = Solutions.VectorFieldSolution(result)
                x = Solutions.state(sol)
                Test.@test x === sol  # Returns same object
            end

            Test.@testset "state accessor is callable" begin
                result = FakeIntegrationResult([0.0, 0.5, 1.0], [[1.0], [0.5], [0.25]])
                sol = Solutions.VectorFieldSolution(result)
                x = Solutions.state(sol)
                Test.@test x(0.5) ≈ Solutions.evaluate_at(result, 0.5)
            end

            Test.@testset "time_grid alias works" begin
                result = FakeIntegrationResult([0.0, 0.5, 1.0], [[1.0], [0.5], [0.25]])
                sol = Solutions.VectorFieldSolution(result)
                tg = Solutions.time_grid(sol)
                ts = Solutions.times(sol)
                Test.@test tg === ts  # Returns same object
            end
        end

        # ====================================================================
        # UNIT TESTS - Plot stub
        # ====================================================================

        Test.@testset "Plot stub" begin
            Test.@testset "throws ExtensionError without Plots extension" begin
                fake_sol = FakeVectorFieldSolution("test data")
                
                Test.@test_throws Exceptions.ExtensionError Solutions.plot(fake_sol)
            end

            Test.@testset "error message mentions Plots extension" begin
                fake_sol = FakeVectorFieldSolution("test data")
                
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

        # ====================================================================
        # UNIT TESTS - Base.show
        # ====================================================================

        Test.@testset "Base.show" begin
            Test.@testset "MIME text/plain" begin
                result = FakeIntegrationResult([0.0, 1.0], [[1.0, 2.0], [0.5, 1.0]])
                sol = Solutions.VectorFieldSolution(result)
                
                io = IOBuffer()
                show(io, MIME("text/plain"), sol)
                output = String(take!(io))
                Test.@test occursin("VectorFieldSolution", output)
            end

            Test.@testset "compact" begin
                result = FakeIntegrationResult([0.0, 1.0], [[1.0, 2.0], [0.5, 1.0]])
                sol = Solutions.VectorFieldSolution(result)
                
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
        end
    end
end

end # module

test_vector_field_solution() = TestVectorFieldSolution.test_vector_field_solution()