module TestConcatenationSciML

import Test
import CTFlows.MultiPhase
import CTFlows.Systems
import CTFlows.Integrators
import CTFlows.Flows
import CTFlows.Data
import CTFlows.Common
import CTFlows.Solutions

using OrdinaryDiffEqTsit5
using Plots

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Test function
# ==============================================================================

function test_concatenation_sciml()
    Test.@testset "Concatenation with SciML Integration" verbose=VERBOSE showtiming=SHOWTIMING begin

        # Linear system: dx/dt = -x, solution: x(t) = x0 * exp(-t)
        linear_oop(u) = -u

        Test.@testset "Two-phase linear system" begin
            vf = Data.VectorField(linear_oop)
            sys = Systems.VectorFieldSystem(vf)
            integ = Integrators.SciML()
            flow1 = Flows.StateFlow(sys, integ)
            flow2 = Flows.StateFlow(sys, integ)

            mpf = flow1 * (0.5, flow2)

            t0 = 0.0; tf = 1.0; x0 = [1.0]
            xf = mpf(t0, x0, tf)

            Test.@test xf[1] ≈ exp(-1.0) atol = 1e-3
        end

        Test.@testset "Jump at switching time" begin
            vf = Data.VectorField(linear_oop)
            sys = Systems.VectorFieldSystem(vf)
            integ = Integrators.SciML()

            f = Flows.StateFlow(sys, integ)
            jump = 10.0

            mpf = f * (0.5, jump, f)

            x0 = [1.0]
            xf = mpf(0.0, x0, 1.0)

            expected = (exp(-0.5) + 10.0) * exp(-0.5)

            Test.@test xf[1] ≈ expected atol = 1e-3
        end

        Test.@testset "Three-phase consistency" begin
            vf = Data.VectorField(linear_oop)
            sys = Systems.VectorFieldSystem(vf)
            integ = Integrators.SciML()

            f = Flows.StateFlow(sys, integ)

            mpf = f * (0.3, f) * (0.7, f)

            x0 = [2.0]
            xf = mpf(0.0, x0, 1.0)

            Test.@test xf[1] ≈ 2.0 * exp(-1.0) atol = 1e-4
        end

        Test.@testset "Trajectory merging" begin
            vf = Data.VectorField(linear_oop)
            sys = Systems.VectorFieldSystem(vf)
            integ = Integrators.SciML()

            f = Flows.StateFlow(sys, integ)
            mpf = f * (0.5, f)

            sol = mpf((0.0, 1.0), [1.0])

            # sol is VectorFieldSolution, use accessors
            xf = Integrators.final_state(sol)
            Test.@test xf[1] ≈ exp(-1.0) atol = 1e-4

            ts = Integrators.times(sol)
            for t in ts
                u = sol(t)  # Evaluate at time t
                Test.@test u[1] ≈ exp(-t) atol = 1e-3
            end
        end

        Test.@testset "Trajectory with jump discontinuity" begin
            vf = Data.VectorField(linear_oop)
            sys = Systems.VectorFieldSystem(vf)
            integ = Integrators.SciML()

            f = Flows.StateFlow(sys, integ)
            mpf = f * (0.5, 5.0, f)

            sol = mpf((0.0, 1.0), [1.0])

            # Verify discontinuity at switching time
            t_switch = 0.5
            u_before = sol(t_switch - 1e-6)
            u_after = sol(t_switch + 1e-6)

            # After jump, state should be increased by 5.0
            expected_before = exp(-0.5)
            expected_after = expected_before + 5.0

            Test.@test u_before[1] ≈ expected_before atol = 1e-3
            Test.@test u_after[1] ≈ expected_after atol = 1e-3
        end

        Test.@testset "Multiple jumps" begin
            vf = Data.VectorField(linear_oop)
            sys = Systems.VectorFieldSystem(vf)
            integ = Integrators.SciML()

            f = Flows.StateFlow(sys, integ)
            mpf = f * (0.3, 2.0, f) * (0.6, 3.0, f)

            x0 = [1.0]
            xf = mpf(0.0, x0, 1.0)

            # Expected: x0*exp(-0.3) + 2, then (x0*exp(-0.3)+2)*exp(-0.3) + 3, then *exp(-0.4)
            expected = ((1.0 * exp(-0.3) + 2.0) * exp(-0.3) + 3.0) * exp(-0.4)

            Test.@test xf[1] ≈ expected atol = 1e-3
        end

        Test.@testset "Jump is 0" begin
            vf = Data.VectorField(linear_oop)
            sys = Systems.VectorFieldSystem(vf)
            integ = Integrators.SciML()

            f = Flows.StateFlow(sys, integ)
            mpf = f * (0.5, 0.0, f)

            x0 = [1.0]
            xf = mpf(0.0, x0, 1.0)

            # With zero jump, should be same as no jump
            Test.@test xf[1] ≈ exp(-1.0) atol = 1e-4
        end

        Test.@testset "Switch after final time" begin
            vf = Data.VectorField(linear_oop)
            sys = Systems.VectorFieldSystem(vf)
            integ = Integrators.SciML()

            f = Flows.StateFlow(sys, integ)
            # Switch at 2.0, but final time is 1.0 - switch should be ignored
            mpf = f * (2.0, f)

            x0 = [1.0]
            xf = mpf(0.0, x0, 1.0)

            # Should behave like single flow since switch is after final time
            Test.@test xf[1] ≈ exp(-1.0) atol = 1e-4
        end

        Test.@testset "Equivalence with SciML callback" begin
            vf = Data.VectorField(linear_oop)
            sys = Systems.VectorFieldSystem(vf)
            integ = Integrators.SciML()

            f = Flows.StateFlow(sys, integ)
            jump_value = 5.0
            mpf = f * (0.5, jump_value, f)

            x0 = [1.0]
            xf_mpf = mpf(0.0, x0, 1.0)

            # Expected value with jump
            expected = (exp(-0.5) + jump_value) * exp(-0.5)
            Test.@test xf_mpf[1] ≈ expected atol = 1e-3
        end

        Test.@testset "TrajectoryConfig and plot" begin
            vf = Data.VectorField(linear_oop)
            sys = Systems.VectorFieldSystem(vf)
            integ = Integrators.SciML()

            f = Flows.StateFlow(sys, integ)
            mpf = f * (0.5, f)

            # Call with tspan (TrajectoryConfig)
            sol = mpf((0.0, 1.0), [1.0])

            # Verify it's a VectorFieldSolution
            Test.@test sol isa Solutions.VectorFieldSolution

            # Test plot function
            p = plot(sol; label="x(t)", title="Trajectory")
            Test.@test p isa Plots.Plot
        end

    end
end

end # module

test_concatenation_sciml() = TestConcatenationSciML.test_concatenation_sciml()