module TestForwardDiffExtension

using Test: Test
using CTFlows: CTFlows
using CTBase: Data
using CTFlows: Integrators
using CTFlows: Flows

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
            x0_dual = ForwardDiff.Dual{:T}.([1.0], [1.0])   # Jacobian w.r.t. the initial condition

            # The integration grid is the solver steps: `grid=nothing` (the default output
            # grid is generated from the interpolant, see below).
            result_real = flow((0.0, 1.0), [1.0]; grid=nothing)
            result_dual = flow((0.0, 1.0), x0_dual; grid=nothing)
            t_real = Integrators.times(result_real)
            t_dual = ForwardDiff.value.(Integrators.times(result_dual))

            # Real part of dual solution must match real solution
            x_real = Integrators.final_state(result_real)
            x_dual = ForwardDiff.value.(Integrators.final_state(result_dual))
            Test.@test x_real == x_dual

            # Grids must be identical with real_norm (the integrator's default)
            Test.@test t_real == t_dual
        end

        Test.@testset "Default output grid is not bit-reproducible across Float64 and Dual" begin
            # The default output grid (issue #446) is generated from the dense interpolant,
            # whose Float64 and Dual evaluations may differ by an ulp (compiler contraction of
            # the Tsit5 interpolation; platform and `--check-bounds` dependent), and the
            # adaptive grid propagates it to ~1e-14 on the times. So the times are compared
            # with a tolerance, not exactly; the values are what matters to the derivative.
            vf = Data.VectorField(x -> x; is_autonomous=true, is_variable=false)
            flow = Flows.Flow(vf; save_everystep=true)
            result_real = flow((0.0, 1.0), [1.0])
            result_dual = flow((0.0, 1.0), ForwardDiff.Dual{:T}.([1.0], [1.0]))
            t_real = Integrators.times(result_real)
            t_dual = ForwardDiff.value.(Integrators.times(result_dual))
            Test.@test length(t_real) == length(t_dual) == 250
            Test.@test t_dual ≈ t_real atol = 1e-12
            Test.@test first(t_dual) == 0.0 && last(t_dual) == 1.0
            # value and sensitivity at the final time: x(1) = e · x0, ∂x(1)/∂x0 = e
            Test.@test ForwardDiff.value(result_dual(1.0)[1]) ≈ result_real(1.0)[1] atol = 1e-8
            Test.@test ForwardDiff.partials(result_dual(1.0)[1], 1) ≈ ℯ atol = 1e-6
        end
    end
end

end # module

test_forwarddiff_extension() = TestForwardDiffExtension.test_forwarddiff_extension()
