module TestForwardDiffExtension

import Test
import CTFlows: CTFlows
import CTFlows.Common: Common
import CTFlows.Data: Data
import CTFlows.Systems: Systems
import CTFlows.Integrators: Integrators
import CTFlows.Solutions: Solutions
import CTFlows.Flows: Flows
import CTSolvers.Strategies: Strategies

using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, ODEProblem, Tsit5
using SciMLBase: SciMLBase
using DiffEqBase: DiffEqBase
using ForwardDiff: ForwardDiff

const CTFlowsSciMLExt = Base.get_extension(CTFlows, :CTFlowsSciMLExt)
const CTFlowsForwardDiffExt = Base.get_extension(CTFlows, :CTFlowsForwardDiffExt)

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_forwarddiff_extension()
    Test.@testset "ForwardDiff Extension Tests" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # ====================================================================
        # Extension availability check
        # ====================================================================

        Test.@testset "Extension availability" begin
            Test.@testset "CTFlowsSciMLExt is loaded" begin
                Test.@test !isnothing(CTFlowsSciMLExt)
            end

            Test.@testset "CTFlowsForwardDiffExt availability" begin
                if isnothing(CTFlowsForwardDiffExt)
                    Test.@test_skip "ForwardDiff extension not loaded (ForwardDiff not installed)"
                else
                    Test.@test CTFlowsForwardDiffExt isa Module
                end
            end
        end

        # Skip ForwardDiff-specific tests if extension is not loaded
        if isnothing(CTFlowsForwardDiffExt)
            return
        end

        # ====================================================================
        # UNIT TESTS - Common fallbacks
        # ====================================================================

        Test.@testset "Common fallbacks" begin
            Test.@testset "deepvalue(x::Real) is identity" begin
                Test.@test Common.deepvalue(1.0) === 1.0
                Test.@test Common.deepvalue(2.5) === 2.5
            end

            Test.@testset "real_norm(u::Real, t) is abs" begin
                Test.@test Common.real_norm(3.0, 0.0) === 3.0
                Test.@test Common.real_norm(-5.0, 0.0) === 5.0
            end
        end

        # ====================================================================
        # UNIT TESTS - deepvalue extraction (ForwardDiff)
        # ====================================================================

        Test.@testset "deepvalue extraction" begin
            Test.@testset "order 1 — single Dual" begin
                d1 = ForwardDiff.Dual{:Tag1}(3.0, 1.0)
                Test.@test Common.deepvalue(d1) === 3.0

                d1b = ForwardDiff.Dual{:Tag1}(5.5, 2.0, 3.0)
                Test.@test Common.deepvalue(d1b) === 5.5
            end

            Test.@testset "order 2 — nested Dual" begin
                d1 = ForwardDiff.Dual{:Tag1}(3.0, 1.0)
                d2 = ForwardDiff.Dual{:Tag2}(d1, d1)
                Test.@test Common.deepvalue(d2) === 3.0
            end
        end

        # ====================================================================
        # UNIT TESTS - real_norm ignores dual parts (ForwardDiff)
        # ====================================================================

        Test.@testset "real_norm ignores dual parts" begin
            u_real = [1.0, 2.0, 3.0]
            u_dual = ForwardDiff.Dual{:T}.(u_real, ones(3))

            # The norm must be identical regardless of dual parts
            norm_real = Common.real_norm(u_real, 0.0)
            norm_dual = Common.real_norm(u_dual, 0.0)
            Test.@test norm_real ≈ norm_dual
        end

        # ====================================================================
        # INTEGRATION TESTS - Grid invariance
        # ====================================================================

        Test.@testset "grids differ WITHOUT real_norm (baseline)" begin
            f!(du, u, p, t) = (du .= u)  # ẋ = x
            u0_real = [1.0]

            # Integration with real numbers
            prob_real = ODEProblem(f!, u0_real, (0.0, 1.0), nothing)
            sol_real = SciMLBase.solve(prob_real, Tsit5(); reltol=1e-8, abstol=1e-8, dense=false)

            # Integration with Dual (Jacobian w.r.t. u0) using DiffEqBase.ODE_DEFAULT_NORM
            function integrate_dual_default(x0)
                prob = ODEProblem(f!, x0, (0.0, 1.0), nothing)
                return SciMLBase.solve(prob, Tsit5(); reltol=1e-8, abstol=1e-8, dense=false,
                    internalnorm=DiffEqBase.ODE_DEFAULT_NORM)
            end
            u0_dual = ForwardDiff.Dual{:T}.([1.0], [1.0])
            sol_dual = integrate_dual_default(u0_dual)

            # The grids MUST be different with DiffEqBase.ODE_DEFAULT_NORM
            t_real = sol_real.t
            t_dual = ForwardDiff.value.(sol_dual.t)
            Test.@test t_real ≠ t_dual
        end

        Test.@testset "grids identical WITH real_norm (objective)" begin
            f!(du, u, p, t) = (du .= u)
            u0_real = [1.0]

            prob_real = ODEProblem(f!, u0_real, (0.0, 1.0), nothing)
            sol_real = SciMLBase.solve(prob_real, Tsit5();
                reltol=1e-8, abstol=1e-8, dense=false,
                internalnorm=Common.real_norm)

            function integrate_dual_with_norm(x0)
                prob = ODEProblem(f!, x0, (0.0, 1.0), nothing)
                return SciMLBase.solve(prob, Tsit5();
                    reltol=1e-8, abstol=1e-8, dense=false,
                    internalnorm=Common.real_norm)
            end
            u0_dual = ForwardDiff.Dual{:T}.([1.0], [1.0])
            sol_dual = integrate_dual_with_norm(u0_dual)

            t_real = sol_real.t
            t_dual = ForwardDiff.value.(sol_dual.t)
            Test.@test t_real == t_dual
        end

        # ====================================================================
        # UNIT TESTS - Default option verification
        # ====================================================================

        Test.@testset "real_norm is default internalnorm" begin
            integ = Integrators.build_integrator()
            opts = Strategies.options_dict(integ)
            Test.@test haskey(opts, :internalnorm)
            Test.@test opts[:internalnorm] === Common.real_norm
        end

        # ====================================================================
        # INTEGRATION TESTS - Flow API grid invariance
        # ====================================================================

        Test.@testset "Flow API grid invariance" begin
            # Simple ODE: ẋ = x
            vf = Data.VectorField(x -> x; is_autonomous=true, is_variable=false)
            flow = Flows.Flow(vf)

            # Integration with real numbers
            result_real = flow((0.0, 1.0), [1.0])
            t_real = Solutions.times(result_real)

            # Integration with Dual (Jacobian w.r.t. initial condition)
            result_dual = flow((0.0, 1.0), ForwardDiff.Dual{:T}.([1.0], [1.0]))
            t_dual = ForwardDiff.value.(Solutions.times(result_dual))

            # Grids must be identical with real_norm (default)
            Test.@test t_real == t_dual
        end
    end
end

end # module

test_forwarddiff_extension() = TestForwardDiffExtension.test_forwarddiff_extension()
