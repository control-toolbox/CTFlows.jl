module TestInterfaceConfigs

import Test
import CTBase.Exceptions
import CTFlows.Configs
import CTFlows.Traits

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for contract testing
# ==============================================================================

"""
Fake bare config that intentionally does not implement any AbstractConfig stubs.
"""
struct FakeBareConfig <: Configs.AbstractConfig{Float64} end

function test_interface_configs()
    Test.@testset "Interface Configs Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # ERROR TESTS - Interface Stubs
        # ====================================================================

        Test.@testset "ERROR TESTS - Interface Stubs" begin
            Test.@testset "tspan stub throws NotImplemented" begin
                config = FakeBareConfig()
                Test.@test_throws Exceptions.NotImplemented Configs.tspan(config)
            end

            Test.@testset "initial_time stub throws NotImplemented" begin
                config = FakeBareConfig()
                Test.@test_throws Exceptions.NotImplemented Configs.initial_time(config)
            end

            Test.@testset "final_time stub throws NotImplemented" begin
                config = FakeBareConfig()
                Test.@test_throws Exceptions.NotImplemented Configs.final_time(config)
            end

            Test.@testset "initial_condition stub throws NotImplemented" begin
                config = FakeBareConfig()
                Test.@test_throws Exceptions.NotImplemented Configs.initial_condition(config)
            end

            Test.@testset "initial_state stub throws NotImplemented" begin
                config = FakeBareConfig()
                Test.@test_throws Exceptions.NotImplemented Configs.initial_state(config)
            end

            Test.@testset "initial_costate stub throws NotImplemented" begin
                config = FakeBareConfig()
                Test.@test_throws Exceptions.NotImplemented Configs.initial_costate(config)
            end

            Test.@testset "initial_variable_costate stub throws NotImplemented" begin
                config = FakeBareConfig()
                Test.@test_throws Exceptions.NotImplemented Configs.initial_variable_costate(config)
            end
        end

        # ====================================================================
        # ERROR TESTS - Exception Quality
        # ====================================================================

        Test.@testset "ERROR TESTS - Exception Quality" begin
            Test.@testset "NotImplemented error message quality" begin
                config = FakeBareConfig()
                e = try
                    Configs.tspan(config)
                catch err
                    err
                end
                Test.@test e isa Exceptions.NotImplemented
                Test.@test occursin("tspan", string(e))
                Test.@test occursin("not implemented", lowercase(string(e)))
            end
        end
    end
end

end # module

test_interface_configs() = TestInterfaceConfigs.test_interface_configs()
