module TestPlotsExtension

import Test
import CTFlows: CTFlows
import CTFlows.Solutions: Solutions

# Get extension to access plotting functions
using Plots: Plots
const CTFlowsPlotsExt = Base.get_extension(CTFlows, :CTFlowsPlotsExt)

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for testing
# ==============================================================================

"""
Fake ODE solution for testing plotting.
"""
struct FakeODESolution
    t::Vector{Float64}
    u::Vector{Vector{Float64}}
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
                Test.@test !isnothing(CTFlowsPlotsExt)
            end

            Test.@testset "extension is a Module" begin
                Test.@test CTFlowsPlotsExt isa Module
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
        # INTEGRATION TESTS - Plotting VectorFieldSolution
        # ====================================================================

        Test.@testset "VectorFieldSolution Plotting" begin
            Test.@testset "plot accepts VectorFieldSolution" begin
                ode_sol = FakeODESolution([0.0, 0.5, 1.0], [[1.0], [0.5], [0.25]])
                sol = Solutions.VectorFieldSolution(ode_sol)

                # Test that plot accepts the solution (may not actually plot without display)
                # We just verify it doesn't throw an error
                Test.@test_nowarn Plots.plot(sol, legend=false)
            end

            Test.@testset "plot! accepts VectorFieldSolution" begin
                ode_sol = FakeODESolution([0.0, 0.5, 1.0], [[1.0], [0.5], [0.25]])
                sol = Solutions.VectorFieldSolution(ode_sol)

                # Create a plot and plot! onto it
                p = Plots.plot([1, 2, 3])
                Test.@test_nowarn Plots.plot!(p, sol)
            end

            Test.@testset "plot!(p, sol) accepts VectorFieldSolution" begin
                ode_sol = FakeODESolution([0.0, 0.5, 1.0], [[1.0], [0.5], [0.25]])
                sol = Solutions.VectorFieldSolution(ode_sol)

                # Create a plot and plot! onto it with explicit plot object
                p = Plots.plot([1, 2, 3])
                Test.@test_nowarn Plots.plot!(p, sol)
            end
        end
    end
end

end # module

test_plots_extension() = TestPlotsExtension.test_plots_extension()