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

            Test.@testset "valid id :sciml" begin
                # This will throw ExtensionError if CTFlowsSciMLExt is not loaded,
                # but at least it dispatches correctly
                result = Integrators.build_integrator(:sciml)
                Test.@test result isa SciML
            end

            Test.@testset "unknown id throws IncorrectArgument" begin
                Test.@test_throws Exceptions.IncorrectArgument Integrators.build_integrator(:unknown)
            end

            Test.@testset "error message for unknown id" begin
                try
                    Integrators.build_integrator(:fake)
                    Test.@test false  # Should not reach here
                catch err
                    Test.@test err isa Exceptions.IncorrectArgument
                    msg = sprint(showerror, err)
                    Test.@test occursin("Unknown integrator id", msg)
                    Test.@test occursin(":sciml", msg)
                end
            end
        end
    end
end

end # module

test_building_integrators() = TestBuilding.test_building_integrators()