module TestSciMLBaseFlowConstructors

import Test
import CTBase.Exceptions: Exceptions
import CTFlows: CTFlows
import CTFlows.Common: Common
import CTFlows.Systems: Systems
import CTFlows.Integrators: Integrators
import CTFlows.Flows: Flows, AbstractFlow, StateFlow, build_flow
import CTFlows.Solutions: Solutions
import SciMLBase: SciMLBase, ODEProblem, ODEFunction
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, Tsit5
using StaticArrays: SA, SVector

const CTFlowsSciML = Base.get_extension(CTFlows, :CTFlowsSciML)
const CTFlowsOrdinaryDiffEqTsit5 = Base.get_extension(CTFlows, :CTFlowsOrdinaryDiffEqTsit5)

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Test function
# ==============================================================================

function test_scimlbase_flow_constructors()
    Test.@testset "SciMLBase Flow Constructors" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Flow(::AbstractODEFunction)
        # ====================================================================

        Test.@testset "Flow(::AbstractODEFunction)" begin
            Test.@testset "in-place function returns StateFlow" begin
                f = ODEFunction((du, u, p, t) -> du .= -p .* u)
                flow = Flows.Flow(f; reltol=1e-10)
                Test.@test flow isa StateFlow
                Test.@test flow isa AbstractFlow
                Test.@test Flows.system(flow) isa CTFlowsSciML.SciMLFunctionSystem
            end

            Test.@testset "out-of-place function returns StateFlow" begin
                f = ODEFunction{false}((u, p, t) -> -p .* u)
                flow = Flows.Flow(f; reltol=1e-10)
                Test.@test flow isa StateFlow
                Test.@test flow isa AbstractFlow
                Test.@test Flows.system(flow) isa CTFlowsSciML.SciMLFunctionSystem
            end

            Test.@testset "kwargs passed to integrator" begin
                f = ODEFunction((du, u, p, t) -> du .= -u)
                flow = Flows.Flow(f; reltol=1e-12, abstol=1e-12)
                integ = Flows.integrator(flow)
                Test.@test integ isa Integrators.SciML
            end
        end

        # ====================================================================
        # UNIT TESTS - Flow(::AbstractODEProblem)
        # ====================================================================

        Test.@testset "Flow(::AbstractODEProblem)" begin
            Test.@testset "returns SciMLProblemFlow" begin
                f = ODEFunction((du, u, p, t) -> du .= -p .* u)
                prob = ODEProblem(f, [1.0], (0.0, 1.0), 2.0)
                flow = Flows.Flow(prob; reltol=1e-10)
                Test.@test flow isa CTFlowsSciML.SciMLProblemFlow
                Test.@test flow isa AbstractFlow
            end

            Test.@testset "kwargs passed to integrator" begin
                f = ODEFunction((du, u, p, t) -> du .= -u)
                prob = ODEProblem(f, [1.0], (0.0, 1.0))
                flow = Flows.Flow(prob; reltol=1e-12, abstol=1e-12)
                integ = Flows.integrator(flow)
                Test.@test integ isa Integrators.SciML
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - Flow(::AbstractODEFunction) End-to-end
        # ====================================================================

        Test.@testset "Integration: Flow(::AbstractODEFunction)" begin
            Test.@testset "in-place function end-to-end" begin
                f = ODEFunction((du, u, p, t) -> du .= -p .* u)
                flow = Flows.Flow(f; reltol=1e-10)
                xf = flow(0.0, [1.0], 1.0; variable=2.0)
                Test.@test xf isa Vector
                Test.@test length(xf) == 1
                # Expected: exp(-2*1) * 1 = exp(-2) ≈ 0.1353
                Test.@test isapprox(xf[1], exp(-2.0), rtol=1e-6)
            end

            Test.@testset "out-of-place function end-to-end" begin
                f = ODEFunction{false}((u, p, t) -> -p .* u)
                flow = Flows.Flow(f; reltol=1e-10)
                xf = flow(0.0, [1.0], 1.0; variable=2.0)
                Test.@test xf isa Vector
                Test.@test length(xf) == 1
                Test.@test isapprox(xf[1], exp(-2.0), rtol=1e-6)
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - Flow(::AbstractODEProblem) End-to-end
        # ====================================================================

        Test.@testset "Integration: Flow(::AbstractODEProblem)" begin
            Test.@testset "remake call end-to-end" begin
                f = ODEFunction((du, u, p, t) -> du .= -p .* u)
                prob = ODEProblem(f, [1.0], (0.0, 1.0), 2.0)
                flow = Flows.Flow(prob; reltol=1e-10)
                result = flow(0.0, [1.0], 1.0; variable=3.0)
                Test.@test result isa CTFlowsSciML.SciMLIntegrationResult
                xf = Integrators.final_state(result)
                Test.@test xf isa Vector
                Test.@test length(xf) == 1
                # Expected: exp(-3*1) * 1 = exp(-3) ≈ 0.0498
                Test.@test isapprox(xf[1], exp(-3.0), rtol=1e-6)
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - Flow(::AbstractODEFunction) Trajectory + SVector
        # ====================================================================

        Test.@testset "Integration: Flow(::AbstractODEFunction) trajectory call" begin
            Test.@testset "trajectory call returns VectorFieldSolution" begin
                f = ODEFunction((du, u, p, t) -> du .= -p .* u)
                flow = Flows.Flow(f; reltol=1e-10)
                sol = flow((0.0, 1.0), [1.0]; variable=2.0)
                Test.@test sol isa Solutions.VectorFieldSolution
                Test.@test sol(0.5)[1] ≈ exp(-2.0 * 0.5) rtol=1e-6
            end
        end

        Test.@testset "Integration: Flow(::AbstractODEFunction) variable=nothing" begin
            Test.@testset "autonomous ODE" begin
                f = ODEFunction((du, u, p, t) -> du .= -u)
                flow = Flows.Flow(f; reltol=1e-10)
                xf = flow(0.0, [1.0, 2.0], 1.0)
                Test.@test xf isa Vector
                Test.@test length(xf) == 2
                Test.@test xf ≈ [exp(-1.0), 2.0 * exp(-1.0)] rtol=1e-6
            end
        end

        Test.@testset "Integration: iip ODEFunction + SVector u0 (cross-adapter path)" begin
            f = ODEFunction((du, u, p, t) -> du .= -p .* u)
            flow = Flows.Flow(f; reltol=1e-10)
            xf = Test.@test_logs (:warn, r"InPlace SciMLFunction") flow(0.0, SA[1.0], 1.0; variable=2.0)
            Test.@test xf isa SVector
            Test.@test xf[1] ≈ exp(-2.0) rtol=1e-6
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_scimlbase_flow_constructors() = TestSciMLBaseFlowConstructors.test_scimlbase_flow_constructors()
