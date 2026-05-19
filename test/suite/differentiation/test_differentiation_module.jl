"""
Module loading and exports tests for the Differentiation submodule.
"""

module TestDifferentiationModule

import Test
import CTFlows
import CTFlows.Differentiation

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_differentiation_module()
    Test.@testset "Differentiation Module Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        Test.@testset "Exports Verification" begin
            # Verify all expected exports are defined
            Test.@test isdefined(Differentiation, :AbstractADBackend)
            Test.@test isdefined(Differentiation, :DifferentiationInterface)
            Test.@test isdefined(Differentiation, :build_ad_backend)
            Test.@test isdefined(Differentiation, :hamiltonian_gradient)
            Test.@test isdefined(Differentiation, :variable_gradient)
            Test.@test isdefined(Differentiation, :prepare_cache)
        end

        Test.@testset "Module Loading" begin
            # Verify the Differentiation submodule is loaded
            Test.@test CTFlows.Differentiation isa Module
        end

    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_differentiation_module() = TestDifferentiationModule.test_differentiation_module()

