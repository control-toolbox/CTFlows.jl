module TestODEParameters

using Test: Test
import CTFlows.Common

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Test function
# ==============================================================================

function test_ode_parameters()
    Test.@testset "ODEParameters Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Constructor
        # ====================================================================

        Test.@testset "Constructor" begin
            Test.@testset "accepts nothing for Fixed systems" begin
                params = Common.ODEParameters(nothing)
                Test.@test Common.variable(params) === nothing
            end

            Test.@testset "accepts value for NonFixed systems" begin
                params = Common.ODEParameters(0.5)
                Test.@test Common.variable(params) == 0.5
            end

            Test.@testset "accepts vector for NonFixed systems" begin
                params = Common.ODEParameters([1.0, 2.0])
                Test.@test Common.variable(params) == [1.0, 2.0]
            end
        end

        # ====================================================================
        # UNIT TESTS - Accessor function
        # ====================================================================

        Test.@testset "Accessor function" begin
            Test.@testset "variable accessor returns nothing" begin
                params = Common.ODEParameters(nothing)
                Test.@test Common.variable(params) === nothing
            end

            Test.@testset "variable accessor returns value" begin
                params = Common.ODEParameters(0.5)
                Test.@test Common.variable(params) == 0.5
            end

            Test.@testset "variable accessor returns vector" begin
                params = Common.ODEParameters([1.0, 2.0])
                Test.@test Common.variable(params) == [1.0, 2.0]
            end
        end

        # ====================================================================
        # UNIT TESTS - Type parameters
        # ====================================================================

        Test.@testset "Type parameters" begin
            Test.@testset "infers Nothing type" begin
                params = Common.ODEParameters(nothing)
                Test.@test params isa Common.ODEParameters{Nothing}
            end

            Test.@testset "infers Float64 type" begin
                params = Common.ODEParameters(0.5)
                Test.@test params isa Common.ODEParameters{Float64}
            end

            Test.@testset "infers Vector{Float64} type" begin
                params = Common.ODEParameters([1.0, 2.0])
                Test.@test params isa Common.ODEParameters{Vector{Float64}}
            end
        end
    end
end

end # module

test_ode_parameters() = TestODEParameters.test_ode_parameters()
