module TestFlowCallablesSciMLVectorField

import Test
import CTFlows.Systems
import CTFlows.Flows
import CTFlows.Integrators
import CTFlows.Solutions
import CTFlows.Common
import CTFlows.Data

using SciMLBase: SciMLBase
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, Tsit5
using StaticArrays: SA, SVector, MVector
using ForwardDiff: ForwardDiff

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Reference systems for numerical testing
# ==============================================================================

# For StateFlow: exponential decay  x' = -x  -> x(t) = x0 * exp(-t)
const VF_DECAY    = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
const SYS_DECAY   = Systems.VectorFieldSystem(VF_DECAY)
const VF_DECAY_IP = Data.VectorField((du, x) -> (du .= -x); is_autonomous=true, is_variable=false)
const SYS_DECAY_IP = Systems.VectorFieldSystem(VF_DECAY_IP)
const INTEG = Integrators.SciML()
const ATOL  = 1e-5

# ==============================================================================
# Test function
# ==============================================================================

function test_flow_callables_sciml_vector_field()
    Test.@testset "Flow Callables SciML VectorField Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # INTEGRATION TESTS - StateFlow StateEndPointConfig
        # ====================================================================

        Test.@testset "StateFlow StateEndPointConfig" begin
            flow = Flows.build_flow(SYS_DECAY, INTEG)

            Test.@testset "scalar Real x0" begin
                xf = flow(0.0, 1.0, 1.0)
                Test.@test xf isa Real
                Test.@test xf ≈ exp(-1.0)  atol=ATOL
            end

            Test.@testset "vector x0" begin
                xf = flow(0.0, [1.0, 2.0], 1.0)
                Test.@test xf isa AbstractVector
                Test.@test length(xf) == 2
                Test.@test xf ≈ [exp(-1.0), 2*exp(-1.0)]  atol=ATOL
            end

            Test.@testset "SVector x0" begin
                xf = flow(0.0, SA[1.0, 2.0], 1.0)
                Test.@test xf isa AbstractVector
                Test.@test length(xf) == 2
                Test.@test xf ≈ [exp(-1.0), 2*exp(-1.0)]  atol=ATOL
            end

            Test.@testset "MVector x0" begin
                xf = flow(0.0, MVector{2}(1.0, 2.0), 1.0)
                Test.@test xf isa AbstractVector
                Test.@test length(xf) == 2
                Test.@test xf ≈ [exp(-1.0), 2*exp(-1.0)]  atol=ATOL
            end

            Test.@testset "scalar complex x0" begin
                xf = flow(0.0, 1.0+2.0im, 1.0)
                Test.@test xf isa Complex
                Test.@test xf ≈ (1.0+2.0im) * exp(-1.0)  atol=ATOL
            end

            Test.@testset "complex vector x0" begin
                xf = flow(0.0, [1.0+2.0im, 3.0+4.0im], 1.0)
                Test.@test xf isa AbstractVector
                Test.@test length(xf) == 2
                Test.@test xf ≈ [1.0+2.0im, 3.0+4.0im] * exp(-1.0)  atol=ATOL
            end

            Test.@testset "SVector complex x0" begin
                xf = flow(0.0, SA[1.0+2.0im, 3.0+4.0im], 1.0)
                Test.@test xf isa AbstractVector
                Test.@test length(xf) == 2
                Test.@test xf ≈ [exp(-1.0)*(1.0+2.0im), exp(-1.0)*(3.0+4.0im)]  atol=ATOL
            end

            Test.@testset "ForwardDiff.Dual scalar x0" begin
                x0 = ForwardDiff.Dual(1.0, 1.0)
                xf = flow(0.0, x0, 1.0)
                Test.@test xf isa ForwardDiff.Dual
                Test.@test ForwardDiff.value(xf) ≈ exp(-1.0)  atol=ATOL
            end

            Test.@testset "ForwardDiff.Dual vector x0" begin
                x0 = [ForwardDiff.Dual(1.0, 1.0), ForwardDiff.Dual(2.0, 0.0)]
                xf = flow(0.0, x0, 1.0)
                Test.@test xf isa AbstractVector
                Test.@test length(xf) == 2
                Test.@test ForwardDiff.value(xf[1]) ≈ exp(-1.0)  atol=ATOL
                Test.@test ForwardDiff.value(xf[2]) ≈ 2*exp(-1.0)  atol=ATOL
            end

            Test.@testset "matrix x0" begin
                X0 = [1.0 2.0; 3.0 4.0]
                Xf = flow(0.0, X0, 1.0)
                Test.@test Xf isa AbstractMatrix
                Test.@test size(Xf) == (2, 2)
                Test.@test Xf ≈ X0 * exp(-1.0)  atol=ATOL
            end

            Test.@testset "complex matrix x0" begin
                X0 = [1.0+2.0im  5.0+6.0im; 3.0+4.0im  7.0+8.0im]
                Xf = flow(0.0, X0, 1.0)
                Test.@test Xf isa AbstractMatrix
                Test.@test size(Xf) == (2, 2)
                Test.@test Xf ≈ X0 * exp(-1.0)  atol=ATOL
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - StateFlow StateTrajectoryConfig
        # ====================================================================

        Test.@testset "StateFlow StateTrajectoryConfig" begin
            flow = Flows.build_flow(SYS_DECAY, INTEG)

            Test.@testset "vector x0" begin
                sol = flow((0.0, 1.0), [1.0, 2.0])
                Test.@test sol isa Solutions.VectorFieldSolution
            end

            Test.@testset "SVector x0" begin
                sol = flow((0.0, 1.0), SA[1.0, 2.0])
                Test.@test sol isa Solutions.VectorFieldSolution
            end

            Test.@testset "MVector x0" begin
                sol = flow((0.0, 1.0), MVector{2}(1.0, 2.0))
                Test.@test sol isa Solutions.VectorFieldSolution
            end

            Test.@testset "matrix x0" begin
                sol = flow((0.0, 1.0), [1.0 2.0; 3.0 4.0])
                Test.@test sol isa Solutions.VectorFieldSolution
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - InPlace StateFlow
        # ====================================================================

        Test.@testset "InPlace StateFlow" begin
            flow = Flows.build_flow(SYS_DECAY_IP, INTEG)

            Test.@testset "IP VF + Vector u0 (no warning)" begin
                xf = flow(0.0, [1.0, 2.0], 1.0)
                Test.@test xf ≈ [exp(-1.0), 2*exp(-1.0)]  atol=ATOL
            end

            Test.@testset "IP VF + SVector u0 (warns)" begin
                xf = Test.@test_logs (:warn, r"InPlace VectorField") flow(0.0, SA[1.0, 2.0], 1.0)
                Test.@test xf ≈ [exp(-1.0), 2*exp(-1.0)]  atol=ATOL
            end

            Test.@testset "IP VF + MVector u0 (no warning)" begin
                xf = flow(0.0, MVector{2}(1.0, 2.0), 1.0)
                Test.@test xf ≈ [exp(-1.0), 2*exp(-1.0)]  atol=ATOL
            end
        end
    end
end

end # module

test_flow_callables_sciml_vector_field() = TestFlowCallablesSciMLVectorField.test_flow_callables_sciml_vector_field()
