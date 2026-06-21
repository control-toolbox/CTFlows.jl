module TestVectorFieldTrajectory

import Test
import CTFlows.Trajectories
import CTBase.Exceptions
import CTFlows.Common
import CTFlows.Integrators

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for testing
# ==============================================================================

"""
Fake integration result for testing VectorFieldTrajectory callable interface.
"""
struct FakeIntegrationResult <: Integrators.AbstractIntegrationResult
    t::Vector{Float64}
    u::Vector{Vector{Float64}}
end

Integrators.times(r::FakeIntegrationResult) = r.t
Integrators.final_state(r::FakeIntegrationResult) = r.u[end]
function Integrators.evaluate_at(r::FakeIntegrationResult, t::Real)
    # Simple interpolation for testing
    return r.u[1]
end

"""
Fake VectorFieldTrajectory for testing stub methods on AbstractVectorFieldTrajectory.
"""
struct FakeVectorFieldTrajectory <: Trajectories.AbstractVectorFieldTrajectory
    data::String
end

# ==============================================================================
# Test function
# ==============================================================================

function test_vector_field_trajectory()
    Test.@testset "VectorFieldTrajectory Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Construction
        # ====================================================================

        Test.@testset "Construction" begin
            Test.@testset "constructs from integration result" begin
                result = FakeIntegrationResult([0.0, 0.5, 1.0], [[1.0], [0.5], [0.25]])
                sol = Trajectories.VectorFieldTrajectory(result)
                Test.@test sol isa Trajectories.VectorFieldTrajectory
            end
        end

        # ====================================================================
        # UNIT TESTS - Callable & Delegation
        # ====================================================================

        Test.@testset "Callable & Delegation" begin
            Test.@testset "delegates evaluate_at to result" begin
                result = FakeIntegrationResult([0.0, 0.5, 1.0], [[1.0], [0.5], [0.25]])
                sol = Trajectories.VectorFieldTrajectory(result)
                Test.@test sol(0.5) === Integrators.evaluate_at(result, 0.5)
            end

            Test.@testset "delegates times to result" begin
                result = FakeIntegrationResult([0.0, 0.5, 1.0], [[1.0], [0.5], [0.25]])
                sol = Trajectories.VectorFieldTrajectory(result)
                Test.@test Integrators.times(sol) === Integrators.times(result)
            end

            Test.@testset "state accessor returns sol itself" begin
                result = FakeIntegrationResult([0.0, 0.5, 1.0], [[1.0], [0.5], [0.25]])
                sol = Trajectories.VectorFieldTrajectory(result)
                x = Trajectories.state(sol)
                Test.@test x === sol  # Returns same object
            end

            Test.@testset "state accessor is callable" begin
                result = FakeIntegrationResult([0.0, 0.5, 1.0], [[1.0], [0.5], [0.25]])
                sol = Trajectories.VectorFieldTrajectory(result)
                x = Trajectories.state(sol)
                Test.@test x(0.5) ≈ Integrators.evaluate_at(result, 0.5)
            end

            Test.@testset "time_grid alias works" begin
                result = FakeIntegrationResult([0.0, 0.5, 1.0], [[1.0], [0.5], [0.25]])
                sol = Trajectories.VectorFieldTrajectory(result)
                tg = Trajectories.time_grid(sol)
                ts = Integrators.times(sol)
                Test.@test tg === ts  # Returns same object
            end
        end

        # ====================================================================
        # UNIT TESTS - Plot stub
        # ====================================================================

        Test.@testset "Plot stub" begin
            Test.@testset "throws ExtensionError without Plots extension" begin
                fake_sol = FakeVectorFieldTrajectory("test data")
                
                Test.@test_throws Exceptions.ExtensionError Trajectories.plot(fake_sol)
            end

            Test.@testset "error message mentions Plots extension" begin
                fake_sol = FakeVectorFieldTrajectory("test data")
                
                try
                    Trajectories.plot(fake_sol)
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
                sol = Trajectories.VectorFieldTrajectory(result)
                
                io = IOBuffer()
                show(io, MIME("text/plain"), sol)
                output = String(take!(io))
                Test.@test occursin("VectorFieldTrajectory", output)
            end

            Test.@testset "compact" begin
                result = FakeIntegrationResult([0.0, 1.0], [[1.0, 2.0], [0.5, 1.0]])
                sol = Trajectories.VectorFieldTrajectory(result)
                
                io = IOBuffer()
                show(io, sol)
                output = String(take!(io))
                Test.@test occursin("VectorFieldTrajectory", output)
            end
        end

        # ====================================================================
        # UNIT TESTS - Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "VectorFieldTrajectory is exported" begin
                Test.@test isdefined(Trajectories, :VectorFieldTrajectory)
            end
        end
    end
end

end # module

test_vector_field_trajectory() = TestVectorFieldTrajectory.test_vector_field_trajectory()