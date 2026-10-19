module TestAqua

using Aqua: Aqua
using Test: Test
using CTBase: CTBase
using CTFlows: CTFlows

# Load every extension trigger before checking extension quality. The quality check must
# not depend on another test file being visited first.
using CairoMakie: CairoMakie
using Plots: Plots
using SciMLBase: SciMLBase
using StaticArrays: StaticArrays

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_aqua()
    Test.@testset "Aqua Quality Checks" verbose=VERBOSE showtiming=SHOWTIMING begin
        Test.@testset "Aqua" begin
            Aqua.test_all(
                CTFlows; ambiguities=false, unbound_args=false, undefined_exports=false
            )
        end

        Test.@testset "Extensions" begin
            CTBase.DevTools.test_extensions_quality(CTFlows)
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
