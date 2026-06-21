module TestPlotsExtension

import Test
import CTFlows: CTFlows
import CTFlows.Integrators: Integrators
import CTFlows.Trajectories: Trajectories

# Get extension to access plotting functions
using Plots
const CTFlowsPlots = Base.get_extension(CTFlows, :CTFlowsPlots)

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for testing
# ==============================================================================

"""
Fake integration result for testing plotting.
"""
struct FakePlotIntegrationResult{T} <: Integrators.AbstractIntegrationResult
    t::Vector{Float64}
    u::Vector{T}
end

Integrators.times(r::FakePlotIntegrationResult) = r.t

function Integrators.evaluate_at(r::FakePlotIntegrationResult, t::Real)
    idx = findfirst(==(t), r.t)
    return isnothing(idx) ? r.u[1] : r.u[idx]
end

# Make our FakePlotIntegrationResult callable so sol.(ts) works
function (r::FakePlotIntegrationResult)(t::Real)
    return Integrators.evaluate_at(r, t)
end

"""
Fake integration result for Hamiltonian solution testing.
"""
struct FakeHamiltonianPlotResult <: Integrators.AbstractIntegrationResult
    t::Vector{Float64}
    u::Vector{Vector{Float64}}
end

Integrators.times(r::FakeHamiltonianPlotResult) = r.t

function Integrators.evaluate_at(r::FakeHamiltonianPlotResult, t::Real)
    idx = findfirst(==(t), r.t)
    return isnothing(idx) ? r.u[1] : r.u[idx]
end

# Make our FakeHamiltonianPlotResult callable
function (r::FakeHamiltonianPlotResult)(t::Real)
    return Integrators.evaluate_at(r, t)
end

# ==============================================================================
# Test function
# ==============================================================================

