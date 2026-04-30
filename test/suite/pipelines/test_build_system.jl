module TestBuildSystem

import Test
import CTFlows.Systems
import CTFlows.Pipelines
import CTFlows.Common

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Test function
# ==============================================================================

function test_build_system()
    Test.@testset "build_system Pipeline Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - VectorField System Building
        # ====================================================================

        Test.@testset "VectorField System Building" begin
            Test.@testset "builds VectorFieldSystem from VectorField" begin
                vf = Systems.VectorField(x -> x, Common.Autonomous, Common.Fixed)
                system = Pipelines.build_system(vf)
                Test.@test system isa Systems.VectorFieldSystem
                Test.@test system isa Systems.AbstractSystem
            end
        end
    end
end

end # module

test_build_system() = TestBuildSystem.test_build_system()
