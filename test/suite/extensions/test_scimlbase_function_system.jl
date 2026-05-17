module TestSciMLBaseFunctionSystem

import Test
import CTBase.Exceptions: Exceptions
import CTFlows: CTFlows
import CTFlows.Common: Common
import CTFlows.Systems: Systems
import CTFlows.Integrators: Integrators
import CTFlows.Flows: Flows
import CTSolvers.Strategies: Strategies

# Fake tag type for testing stub behavior
struct FakeTag <: Common.AbstractTag end

# Get extension to access SciML integrator
using SciMLBase: SciMLBase, ODEProblem, ODEFunction
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, Tsit5

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
            Test.@testset "in-place returns pre-computed closure" begin
                f = ODEFunction((du, u, p, t) -> du .= -u)
                sys = CTFlowsSciML.SciMLFunctionSystem(f)
                rhs_fn = Systems.rhs(sys)
                Test.@test rhs_fn !== f  # Not the raw function, but a wrapper
                # Test that the wrapper works
                du = zeros(2)
                u = [1.0, 2.0]
                p = Common.ODEParameters(2.0)
                rhs_fn(du, u, p, 0.0)
                Test.@test du ≈ [-1.0, -2.0]
            end

            Test.@testset "out-of-place returns pre-computed closure" begin
                f = ODEFunction{false}((u, p, t) -> -u)
                sys = CTFlowsSciML.SciMLFunctionSystem(f)
                rhs_oop_fn = Systems.rhs_oop(sys)
                Test.@test rhs_oop_fn !== f  # Not the raw function, but a wrapper
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
                config = Common.StatePointConfig(0.0, [1.0, 0.0], 1.0)
                prob = Integrators.build_problem(integ, sys, config; variable=2.0)
                Test.@test prob isa SciMLBase.ODEProblem
                Test.@test prob.p isa Common.ODEParameters
                Test.@test prob.p.variable == 2.0
            end

            Test.@testset "variable wrapped in ODEParameters" begin
                f = ODEFunction((du, u, p, t) -> du .= -p .* u)
                sys = CTFlowsSciML.SciMLFunctionSystem(f)
                integ = Integrators.SciML()
                config = Common.StatePointConfig(0.0, [1.0], 1.0)
                prob = Integrators.build_problem(integ, sys, config; variable=3.5)
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
        # NOTE: Flow constructors are added in Step 6, not Step 2
        # Integration tests will be added in Step 7

    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_scimlbase_function_system() = TestSciMLBaseFunctionSystem.test_scimlbase_function_system()
