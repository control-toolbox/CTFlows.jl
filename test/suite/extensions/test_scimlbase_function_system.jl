module TestSciMLBaseFunctionSystem

import Test
import CTBase.Exceptions: Exceptions
import CTFlows: CTFlows
import CTFlows.Common: Common
import CTFlows.Configs: Configs
import CTFlows.Systems: Systems
import CTFlows.Integrators: Integrators
import CTFlows.Flows: Flows
import CTFlows.Solutions: Solutions
import CTSolvers.Strategies: Strategies

# Fake tag type for testing stub behavior
struct FakeTag <: Common.AbstractTag end

# Get extension to access SciML integrator
using SciMLBase: SciMLBase, ODEProblem, ODEFunction
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, Tsit5
using StaticArrays: SA, SVector

const CTFlowsSciML = Base.get_extension(CTFlows, :CTFlowsSciML)
const CTFlowsOrdinaryDiffEqTsit5 = Base.get_extension(CTFlows, :CTFlowsOrdinaryDiffEqTsit5)

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

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
                Test.@test !isnothing(CTFlowsSciML)
            end

            Test.@testset "extension is a Module" begin
                Test.@test CTFlowsSciML isa Module
            end
        end

        # ====================================================================
        # UNIT TESTS - SciMLFunctionSystem Construction
        # ====================================================================

        Test.@testset "SciMLFunctionSystem Construction" begin
            Test.@testset "in-place ODEFunction" begin
                f = ODEFunction((du, u, p, t) -> du .= -p .* u)
                sys = CTFlowsSciML.SciMLFunctionSystem(f)
                Test.@test sys isa CTFlowsSciML.SciMLFunctionSystem
                Test.@test sys isa Systems.AbstractStateSystem
                Test.@test sys.f === f
            end

            Test.@testset "out-of-place ODEFunction" begin
                f = ODEFunction{false}((u, p, t) -> -p .* u)
                sys = CTFlowsSciML.SciMLFunctionSystem(f)
                Test.@test sys isa CTFlowsSciML.SciMLFunctionSystem
                Test.@test sys isa Systems.AbstractStateSystem
                Test.@test sys.f === f
            end
        end

        # ====================================================================
        # UNIT TESTS - rhs / rhs_oop
        # ====================================================================

        Test.@testset "rhs Dispatch" begin
            Test.@testset "in-place returns pre-computed functor" begin
                f = ODEFunction((du, u, p, t) -> du .= -u)
                sys = CTFlowsSciML.SciMLFunctionSystem(f)
                rhs_fn = Systems.rhs(sys)
                Test.@test rhs_fn !== f  # Not the raw function, but a wrapper
                Test.@test rhs_fn isa Systems.AbstractIPRHS
                # Test that the wrapper works
                du = zeros(2)
                u = [1.0, 2.0]
                p = Common.ODEParameters(2.0)
                rhs_fn(du, u, p, 0.0)
                Test.@test du ≈ [-1.0, -2.0]
            end

            Test.@testset "out-of-place returns pre-computed functor" begin
                f = ODEFunction{false}((u, p, t) -> -u)
                sys = CTFlowsSciML.SciMLFunctionSystem(f)
                rhs_oop_fn = Systems.rhs_oop(sys)
                Test.@test rhs_oop_fn !== f  # Not the raw function, but a wrapper
                Test.@test rhs_oop_fn isa Systems.AbstractOoPRHS
                # Test that the wrapper works
                u = [1.0, 2.0]
                p = Common.ODEParameters(2.0)
                du = rhs_oop_fn(u, p, 0.0)
                Test.@test du ≈ [-1.0, -2.0]
            end

            Test.@testset "rhs on out-of-place returns iip wrapper (cross-adapter)" begin
                f = ODEFunction{false}((u, p, t) -> -u)
                sys = CTFlowsSciML.SciMLFunctionSystem(f)
                rhs_fn = Systems.rhs(sys)
                Test.@test rhs_fn isa Systems.AbstractIPRHS
                # Should return a wrapper that makes the oop function iip
                du = zeros(2)
                u = [1.0, 2.0]
                p = Common.ODEParameters(2.0)
                rhs_fn(du, u, p, 0.0)
                Test.@test du ≈ [-1.0, -2.0]
            end

            Test.@testset "rhs_oop on in-place returns oop wrapper (cross-adapter)" begin
                f = ODEFunction((du, u, p, t) -> du .= -u)
                sys = CTFlowsSciML.SciMLFunctionSystem(f)
                rhs_oop_fn = Systems.rhs_oop(sys)
                Test.@test rhs_oop_fn isa Systems.AbstractOoPRHS
                # Should return a wrapper that allocates a buffer
                u = [1.0, 2.0]
                p = Common.ODEParameters(2.0)
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
                sys = CTFlowsSciML.SciMLFunctionSystem(f)
                integ = Integrators.SciML()
                config = Configs.StatePointConfig(0.0, [1.0, 0.0], 1.0)
                prob = Integrators.build_problem(integ, sys, config; variable=2.0, cache=nothing)
                Test.@test prob isa SciMLBase.ODEProblem
                Test.@test prob.p isa Common.ODEParameters
                Test.@test prob.p.variable == 2.0
            end

            Test.@testset "variable wrapped in ODEParameters" begin
                f = ODEFunction((du, u, p, t) -> du .= -p .* u)
                sys = CTFlowsSciML.SciMLFunctionSystem(f)
                integ = Integrators.SciML()
                config = Configs.StatePointConfig(0.0, [1.0], 1.0)
                prob = Integrators.build_problem(integ, sys, config; variable=3.5, cache=nothing)
                Test.@test prob.p isa Common.ODEParameters
                Test.@test prob.p.variable == 3.5
            end
        end

        # ====================================================================
        # UNIT TESTS - Base.show
        # ====================================================================

        Test.@testset "Base.show" begin
            Test.@testset "in-place display" begin
                f = ODEFunction((du, u, p, t) -> du .= -u)
                sys = CTFlowsSciML.SciMLFunctionSystem(f)
                str = sprint(show, sys)
                Test.@test occursin("in-place", str)
            end

            Test.@testset "out-of-place display" begin
                f = ODEFunction{false}((u, p, t) -> -u)
                sys = CTFlowsSciML.SciMLFunctionSystem(f)
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
            Test.@test xf isa Vector
            Test.@test length(xf) == 1
            # Expected: exp(-2*1) * 1 = exp(-2) ≈ 0.1353
            Test.@test isapprox(xf[1], exp(-2.0), rtol=1e-6)
        end

        Test.@testset "Integration: oop flow end-to-end" begin
            f = ODEFunction{false}((u, p, t) -> -p .* u)
            flow = Flows.Flow(f; reltol=1e-10)
            xf = flow(0.0, [1.0], 1.0; variable=2.0)
            Test.@test xf isa Vector
            Test.@test length(xf) == 1
            Test.@test isapprox(xf[1], exp(-2.0), rtol=1e-6)
        end

        Test.@testset "Integration: trajectory call" begin
            f = ODEFunction((du, u, p, t) -> du .= -p .* u)
            flow = Flows.Flow(f; reltol=1e-10)
            sol = flow((0.0, 1.0), [1.0]; variable=2.0)
            Test.@test sol isa Solutions.VectorFieldSolution
            Test.@test sol(0.5)[1] ≈ exp(-2.0 * 0.5) rtol=1e-6
        end

        Test.@testset "Integration: iip + SVector u0 (cross-adapter finalize path)" begin
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
test_scimlbase_function_system() = TestSciMLBaseFunctionSystem.test_scimlbase_function_system()
