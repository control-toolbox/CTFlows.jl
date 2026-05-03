module TestBuildingIntegrators

import Test
import CTBase.Exceptions
import CTFlows.Integrators
import CTFlows.Integrators: SciML
using OrdinaryDiffEqTsit5

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Test function
# ==============================================================================

function test_building_integrators()
    Test.@testset "Integrator Building Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - build_integrator
        # ====================================================================

        Test.@testset "build_integrator" begin

            Test.@testset "builds SciML integrator" begin
                # This will throw ExtensionError if CTFlowsSciMLExt is not loaded,
                # but at least it calls the right function
                result = Integrators.build_integrator()
                Test.@test result isa Integrators.SciML
            end

            Test.@testset "forwards keyword options" begin
                result = Integrators.build_integrator(reltol=1e-10)
                Test.@test result isa Integrators.SciML
            end
        end
    end
end

end # module

test_building_integrators() = TestBuildingIntegrators.test_building_integrators()