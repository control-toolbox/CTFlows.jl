module TestSciMLBaseFlowConstructors

using Test: Test
using CTBase: Exceptions
using CTFlows: CTFlows
using CTFlows: Systems
using CTFlows: Integrators
using CTFlows: Flows
using CTFlows: Trajectories
using CTFlows: MultiPhase
using SciMLBase: SciMLBase, ODEProblem, ODEFunction
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, Tsit5
using StaticArrays: SA, SVector

const CTFlowsSciMLFlows = Base.get_extension(CTFlows, :CTFlowsSciMLFlows)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

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
                Test.@test flow isa Flows.StateFlow
                Test.@test flow isa Flows.AbstractFlow
                Test.@test Flows.system(flow) isa CTFlowsSciMLFlows.SciMLFunctionSystem
            end

            Test.@testset "out-of-place function returns StateFlow" begin
                f = ODEFunction{false}((u, p, t) -> -p .* u)
                flow = Flows.Flow(f; reltol=1e-10)
                Test.@test flow isa Flows.StateFlow
                Test.@test flow isa Flows.AbstractFlow
                Test.@test Flows.system(flow) isa CTFlowsSciMLFlows.SciMLFunctionSystem
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
                Test.@test flow isa CTFlowsSciMLFlows.SciMLProblemFlow
                Test.@test flow isa Flows.AbstractFlow
            end

            Test.@testset "kwargs passed to integrator" begin
                f = ODEFunction((du, u, p, t) -> du .= -u)
                prob = ODEProblem(f, [1.0], (0.0, 1.0))
                flow = Flows.Flow(prob; reltol=1e-12, abstol=1e-12)
                integ = Flows.integrator(flow)
                Test.@test integ isa Integrators.SciML
            end
        end

        Test.@testset "phase labels (issue #443)" begin
            f = ODEFunction((du, u, p, t) -> du .= -u)
            prob = ODEProblem(f, [1.0], (0.0, 1.0))
            # Flow(::AbstractODEFunction): a labelled state flow
            Test.@test Flows.label(Flows.Flow(f)) == ""
            Test.@test Flows.label(Flows.Flow(f; label="decay", reltol=1e-10)) == "decay"
            # Flow(::AbstractODEProblem): the label is a field of the problem flow
            pf = Flows.Flow(prob; label="decay", reltol=1e-10)
            Test.@test Flows.label(pf) == "decay"
            Test.@test Flows.label(Flows.Flow(prob)) == ""
            Test.@test Flows.label(
                CTFlowsSciMLFlows.SciMLProblemFlow(prob, Integrators.SciML())
            ) == ""
            Test.@test Flows.with_label(pf, "") === pf
            Test.@test Flows.label(Flows.with_label(pf, "other")) == "other"
            # not passed to the integrator: the flow still integrates
            Test.@test Integrators.final_state(pf(; unsafe=false))[1] ≈ exp(-1.0) atol =
                1e-8
            # display
            Test.@test occursin("label: decay", sprint(show, MIME"text/plain"(), pf))
            Test.@test occursin("label=\"decay\"", sprint(show, pf))
            Test.@test !occursin(
                "label", sprint(show, MIME"text/plain"(), Flows.Flow(prob))
            )
            Test.@test !occursin("label", sprint(show, Flows.Flow(prob)))
            # an action option: a wrong type is rejected
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(prob; label=:decay)
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(f; label=1)
            # multi-phase SciML flows keep and show the phase sequence
            g = ODEFunction((du, u, p, t) -> du .= u)
            mf = Flows.Flow(f; label="bang") * (0.5, Flows.Flow(g; label="singular"))
            Test.@test MultiPhase.get_labels(mf) == ["bang", "singular"]
            Test.@test occursin(
                "labels: bang → singular", sprint(show, MIME"text/plain"(), mf)
            )
            traj = mf((0.0, 1.0), [1.0]; variable=nothing)
            Test.@test Trajectories.phase_labels(traj) == ["bang", "singular"]
            mp = pf * (0.5, Flows.Flow(ODEProblem(g, [1.0], (0.0, 1.0)); label="singular"))
            Test.@test MultiPhase.get_labels(mp) == ["decay", "singular"]
            Test.@test occursin(
                "labels: decay → singular", sprint(show, MIME"text/plain"(), mp)
            )
        end

        # ====================================================================
        # INTEGRATION TESTS - Flow(::AbstractODEFunction) End-to-end
        # ====================================================================

        Test.@testset "Integration: Flow(::AbstractODEFunction)" begin
            Test.@testset "in-place function end-to-end" begin
                f = ODEFunction((du, u, p, t) -> du .= -p .* u)
                flow = Flows.Flow(f; reltol=1e-10)
                xf = flow(0.0, [1.0], 1.0; variable=2.0)
                # 1-D = scalar (issue #357): a length-1 vector u0 collapses to a scalar.
                Test.@test xf isa Real
                # Expected: exp(-2*1) * 1 = exp(-2) ≈ 0.1353
                Test.@test isapprox(xf, exp(-2.0), rtol=1e-6)
            end

            Test.@testset "out-of-place function end-to-end" begin
                f = ODEFunction{false}((u, p, t) -> -p .* u)
                flow = Flows.Flow(f; reltol=1e-10)
                xf = flow(0.0, [1.0], 1.0; variable=2.0)
                Test.@test xf isa Real
                Test.@test isapprox(xf, exp(-2.0), rtol=1e-6)
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - Flow(::AbstractODEProblem) End-to-end
        # ====================================================================

        Test.@testset "Integration: Flow(::AbstractODEProblem)" begin
            Test.@testset "point call end-to-end" begin
                f = ODEFunction((du, u, p, t) -> du .= -p .* u)
                prob = ODEProblem(f, [1.0], (0.0, 1.0), 2.0)
                flow = Flows.Flow(prob; reltol=1e-10)
                xf = flow(0.0, [1.0], 1.0; variable=3.0)
                Test.@test xf isa Vector
                Test.@test length(xf) == 1
                # Expected: exp(-3*1) * 1 = exp(-3) ≈ 0.0498
                Test.@test isapprox(xf[1], exp(-3.0), rtol=1e-6)
            end

            Test.@testset "trajectory call end-to-end" begin
                f = ODEFunction((du, u, p, t) -> du .= -p .* u)
                prob = ODEProblem(f, [1.0], (0.0, 1.0), 2.0)
                flow = Flows.Flow(prob; reltol=1e-10)
                result = flow((0.0, 1.0), [1.0]; variable=3.0)
                Test.@test result isa Integrators.AbstractIntegrationResult
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
            Test.@testset "trajectory call returns VectorFieldTrajectory" begin
                f = ODEFunction((du, u, p, t) -> du .= -p .* u)
                flow = Flows.Flow(f; reltol=1e-10)
                sol = flow((0.0, 1.0), [1.0]; variable=2.0)
                Test.@test sol isa Trajectories.VectorFieldTrajectory
                Test.@test sol(0.5)[1] ≈ exp(-2.0 * 0.5) rtol=1e-6
            end
        end

        Test.@testset "Integration: Flow(::AbstractODEFunction) with variable" begin
            Test.@testset "autonomous ODE" begin
                f = ODEFunction((du, u, p, t) -> du .= -p .* u)
                flow = Flows.Flow(f; reltol=1e-10)
                xf = flow(0.0, [1.0, 2.0], 1.0; variable=1.0)
                Test.@test xf isa Vector
                Test.@test length(xf) == 2
                Test.@test xf ≈ [exp(-1.0), 2.0 * exp(-1.0)] rtol=1e-6
            end
        end

        Test.@testset "Integration: iip ODEFunction + length-1 SVector u0 (cross-adapter path)" begin
            f = ODEFunction((du, u, p, t) -> du .= -p .* u)
            flow = Flows.Flow(f; reltol=1e-10)
            xf = Test.@test_logs (:warn, r"InPlace SciMLFunction") flow(
                0.0, SA[1.0], 1.0; variable=2.0
            )
            # 1-D = scalar (issue #357): a length-1 SVector u0 collapses to a scalar.
            Test.@test xf isa Real
            Test.@test xf ≈ exp(-2.0) rtol=1e-6
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
function test_scimlbase_flow_constructors()
    return TestSciMLBaseFlowConstructors.test_scimlbase_flow_constructors()
end
