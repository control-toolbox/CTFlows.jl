module TestConcatenationSciML

import Test
import CTFlows.MultiPhase
import CTFlows.Systems
import CTFlows.Integrators
import CTFlows.Flows
import CTFlows.Data
import CTFlows.Common

using OrdinaryDiffEqTsit5

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

    end
end

end # module

test_concatenation_sciml() = TestConcatenationSciML.test_concatenation_sciml()