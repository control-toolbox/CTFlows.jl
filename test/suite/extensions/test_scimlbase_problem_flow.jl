module TestSciMLBaseProblemFlow

import Test
import CTBase.Exceptions: Exceptions
import CTFlows: CTFlows
import CTFlows.Integrators: Integrators
import CTFlows.Flows: Flows, AbstractFlow

# Get extension to access SciML integrator
using SciMLBase: SciMLBase, ODEProblem, ODEFunction
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, Tsit5
const CTFlowsSciMLFlows      = Base.get_extension(CTFlows, :CTFlowsSciMLFlows)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Test function
# ==============================================================================

function test_scimlbase_problem_flow()
    Test.@testset "SciMLBaseProblemFlow" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Construction
        # ====================================================================

        Test.@testset "SciMLProblemFlow Construction" begin
            Test.@testset "in-place ODEProblem" begin
                f = ODEFunction((du, u, p, t) -> du .= -p .* u)
                prob = ODEProblem(f, [1.0], (0.0, 1.0), 2.0)
                integ = Integrators.SciML()
                flow = CTFlowsSciMLFlows.SciMLProblemFlow(prob, integ)
                Test.@test flow isa CTFlowsSciMLFlows.SciMLProblemFlow
                Test.@test flow isa AbstractFlow
                Test.@test flow.prob === prob
                Test.@test flow.integrator === integ
            end

            Test.@testset "out-of-place ODEProblem" begin
                f = ODEFunction{false}((u, p, t) -> -p .* u)
                prob = ODEProblem(f, [1.0], (0.0, 1.0), 2.0)
                integ = Integrators.SciML()
                flow = CTFlowsSciMLFlows.SciMLProblemFlow(prob, integ)
                Test.@test flow isa CTFlowsSciMLFlows.SciMLProblemFlow
                Test.@test flow isa AbstractFlow
                Test.@test flow.prob === prob
                Test.@test flow.integrator === integ
            end
        end

        # ====================================================================
        # UNIT TESTS - Contract Methods
        # ====================================================================

        Test.@testset "Contract Methods" begin
            Test.@testset "system(f) returns nothing" begin
                f = ODEFunction((du, u, p, t) -> du .= -u)
                prob = ODEProblem(f, [1.0], (0.0, 1.0))
                integ = Integrators.SciML()
                flow = CTFlowsSciMLFlows.SciMLProblemFlow(prob, integ)
                Test.@test Flows.system(flow) === nothing
            end

            Test.@testset "integrator(f) returns integrator" begin
                f = ODEFunction((du, u, p, t) -> du .= -u)
                prob = ODEProblem(f, [1.0], (0.0, 1.0))
                integ = Integrators.SciML()
                flow = CTFlowsSciMLFlows.SciMLProblemFlow(prob, integ)
                Test.@test Flows.integrator(flow) === integ
            end
        end

        # ====================================================================
        # UNIT TESTS - Base.show
        # ====================================================================

        Test.@testset "Base.show" begin
            Test.@testset "compact show" begin
                f = ODEFunction((du, u, p, t) -> du .= -u)
                prob = ODEProblem(f, [1.0], (0.0, 1.0))
                integ = Integrators.SciML()
                flow = CTFlowsSciMLFlows.SciMLProblemFlow(prob, integ)
                str = sprint(show, flow)
                Test.@test occursin("SciMLProblemFlow", str)
                Test.@test occursin("tspan", str)
            end

            Test.@testset "text/plain show" begin
                f = ODEFunction((du, u, p, t) -> du .= -u)
                prob = ODEProblem(f, [1.0], (0.0, 1.0))
                integ = Integrators.SciML()
                flow = CTFlowsSciMLFlows.SciMLProblemFlow(prob, integ)
                str = sprint(show, MIME"text/plain"(), flow)
                Test.@test occursin("SciMLProblemFlow", str)
                Test.@test occursin("tspan:", str)
                Test.@test occursin("u0:", str)
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - No-arg Call
        # ====================================================================

        Test.@testset "Integration: No-arg Call" begin
            Test.@testset "no-arg call uses original problem" begin
                f = ODEFunction((du, u, p, t) -> du .= -p .* u)
                prob = ODEProblem(f, [1.0], (0.0, 1.0), 2.0)
                integ = Integrators.SciML()
                flow = CTFlowsSciMLFlows.SciMLProblemFlow(prob, integ)
                result = flow(; unsafe=false)
                Test.@test result isa Integrators.AbstractIntegrationResult
                xf = Integrators.final_state(result)
                Test.@test xf isa Vector
                Test.@test length(xf) == 1
                # Expected: exp(-2*1) * 1 = exp(-2) ≈ 0.1353
                Test.@test isapprox(xf[1], exp(-2.0), rtol=1e-6)
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - Point Call
        # ====================================================================

        Test.@testset "Integration: Point Call" begin
            Test.@testset "scalar state returns xf directly" begin
                f = ODEFunction((du, u, p, t) -> du .= -p .* u)
                prob = ODEProblem(f, [1.0], (0.0, 1.0), 2.0)
                integ = Integrators.SciML()
                flow = CTFlowsSciMLFlows.SciMLProblemFlow(prob, integ)
                xf = flow(0.0, [1.0], 1.0; unsafe=false)
                Test.@test xf isa Vector
                Test.@test length(xf) == 1
                # Expected: exp(-2*1) * 1 = exp(-2) ≈ 0.1353
                Test.@test isapprox(xf[1], exp(-2.0), rtol=1e-6)
            end

            Test.@testset "vector state returns xf directly" begin
                f = ODEFunction((du, u, p, t) -> du .= -p .* u)
                prob = ODEProblem(f, [1.0, 2.0], (0.0, 1.0), 2.0)
                integ = Integrators.SciML()
                flow = CTFlowsSciMLFlows.SciMLProblemFlow(prob, integ)
                xf = flow(0.0, [1.0, 2.0], 1.0; unsafe=false)
                Test.@test xf isa Vector
                Test.@test length(xf) == 2
            end

            Test.@testset "point call with variable overrides p" begin
                f = ODEFunction((du, u, p, t) -> du .= -p .* u)
                prob = ODEProblem(f, [1.0], (0.0, 1.0), 2.0)
                integ = Integrators.SciML()
                flow = CTFlowsSciMLFlows.SciMLProblemFlow(prob, integ)
                xf = flow(0.0, [1.0], 1.0; variable=3.0, unsafe=false)
                # Expected: exp(-3*1) * 1 = exp(-3) ≈ 0.0498
                Test.@test isapprox(xf[1], exp(-3.0), rtol=1e-6)
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - Trajectory Call
        # ====================================================================

        Test.@testset "Integration: Trajectory Call" begin
            Test.@testset "trajectory call returns an AbstractIntegrationResult" begin
                f = ODEFunction((du, u, p, t) -> du .= -p .* u)
                prob = ODEProblem(f, [1.0], (0.0, 1.0), 2.0)
                integ = Integrators.SciML()
                flow = CTFlowsSciMLFlows.SciMLProblemFlow(prob, integ)
                result = flow((0.0, 1.0), [1.0]; unsafe=false)
                Test.@test result isa Integrators.AbstractIntegrationResult
                xf = Integrators.final_state(result)
                Test.@test xf isa Vector
                Test.@test length(xf) == 1
                # Expected: exp(-2*1) * 1 = exp(-2) ≈ 0.1353
                Test.@test isapprox(xf[1], exp(-2.0), rtol=1e-6)
            end

            Test.@testset "trajectory call with variable overrides p" begin
                f = ODEFunction((du, u, p, t) -> du .= -p .* u)
                prob = ODEProblem(f, [1.0], (0.0, 1.0), 2.0)
                integ = Integrators.SciML()
                flow = CTFlowsSciMLFlows.SciMLProblemFlow(prob, integ)
                result = flow((0.0, 1.0), [1.0]; variable=3.0, unsafe=false)
                xf = Integrators.final_state(result)
                # Expected: exp(-3*1) * 1 = exp(-3) ≈ 0.0498
                Test.@test isapprox(xf[1], exp(-3.0), rtol=1e-6)
            end

            Test.@testset "trajectory call can evaluate at intermediate times" begin
                f = ODEFunction((du, u, p, t) -> du .= -p .* u)
                prob = ODEProblem(f, [1.0], (0.0, 1.0), 2.0)
                integ = Integrators.SciML()
                flow = CTFlowsSciMLFlows.SciMLProblemFlow(prob, integ)
                result = flow((0.0, 1.0), [1.0]; unsafe=false)
                # Can evaluate at intermediate time
                u_mid = Integrators.evaluate_at(result, 0.5)
                Test.@test u_mid isa Vector
                Test.@test isapprox(u_mid[1], exp(-2.0 * 0.5), rtol=1e-6)
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - Error Handling
        # ====================================================================

        Test.@testset "Error Handling" begin
            Test.@testset "unsafe=true skips retcode check for point call" begin
                # Create a problem that will fail (negative parameter with unstable ODE)
                f = ODEFunction((du, u, p, t) -> du .= p .* u)
                prob = ODEProblem(f, [1.0], (0.0, 10.0), 1.0)
                integ = Integrators.SciML()
                flow = CTFlowsSciMLFlows.SciMLProblemFlow(prob, integ)
                # This should not throw even if integration fails
                xf = flow(0.0, [1.0], 10.0; unsafe=true)
                Test.@test xf isa Vector
            end

            Test.@testset "unsafe=true skips retcode check for trajectory call" begin
                # Create a problem that will fail (negative parameter with unstable ODE)
                f = ODEFunction((du, u, p, t) -> du .= p .* u)
                prob = ODEProblem(f, [1.0], (0.0, 10.0), 1.0)
                integ = Integrators.SciML()
                flow = CTFlowsSciMLFlows.SciMLProblemFlow(prob, integ)
                # This should not throw even if integration fails
                result = flow((0.0, 10.0), [1.0]; unsafe=true)
                Test.@test result isa Integrators.AbstractIntegrationResult
            end
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_scimlbase_problem_flow() = TestSciMLBaseProblemFlow.test_scimlbase_problem_flow()