function test_plots_extension()
    Test.@testset "Plots Extension" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Extension Loading
        # ====================================================================

        Test.@testset "Extension Loading" begin
            Test.@testset "extension is loaded" begin
                Test.@test !isnothing(CTFlowsPlots)
            end

            Test.@testset "extension is a Module" begin
                Test.@test CTFlowsPlots isa Module
            end
        end

        # ====================================================================
        # UNIT TESTS - Plot Functions Exist
        # ====================================================================

        Test.@testset "Plot Functions" begin
            Test.@testset "plot method exists" begin
                Test.@test isdefined(Plots, :plot)
            end

            Test.@testset "plot! method exists" begin
                Test.@test isdefined(Plots, :plot!)
            end
        end

        # ====================================================================
        # UNIT TESTS - Internal Helper _sol_to_arrays
        # ====================================================================

        Test.@testset "Internal Helper _sol_to_arrays" begin
            Test.@testset "vector state" begin
                fake_result = FakePlotIntegrationResult([0.0, 1.0], [[1.0, 2.0], [3.0, 4.0]])
                sol = Trajectories.VectorFieldSolution(fake_result)
                
                ts, states = CTFlowsPlots._sol_to_arrays(sol)
                Test.@test ts == [0.0, 1.0]
                Test.@test states == [1.0 2.0; 3.0 4.0]
            end

            Test.@testset "scalar state" begin
                fake_result = FakePlotIntegrationResult([0.0, 1.0], [1.0, 3.0])
                sol = Trajectories.VectorFieldSolution(fake_result)
                
                ts, states = CTFlowsPlots._sol_to_arrays(sol)
                Test.@test ts == [0.0, 1.0]
                Test.@test states == reshape([1.0, 3.0], 2, 1)
            end

            Test.@testset "uses semantic accessors" begin
                # Behavioral test: verify _sol_to_arrays works correctly
                # The implementation detail (using state) is verified by code review
                fake_result = FakePlotIntegrationResult([0.0, 0.5, 1.0], [[1.0], [0.5], [0.25]])
                sol = Trajectories.VectorFieldSolution(fake_result)
                
                ts, states = CTFlowsPlots._sol_to_arrays(sol)
                Test.@test length(ts) == 3
                Test.@test size(states) == (3, 1)
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - Plotting VectorFieldSolution
        # ====================================================================

        Test.@testset "VectorFieldSolution Plotting" begin
            Test.@testset "plot accepts VectorFieldSolution" begin
                fake_result = FakePlotIntegrationResult([0.0, 0.5, 1.0], [[1.0], [0.5], [0.25]])
                sol = Trajectories.VectorFieldSolution(fake_result)

                # Test that plot accepts the solution (may not actually plot without display)
                # We just verify it doesn't throw an error
                Test.@test_nowarn Plots.plot(sol, legend=false)
            end

            Test.@testset "plot! accepts VectorFieldSolution" begin
                fake_result = FakePlotIntegrationResult([0.0, 0.5, 1.0], [[1.0], [0.5], [0.25]])
                sol = Trajectories.VectorFieldSolution(fake_result)

                # Create a plot and plot! onto it
                p = Plots.plot([1, 2, 3])
                Test.@test_nowarn Plots.plot!(p, sol)
            end

            Test.@testset "plot!(p, sol) accepts VectorFieldSolution" begin
                fake_result = FakePlotIntegrationResult([0.0, 0.5, 1.0], [[1.0], [0.5], [0.25]])
                sol = Trajectories.VectorFieldSolution(fake_result)

                # Create a plot and plot! onto it with explicit plot object
                p = Plots.plot([1, 2, 3])
                Test.@test_nowarn Plots.plot!(p, sol)
            end
        end

        # ====================================================================
        # UNIT TESTS - Internal Helper _ham_sol_to_arrays
        # ====================================================================

        Test.@testset "Internal Helper _ham_sol_to_arrays" begin
            Test.@testset "scalar state and costate" begin
                fake_result = FakeHamiltonianPlotResult(
                    [0.0, 1.0],
                    [
                        [1.0, 5.0],
                        [3.0, 7.0],
                    ],
                )
                x0 = 1.0  # initial state
                sol = Trajectories.HamiltonianVectorFieldSolution(x0, fake_result)

                ts, states, costates = CTFlowsPlots._ham_sol_to_arrays(sol)
                Test.@test ts == [0.0, 1.0]
                Test.@test size(states) == (2, 1)
                Test.@test size(costates) == (2, 1)
                Test.@test states[:, 1] == [1.0, 3.0]
                Test.@test costates[:, 1] == [5.0, 7.0]
            end

            Test.@testset "vector state and costate" begin
                fake_result = FakeHamiltonianPlotResult(
                    [0.0, 1.0],
                    [
                        [1.0, 2.0, 5.0, 6.0],
                        [3.0, 4.0, 7.0, 8.0],
                    ],
                )
                x0 = [1.0, 2.0]  # initial state
                sol = Trajectories.HamiltonianVectorFieldSolution(x0, fake_result)

                ts, states, costates = CTFlowsPlots._ham_sol_to_arrays(sol)
                Test.@test ts == [0.0, 1.0]
                Test.@test size(states) == (2, 2)
                Test.@test size(costates) == (2, 2)
                Test.@test states == [1.0 2.0; 3.0 4.0]
                Test.@test costates == [5.0 6.0; 7.0 8.0]
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - Plotting HamiltonianVectorFieldSolution
        # ====================================================================

        Test.@testset "HamiltonianVectorFieldSolution Plotting" begin
            Test.@testset "plot accepts HamiltonianVectorFieldSolution" begin
                fake_result = FakeHamiltonianPlotResult(
                    [0.0, 0.5, 1.0],
                    [
                        [1.0, 2.0],
                        [0.5, 1.0],
                        [0.25, 0.5],
                    ],
                )
                x0 = 1.0  # initial state
                sol = Trajectories.HamiltonianVectorFieldSolution(x0, fake_result)

                Test.@test_nowarn Plots.plot(sol, legend=false)
            end

            Test.@testset "plot! accepts HamiltonianVectorFieldSolution" begin
                fake_result = FakeHamiltonianPlotResult(
                    [0.0, 0.5, 1.0],
                    [
                        [1.0, 2.0],
                        [0.5, 1.0],
                        [0.25, 0.5],
                    ],
                )
                x0 = 1.0  # initial state
                sol = Trajectories.HamiltonianVectorFieldSolution(x0, fake_result)

                p = Plots.plot([1, 2, 3])
                Test.@test_nowarn Plots.plot!(p, sol)
            end

            Test.@testset "plot!(p, sol) accepts HamiltonianVectorFieldSolution" begin
                fake_result = FakeHamiltonianPlotResult(
                    [0.0, 0.5, 1.0],
                    [
                        [1.0, 2.0],
                        [0.5, 1.0],
                        [0.25, 0.5],
                    ],
                )
                x0 = 1.0  # initial state
                sol = Trajectories.HamiltonianVectorFieldSolution(x0, fake_result)

                p = Plots.plot([1, 2, 3])
                Test.@test_nowarn Plots.plot!(p, sol)
            end
        end
    end
end

end # module

test_plots_extension() = TestPlotsExtension.test_plots_extension()