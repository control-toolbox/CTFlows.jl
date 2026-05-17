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

const CTFlowsSciMLBase = Base.get_extension(CTFlows, :CTFlowsSciMLBase)
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
                Test.@test !isnothing(CTFlowsSciMLBase)
            end

            Test.@testset "extension is a Module" begin
                Test.@test CTFlowsSciMLBase isa Module
            end
        end

        # ====================================================================
        # UNIT TESTS - SciMLFunctionSystem Construction
        # ====================================================================

        Test.@testset "SciMLFunctionSystem Construction" begin
            Test.@testset "in-place ODEFunction" begin
                f = ODEFunction((du, u, p, t) -> du .= -p .* u)
                sys = CTFlowsSciMLBase.SciMLFunctionSystem(f)
                Test.@test sys isa CTFlowsSciMLBase.SciMLFunctionSystem
                Test.@test sys isa Systems.AbstractStateSystem
                Test.@test sys.f === f
            end

            Test.@testset "out-of-place ODEFunction" begin
                f = ODEFunction{false}((u, p, t) -> -p .* u)
                sys = CTFlowsSciMLBase.SciMLFunctionSystem(f)
                Test.@test sys isa CTFlowsSciMLBase.SciMLFunctionSystem
                Test.@test sys isa Systems.AbstractStateSystem
                Test.@test sys.f === f
            end
        end

        # ====================================================================
        # UNIT TESTS - rhs / rhs_oop
        # ====================================================================

        Test.@testset "rhs Dispatch" begin
            Test.@testset "in-place returns function directly" begin
                f = ODEFunction((du, u, p, t) -> du .= -u)
                sys = CTFlowsSciMLBase.SciMLFunctionSystem(f)
                Test.@test Systems.rhs(sys) === f
            end

            Test.@testset "out-of-place returns function directly" begin
                f = ODEFunction{false}((u, p, t) -> -u)
                sys = CTFlowsSciMLBase.SciMLFunctionSystem(f)
                Test.@test Systems.rhs_oop(sys) === f
            end

            Test.@testset "rhs on out-of-place throws PreconditionError" begin
                f = ODEFunction{false}((u, p, t) -> -u)
                sys = CTFlowsSciMLBase.SciMLFunctionSystem(f)
                Test.@test_throws Exceptions.PreconditionError Systems.rhs(sys)
            end

            Test.@testset "rhs_oop on in-place throws PreconditionError" begin
                f = ODEFunction((du, u, p, t) -> du .= -u)
                sys = CTFlowsSciMLBase.SciMLFunctionSystem(f)
                Test.@test_throws Exceptions.PreconditionError Systems.rhs_oop(sys)
            end
        end

        # ====================================================================
        # UNIT TESTS - build_problem
        # ====================================================================

        Test.@testset "build_problem" begin
            Test.@testset "returns SciMLBaseODEProblem wrapper" begin
                f = ODEFunction((du, u, p, t) -> du .= -u)
                sys = CTFlowsSciMLBase.SciMLFunctionSystem(f)
                integ = Integrators.SciML()
                config = Common.StatePointConfig(0.0, [1.0, 0.0], 1.0)
                prob = Integrators.build_problem(integ, sys, config; variable=2.0)
                Test.@test prob isa CTFlowsSciMLBase.SciMLBaseODEProblem
                Test.@test prob.prob.p == 2.0
            end

            Test.@testset "variable passed directly as p" begin
                f = ODEFunction((du, u, p, t) -> du .= -p .* u)
                sys = CTFlowsSciMLBase.SciMLFunctionSystem(f)
                integ = Integrators.SciML()
                config = Common.StatePointConfig(0.0, [1.0], 1.0)
                prob = Integrators.build_problem(integ, sys, config; variable=3.5)
                Test.@test prob.prob.p == 3.5
            end
        end

        # ====================================================================
        # UNIT TESTS - Base.show
        # ====================================================================

        Test.@testset "Base.show" begin
            Test.@testset "in-place display" begin
                f = ODEFunction((du, u, p, t) -> du .= -u)
                sys = CTFlowsSciMLBase.SciMLFunctionSystem(f)
                str = sprint(show, sys)
                Test.@test occursin("in-place", str)
            end

            Test.@testset "out-of-place display" begin
                f = ODEFunction{false}((u, p, t) -> -u)
                sys = CTFlowsSciMLBase.SciMLFunctionSystem(f)
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
