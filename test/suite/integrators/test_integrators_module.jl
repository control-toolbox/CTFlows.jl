module TestIntegratorsModule

import Test
import CTFlows.Integrators

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Test function
# ==============================================================================

function test_integrators_module()
    Test.@testset "Integrators Module Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "AbstractIntegrator is exported" begin
                Test.@test isdefined(Integrators, :AbstractIntegrator)
            end

            Test.@testset "SciML is exported" begin
                Test.@test isdefined(Integrators, :SciML)
            end

            Test.@testset "SciMLTag is exported" begin
                Test.@test isdefined(Integrators, :SciMLTag)
            end

            Test.@testset "build_sciml_integrator is exported" begin
                Test.@test isdefined(Integrators, :build_sciml_integrator)
            end

            Test.@testset "build_integrator is exported" begin
                Test.@test isdefined(Integrators, :build_integrator)
            end
        end

        # ====================================================================
        # UNIT TESTS - Module Loading
        # ====================================================================

        Test.@testset "Module Loading" begin
            Test.@testset "Integrators module exists" begin
                Test.@test @isdefined(Integrators)
            end

            Test.@testset "Integrators is a Module" begin
                Test.@test Integrators isa Module
            end
        end
    end
end

end # module

test_integrators_module() = TestIntegratorsModule.test_integrators_module()