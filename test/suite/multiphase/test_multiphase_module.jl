module TestMultiPhaseModule

import Test
import CTFlows.MultiPhase

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_multiphase_module()
    Test.@testset "MultiPhase Module Exports" verbose=VERBOSE showtiming=SHOWTIMING begin

        Test.@testset "Types are exported" begin
            Test.@testset "MultiPhaseStateFlow" begin
                Test.@test isdefined(MultiPhase, :MultiPhaseStateFlow)
            end

            Test.@testset "MultiPhaseHamiltonianFlow" begin
                Test.@test isdefined(MultiPhase, :MultiPhaseHamiltonianFlow)
            end
        end
    end
end

end # module

test_multiphase_module() = TestMultiPhaseModule.test_multiphase_module()
