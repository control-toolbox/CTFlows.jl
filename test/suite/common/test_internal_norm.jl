module TestInternalNorm

import Test
import CTFlows.Common: Common

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_internal_norm()
    Test.@testset "Internal Norm Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - deepvalue
        # ====================================================================

        Test.@testset "deepvalue" begin
            Test.@testset "deepvalue(x::Real) is identity" begin
                Test.@test Common.deepvalue(1.0) === 1.0
                Test.@test Common.deepvalue(2.5) === 2.5
                Test.@test Common.deepvalue(-3.0) === -3.0
                Test.@test Common.deepvalue(0.0) === 0.0
            end
        end

        # ====================================================================
        # UNIT TESTS - real_norm
        # ====================================================================

        Test.@testset "real_norm" begin
            Test.@testset "real_norm(u::Real, t) is abs" begin
                Test.@test Common.real_norm(3.0, 0.0) === 3.0
                Test.@test Common.real_norm(-5.0, 0.0) === 5.0
                Test.@test Common.real_norm(0.0, 0.0) === 0.0
                Test.@test Common.real_norm(2.5, 1.0) === 2.5
            end
        end

    end
end

end # module

test_internal_norm() = TestInternalNorm.test_internal_norm()