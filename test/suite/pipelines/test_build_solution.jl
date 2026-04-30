module TestBuildSolution

import Test
import CTFlows.Systems
import CTFlows.Pipelines

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for testing
# ==============================================================================

struct FakeSystem <: Systems.AbstractSystem
    state_dim::Int
    captured_ode_sol::Ref{Any}
end

function FakeSystem(state_dim)
    return FakeSystem(state_dim, Ref{Any}(nothing))
end

function Systems.rhs!(sys::FakeSystem)
    return (du, u, p, t) -> nothing
end

function Systems.build_solution(sys::FakeSystem, ode_sol)
    sys.captured_ode_sol[] = ode_sol
    return (:packaged, ode_sol)
end

# ==============================================================================
# Test function
# ==============================================================================

function test_build_solution()
    Test.@testset "build_solution Pipeline Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Delegation to System
        # ====================================================================

        Test.@testset "Delegation to System" begin
            sys = FakeSystem(2)
            ode_sol = :fake_ode_solution

            Test.@testset "delegates to system build_solution" begin
                result = Pipelines.build_solution(sys, ode_sol)
                Test.@test result == (:packaged, ode_sol)
            end

            Test.@testset "passes ode_sol to system" begin
                sys = FakeSystem(2)
                Pipelines.build_solution(sys, ode_sol)
                Test.@test sys.captured_ode_sol[] === ode_sol
            end
        end
    end
end

end # module

test_build_solution() = TestBuildSolution.test_build_solution()
