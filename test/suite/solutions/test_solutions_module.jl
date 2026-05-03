module TestSolutionsModule

import Test
import CTFlows.Solutions

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Test function
# ==============================================================================

function test_solutions_module()
    Test.@testset "Solutions Module Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "VectorFieldSolution is exported" begin
                Test.@test isdefined(Solutions, :VectorFieldSolution)
            end

            Test.@testset "build_solution is exported" begin
                Test.@test isdefined(Solutions, :build_solution)
            end
        end

        # ====================================================================
        # UNIT TESTS - Module Loading
        # ====================================================================

        Test.@testset "Module Loading" begin
            Test.@testset "Solutions module exists" begin
                Test.@test @isdefined(Solutions)
            end

            Test.@testset "Solutions is a Module" begin
                Test.@test Solutions isa Module
            end
        end
    end
end

end # module

test_solutions_module() = TestSolutionsModule.test_solutions_module()