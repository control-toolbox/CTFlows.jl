module TestODEParameters

using Test: Test
import CTFlows.Systems

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
                params = Systems.ODEParameters(nothing)
                Test.@test Systems.variable(params) === nothing
            end

            Test.@testset "accepts value for NonFixed systems" begin
                params = Systems.ODEParameters(0.5)
                Test.@test Systems.variable(params) == 0.5
            end

            Test.@testset "accepts vector for NonFixed systems" begin
                params = Systems.ODEParameters([1.0, 2.0])
                Test.@test Systems.variable(params) == [1.0, 2.0]
            end
        end

        # ====================================================================
        # UNIT TESTS - Accessor function
        # ====================================================================

        Test.@testset "Accessor function" begin
            Test.@testset "variable accessor returns nothing" begin
                params = Systems.ODEParameters(nothing)
                Test.@test Systems.variable(params) === nothing
            end

            Test.@testset "variable accessor returns value" begin
                params = Systems.ODEParameters(0.5)
                Test.@test Systems.variable(params) == 0.5
            end

            Test.@testset "variable accessor returns vector" begin
                params = Systems.ODEParameters([1.0, 2.0])
                Test.@test Systems.variable(params) == [1.0, 2.0]
            end
        end

        # ====================================================================
        # UNIT TESTS - Type parameters
        # ====================================================================

        Test.@testset "Type parameters" begin
            Test.@testset "infers Nothing type" begin
                params = Systems.ODEParameters(nothing)
                Test.@test params isa Systems.ODEParameters{Nothing}
            end

            Test.@testset "infers Float64 type" begin
                params = Systems.ODEParameters(0.5)
                Test.@test params isa Systems.ODEParameters{Float64}
            end

            Test.@testset "infers Vector{Float64} type" begin
                params = Systems.ODEParameters([1.0, 2.0])
                Test.@test params isa Systems.ODEParameters{Vector{Float64}}
            end
        end
    end
end

end # module

test_ode_parameters() = TestODEParameters.test_ode_parameters()
