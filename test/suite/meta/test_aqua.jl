module TestAqua

import Aqua
import Test
import CTFlows

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_aqua()
    Test.@testset "Aqua Quality Checks" verbose=VERBOSE showtiming=SHOWTIMING begin

        Test.@testset "Aqua" begin
            Aqua.test_all(CTFlows; ambiguities=false, unbound_args=false, undefined_exports=false)
        end

        Test.@testset "Ambiguities" begin
            Aqua.test_ambiguities(CTFlows)
        end

        Test.@testset "Unbound Args" begin
            Aqua.test_unbound_args(CTFlows)
        end

        Test.@testset "Undefined Exports" begin
            Aqua.test_undefined_exports(CTFlows)
        end
    end
end

end # module

test_aqua() = TestAqua.test_aqua()
