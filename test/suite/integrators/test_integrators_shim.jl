module TestIntegratorsShim

import Test
import CTFlows.Integrators: Integrators
import CTSolvers.Integrators as CTSI

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# The CTFlows.Integrators submodule is a thin shim: it re-exports the generic
# integrator surface from CTSolvers.Integrators, and owns only the two
# domain-specific glue generics `build_problem` / `build_options`.
# ==============================================================================

function test_integrators_shim()
    Test.@testset "Integrators shim" verbose=VERBOSE showtiming=SHOWTIMING begin

        Test.@testset "re-exported types resolve to CTSolvers" begin
            Test.@test Integrators.AbstractIntegrator === CTSI.AbstractIntegrator
            Test.@test Integrators.SciML === CTSI.SciML
            Test.@test Integrators.AbstractIntegrationResult === CTSI.AbstractIntegrationResult
        end

        Test.@testset "re-exported functions resolve to CTSolvers" begin
            Test.@test Integrators.final_state === CTSI.final_state
            Test.@test Integrators.times === CTSI.times
            Test.@test Integrators.evaluate_at === CTSI.evaluate_at
            Test.@test Integrators.merge === CTSI.merge
            Test.@test Integrators.build_integrator === CTSI.build_integrator
            Test.@test Integrators.options_point === CTSI.options_point
            Test.@test Integrators.options_trajectory === CTSI.options_trajectory
        end

        Test.@testset "glue generics are owned by CTFlows.Integrators" begin
            Test.@test parentmodule(Integrators.build_problem) === Integrators
            Test.@test parentmodule(Integrators.build_options) === Integrators
            # CTSolvers must NOT define these (they are CTFlows glue, typed on Systems/Configs)
            Test.@test !isdefined(CTSI, :build_problem)
            Test.@test !isdefined(CTSI, :build_options)
        end
    end
end

end # module

test_integrators_shim() = TestIntegratorsShim.test_integrators_shim()
