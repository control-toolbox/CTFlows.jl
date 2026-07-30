module TestSciMLBaseFunctionSystem

using Test: Test
using CTBase: Core
using CTBase: Exceptions
using CTBase: Strategies
using CTFlows: CTFlows
using CTFlows: Configs
using CTFlows: Systems
using CTFlows: Integrators
using CTFlows: Flows
using CTFlows: Trajectories

# Fake tag type for testing stub behavior
struct FakeTag <: Core.AbstractTag end

# Get extension to access SciML integrator
using SciMLBase: SciMLBase, ODEProblem, ODEFunction
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, Tsit5
using StaticArrays: SA, SVector

const CTFlowsSciMLFlows = Base.get_extension(CTFlows, :CTFlowsSciMLFlows)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Test function
# ==============================================================================

function test_scimlbase_function_system()
    Test.@testset "SciMLBaseFunctionSystem" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Extension Loading
        # ====================================================================

        Test.@testset "Extension Loading" begin
            Test.@testset "extension is loaded" begin
                Test.@test !isnothing(CTFlowsSciMLFlows)
            end

            Test.@testset "extension is a Module" begin
                Test.@test CTFlowsSciMLFlows isa Module
            end
        end

        # ====================================================================
        # UNIT TESTS - SciMLFunctionSystem Construction
        # ====================================================================

        Test.@testset "SciMLFunctionSystem Construction" begin
            Test.@testset "in-place ODEFunction" begin
                f = ODEFunction((du, u, p, t) -> du .= -p .* u)
                sys = CTFlowsSciMLFlows.SciMLFunctionSystem(f)
                Test.@test sys isa CTFlowsSciMLFlows.SciMLFunctionSystem
                Test.@test sys isa Systems.AbstractStateSystem
                Test.@test sys.f === f
            end

            Test.@testset "out-of-place ODEFunction" begin
                f = ODEFunction{false}((u, p, t) -> -p .* u)
                sys = CTFlowsSciMLFlows.SciMLFunctionSystem(f)
                Test.@test sys isa CTFlowsSciMLFlows.SciMLFunctionSystem
                Test.@test sys isa Systems.AbstractStateSystem
                Test.@test sys.f === f
            end
        end

        # ====================================================================
        # UNIT TESTS - get_ip_rhs / get_oop_rhs
        # ====================================================================

        Test.@testset "RHS Dispatch" begin
            # Lazy systems (issue #357): get_ip_rhs/get_oop_rhs read x0 from the
            # config to build the coercion — use a real config matching u.
            cfg(x0) = Configs.StateEndPointConfig(0.0, x0, 1.0)

            Test.@testset "in-place returns functor" begin
                f = ODEFunction((du, u, p, t) -> du .= -u)
                sys = CTFlowsSciMLFlows.SciMLFunctionSystem(f)
                rhs_fn = Systems.get_ip_rhs(sys, cfg([1.0, 2.0]))
                Test.@test rhs_fn !== f  # Not the raw function, but a wrapper
                Test.@test rhs_fn isa Systems.AbstractIPRHS
                # Test that the wrapper works
                du = zeros(2)
                u = [1.0, 2.0]
                p = Systems.ODEParameters(2.0)
                rhs_fn(du, u, p, 0.0)
                Test.@test du ≈ [-1.0, -2.0]
            end

            Test.@testset "out-of-place returns functor" begin
                f = ODEFunction{false}((u, p, t) -> -u)
                sys = CTFlowsSciMLFlows.SciMLFunctionSystem(f)
                rhs_oop_fn = Systems.get_oop_rhs(sys, cfg([1.0, 2.0]))
                Test.@test rhs_oop_fn !== f  # Not the raw function, but a wrapper
                Test.@test rhs_oop_fn isa Systems.AbstractOoPRHS
                # Test that the wrapper works
                u = [1.0, 2.0]
                p = Systems.ODEParameters(2.0)
                du = rhs_oop_fn(u, p, 0.0)
                Test.@test du ≈ [-1.0, -2.0]
            end

            Test.@testset "get_ip_rhs on out-of-place returns iip wrapper (cross-adapter)" begin
                f = ODEFunction{false}((u, p, t) -> -u)
                sys = CTFlowsSciMLFlows.SciMLFunctionSystem(f)
                rhs_fn = Systems.get_ip_rhs(sys, cfg([1.0, 2.0]))
                Test.@test rhs_fn isa Systems.AbstractIPRHS
                # Should return a wrapper that makes the oop function iip
                du = zeros(2)
                u = [1.0, 2.0]
                p = Systems.ODEParameters(2.0)
                rhs_fn(du, u, p, 0.0)
                Test.@test du ≈ [-1.0, -2.0]
            end

            Test.@testset "get_oop_rhs on in-place returns oop wrapper (cross-adapter)" begin
                f = ODEFunction((du, u, p, t) -> du .= -u)
                sys = CTFlowsSciMLFlows.SciMLFunctionSystem(f)
                # x0 = [1.0, 2.0] is mutable, so (per issue #357's ismutable-gated
                # warning, matching HamiltonianVectorFieldSystem) no performance
                # warning fires here — only an immutable x0 (e.g. SVector) warns,
                # covered by "Integration: iip + SVector u0" below.
                rhs_oop_fn = Systems.get_oop_rhs(sys, cfg([1.0, 2.0]))
                Test.@test rhs_oop_fn isa Systems.AbstractOoPRHS
                # Should return a wrapper that allocates a buffer
                u = [1.0, 2.0]
                p = Systems.ODEParameters(2.0)
                du = rhs_oop_fn(u, p, 0.0)
                Test.@test du ≈ [-1.0, -2.0]
            end
        end

        # ====================================================================
        # UNIT TESTS - build_problem
        # ====================================================================

        Test.@testset "build_problem" begin
            Test.@testset "returns raw ODEProblem (no wrapper)" begin
                f = ODEFunction((du, u, p, t) -> du .= -u)
                sys = CTFlowsSciMLFlows.SciMLFunctionSystem(f)
                integ = Integrators.SciML()
                config = Configs.StateEndPointConfig(0.0, [1.0, 0.0], 1.0)
                prob = Integrators.build_problem(sys, config, integ; variable=2.0)
                Test.@test prob isa SciMLBase.ODEProblem
                Test.@test prob.p isa Systems.ODEParameters
                Test.@test prob.p.variable == 2.0
            end

            Test.@testset "variable wrapped in ODEParameters" begin
                f = ODEFunction((du, u, p, t) -> du .= -p .* u)
                sys = CTFlowsSciMLFlows.SciMLFunctionSystem(f)
                integ = Integrators.SciML()
                config = Configs.StateEndPointConfig(0.0, [1.0], 1.0)
                prob = Integrators.build_problem(sys, config, integ; variable=3.5)
                Test.@test prob.p isa Systems.ODEParameters
                Test.@test prob.p.variable == 3.5
            end
        end

        # ====================================================================
        # UNIT TESTS - Base.show
        # ====================================================================

        Test.@testset "Base.show" begin
            Test.@testset "in-place display" begin
                f = ODEFunction((du, u, p, t) -> du .= -u)
                sys = CTFlowsSciMLFlows.SciMLFunctionSystem(f)
                str = sprint(show, sys)
                Test.@test occursin("in-place", str)
            end

            Test.@testset "out-of-place display" begin
                f = ODEFunction{false}((u, p, t) -> -u)
                sys = CTFlowsSciMLFlows.SciMLFunctionSystem(f)
                str = sprint(show, sys)
                Test.@test occursin("out-of-place", str)
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - End-to-end
        # ====================================================================

        Test.@testset "Integration: iip flow end-to-end" begin
            f = ODEFunction((du, u, p, t) -> du .= -p .* u)
            flow = Flows.Flow(f; reltol=1e-10)
            xf = flow(0.0, [1.0], 1.0; variable=2.0)
            # 1-D = scalar (issue #357): a length-1 vector u0 collapses to a scalar.
            Test.@test xf isa Real
            # Expected: exp(-2*1) * 1 = exp(-2) ≈ 0.1353
            Test.@test isapprox(xf, exp(-2.0), rtol=1e-6)
        end

        Test.@testset "Integration: oop flow end-to-end" begin
            f = ODEFunction{false}((u, p, t) -> -p .* u)
            flow = Flows.Flow(f; reltol=1e-10)
            xf = flow(0.0, [1.0], 1.0; variable=2.0)
            Test.@test xf isa Real
            Test.@test isapprox(xf, exp(-2.0), rtol=1e-6)
        end

        Test.@testset "Integration: trajectory call" begin
            f = ODEFunction((du, u, p, t) -> du .= -p .* u)
            flow = Flows.Flow(f; reltol=1e-10)
            sol = flow((0.0, 1.0), [1.0]; variable=2.0)
            Test.@test sol isa Trajectories.VectorFieldTrajectory
            Test.@test sol(0.5)[1] ≈ exp(-2.0 * 0.5) rtol=1e-6
        end

        Test.@testset "Integration: iip + length-1 SVector u0 (cross-adapter finalize path)" begin
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
function test_scimlbase_function_system()
    return TestSciMLBaseFunctionSystem.test_scimlbase_function_system()
end
