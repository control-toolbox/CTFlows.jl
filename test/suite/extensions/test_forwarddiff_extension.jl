module TestForwardDiffExtension

import Test
import CTFlows: CTFlows
import CTBase.Data: Data
import CTFlows.Integrators: Integrators
import CTFlows.Flows: Flows

using SciMLBase: SciMLBase
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, Tsit5
using ForwardDiff: ForwardDiff

const CTFlowsSciMLFlows = Base.get_extension(CTFlows, :CTFlowsSciMLFlows)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# CTFlows-level grid-invariance (IND) test through the Flow API with ForwardDiff.
#
# The grid-invariance helpers (`deepvalue`/`real_norm`, including the ForwardDiff
# `Dual` overloads) live in `CTSolvers.Integrators` and are unit-tested there. Here
# we only check the CTFlows-visible guarantee: differentiating a `Flow` with
# ForwardDiff must not change the integration grid (the SciML integrator's default
# `internalnorm` ignores the dual parts, via the `CTSolversForwardDiff` extension).
# ==============================================================================

function test_forwarddiff_extension()
    Test.@testset "ForwardDiff Extension Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        Test.@testset "Extension availability" begin
            Test.@test !isnothing(CTFlowsSciMLFlows)
            Test.@test CTFlowsSciMLFlows isa Module
        end

        Test.@testset "Flow API grid invariance" begin
            # Simple ODE: ẋ = x
            vf = Data.VectorField(x -> x; is_autonomous=true, is_variable=false)
            flow = Flows.Flow(vf; save_everystep=true)

            # Integration with real numbers
            result_real = flow((0.0, 1.0), [1.0])
            t_real = Integrators.times(result_real)

            # Integration with Dual (Jacobian w.r.t. initial condition)
            result_dual = flow((0.0, 1.0), ForwardDiff.Dual{:T}.([1.0], [1.0]))
            t_dual = ForwardDiff.value.(Integrators.times(result_dual))

            # Real part of dual solution must match real solution
            x_real = Integrators.final_state(result_real)
            x_dual = ForwardDiff.value.(Integrators.final_state(result_dual))
            Test.@test x_real == x_dual

            # Grids must be identical with real_norm (the integrator's default)
            Test.@test t_real == t_dual
        end
    end
end

end # module

test_forwarddiff_extension() = TestForwardDiffExtension.test_forwarddiff_extension()
