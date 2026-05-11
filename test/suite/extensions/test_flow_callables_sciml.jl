module TestFlowCallablesSciML

import Test
import CTFlows.Systems
import CTFlows.Flows
import CTFlows.Integrators
import CTFlows.Solutions
import CTFlows.Common
import CTFlows.Data

using SciMLBase: SciMLBase
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, Tsit5
using StaticArrays: SA, SMatrix, StaticArrays

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Reference systems for numerical testing
# ==============================================================================

# For StateFlow: exponential decay  x' = -x  -> x(t) = x0 * exp(-t)
const VF_DECAY = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
const SYS_DECAY = Systems.VectorFieldSystem(VF_DECAY)
const INTEG = Integrators.SciML()

# For HamiltonianFlow: harmonic oscillator  (x' = p, p' = -x)
# Solution: x(t) = x0 cos(t) + p0 sin(t),  p(t) = -x0 sin(t) + p0 cos(t)
const HVF_HARMONIC = Data.HamiltonianVectorField((x, p) -> (p, -x); is_autonomous=true, is_variable=false)
const HSYS_NO_N = Systems.HamiltonianVectorFieldSystem(HVF_HARMONIC)           # N=nothing
const HSYS_N1  = Systems.HamiltonianVectorFieldSystem(HVF_HARMONIC, 1)         # N=1 (scalar)
const HSYS_N2  = Systems.HamiltonianVectorFieldSystem(HVF_HARMONIC, 2)         # N=2 (for SVector)
const ATOL = 1e-5

# ==============================================================================
# Test function
# ==============================================================================

function test_flow_callables_sciml()
    Test.@testset "Flow Callables SciML Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # INTEGRATION TESTS - StateFlow StatePointConfig
        # ====================================================================

        Test.@testset "StateFlow StatePointConfig" begin
            flow = Flows.build_flow(SYS_DECAY, INTEG)

            Test.@testset "scalar x0" begin
                xf = flow(0.0, 1.0, 1.0)
                Test.@test xf isa Real
                Test.@test xf ≈ exp(-1.0)  atol=ATOL
            end

            Test.@testset "scalar complex x0" begin
                xf = flow(0.0, 1.0+2.0im, 1.0)
                Test.@test xf isa Complex
                Test.@test xf ≈ (1.0+2.0im) * exp(-1.0)  atol=ATOL
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

            Test.@testset "SVector complex x0" begin
                xf = flow(0.0, SA[1.0+2.0im, 3.0+4.0im], 1.0)
                Test.@test xf isa AbstractVector
                Test.@test length(xf) == 2
                Test.@test xf ≈ [exp(-1.0)*(1.0+2.0im), exp(-1.0)*(3.0+4.0im)]  atol=ATOL
            end

            Test.@testset "matrix x0" begin
                X0 = [1.0 2.0; 3.0 4.0]
                Xf = flow(0.0, X0, 1.0)
                Test.@test Xf isa AbstractMatrix
                Test.@test size(Xf) == (2, 2)
                Test.@test Xf ≈ X0 * exp(-1.0)  atol=ATOL
            end

            Test.@testset "complex vector x0" begin
                xf = flow(0.0, [1.0+2.0im, 3.0+4.0im], 1.0)
                Test.@test xf isa AbstractVector
                Test.@test length(xf) == 2
                Test.@test xf ≈ [1.0+2.0im, 3.0+4.0im] * exp(-1.0)  atol=ATOL
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

            Test.@testset "matrix x0" begin
                sol = flow((0.0, 1.0), [1.0 2.0; 3.0 4.0])
                Test.@test sol isa Solutions.VectorFieldSolution
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - HamiltonianFlow HamiltonianPointConfig
        # ====================================================================

        Test.@testset "HamiltonianFlow HamiltonianPointConfig" begin
            Test.@testset "scalar x0, p0" begin
                hflow = Flows.build_flow(HSYS_N1, INTEG)
                xf, pf = hflow(0.0, 1.0, 0.0, π/2)
                Test.@test xf isa Real
                Test.@test pf isa Real
                Test.@test xf ≈ 0.0  atol=ATOL
                Test.@test pf ≈ -1.0  atol=ATOL
            end

            Test.@testset "scalar complex x0, p0" begin
                hflow = Flows.build_flow(HSYS_N1, INTEG)
                xf, pf = hflow(0.0, 1.0+2.0im, 0.0+0.0im, π/2)
                Test.@test xf isa Complex
                Test.@test pf isa Complex
                Test.@test xf ≈ 0.0+0.0im  atol=ATOL
                Test.@test pf ≈ -(1.0+2.0im)  atol=ATOL
            end

            Test.@testset "vector x0, p0" begin
                hflow = Flows.build_flow(HSYS_NO_N, INTEG)
                xf, pf = hflow(0.0, [1.0, 0.0], [0.0, 1.0], π/2)
                Test.@test xf isa AbstractVector && length(xf) == 2
                Test.@test pf isa AbstractVector && length(pf) == 2
                Test.@test xf ≈ [0.0, 1.0]  atol=ATOL
                Test.@test pf ≈ [-1.0, 0.0]  atol=ATOL
            end

            Test.@testset "SVector x0, p0 (N known)" begin
                hflow = Flows.build_flow(HSYS_N2, INTEG)
                xf, pf = hflow(0.0, SA[1.0, 0.0], SA[0.0, 1.0], π/2)
                Test.@test xf isa AbstractVector
                Test.@test pf isa AbstractVector
                Test.@test xf ≈ [0.0, 1.0]  atol=ATOL
                Test.@test pf ≈ [-1.0, 0.0]  atol=ATOL
            end

            Test.@testset "SVector x0, p0 (N nothing)" begin
                hflow = Flows.build_flow(HSYS_NO_N, INTEG)
                xf, pf = hflow(0.0, SA[1.0, 0.0], SA[0.0, 1.0], π/2)
                Test.@test xf isa AbstractVector
                Test.@test pf isa AbstractVector
                Test.@test xf ≈ [0.0, 1.0]  atol=ATOL
                Test.@test pf ≈ [-1.0, 0.0]  atol=ATOL
            end

            Test.@testset "SVector complex x0, p0" begin
                hflow = Flows.build_flow(HSYS_N2, INTEG)
                xf, pf = hflow(0.0, SA[1.0+2.0im, 0.0+0.0im], SA[0.0+0.0im, 1.0+1.0im], π/2)
                Test.@test xf isa AbstractVector
                Test.@test pf isa AbstractVector
                Test.@test xf ≈ SA[0.0+0.0im, 1.0+1.0im]  atol=ATOL
                Test.@test pf ≈ SA[-1.0-2.0im, 0.0+0.0im]  atol=ATOL
            end

            Test.@testset "matrix x0, p0" begin
                hflow = Flows.build_flow(HSYS_NO_N, INTEG)
                X0 = [1.0 2.0; 3.0 4.0]
                P0 = [0.0 0.0; 1.0 1.0]
                Xf, Pf = hflow(0.0, X0, P0, π/2)
                Test.@test Xf isa AbstractMatrix
                Test.@test Pf isa AbstractMatrix
                Test.@test size(Xf) == (2, 2)
                Test.@test size(Pf) == (2, 2)
                # For harmonic oscillator: x(t) = x0 cos(t) + p0 sin(t), p(t) = -x0 sin(t) + p0 cos(t)
                # At t=π/2: x(π/2) = p0, p(π/2) = -x0
                Test.@test Xf ≈ P0  atol=ATOL
                Test.@test Pf ≈ -X0  atol=ATOL
            end

            Test.@testset "SMatrix x0, p0 (N known)" begin
                hflow = Flows.build_flow(HSYS_N2, INTEG)
                X0 = SMatrix{2,2}(1.0, 3.0, 2.0, 4.0)  # column-major: [1 2; 3 4]
                P0 = SMatrix{2,2}(0.0, 1.0, 0.0, 1.0)  # column-major: [0 0; 1 1]
                Xf, Pf = hflow(0.0, X0, P0, π/2)
                # vcat(SMatrix, SMatrix) → Matrix, so ODE returns AbstractMatrix
                Test.@test Xf isa AbstractMatrix
                Test.@test Pf isa AbstractMatrix
                Test.@test Xf ≈ P0  atol=ATOL
                Test.@test Pf ≈ -X0  atol=ATOL
            end

            Test.@testset "SMatrix x0, p0 (N nothing)" begin
                hflow = Flows.build_flow(HSYS_NO_N, INTEG)
                X0 = SMatrix{2,2}(1.0, 3.0, 2.0, 4.0)
                P0 = SMatrix{2,2}(0.0, 1.0, 0.0, 1.0)
                Xf, Pf = hflow(0.0, X0, P0, π/2)
                # vcat(SMatrix, SMatrix) → Matrix, so ODE returns AbstractMatrix
                Test.@test Xf isa AbstractMatrix
                Test.@test Pf isa AbstractMatrix
                Test.@test Xf ≈ P0  atol=ATOL
                Test.@test Pf ≈ -X0  atol=ATOL
            end

            Test.@testset "complex vector x0, p0" begin
                hflow = Flows.build_flow(HSYS_NO_N, INTEG)
                # x' = p, p' = -x  →  at t=π/2: xf = p0, pf = -x0
                x0 = [1.0+2.0im, 0.0+0.0im]
                p0 = [0.0+0.0im, 1.0+1.0im]
                xf, pf = hflow(0.0, x0, p0, π/2)
                Test.@test xf isa AbstractVector
                Test.@test pf isa AbstractVector
                Test.@test xf ≈ p0  atol=ATOL
                Test.@test pf ≈ -x0  atol=ATOL
            end

            Test.@testset "complex matrix x0, p0" begin
                hflow = Flows.build_flow(HSYS_NO_N, INTEG)
                # x' = p, p' = -x  →  at t=π/2: Xf = P0, Pf = -X0
                X0 = [1.0+2.0im  5.0+6.0im; 3.0+4.0im  7.0+8.0im]
                P0 = [0.0+0.0im  1.0+1.0im; 2.0+2.0im  3.0+3.0im]
                Xf, Pf = hflow(0.0, X0, P0, π/2)
                Test.@test Xf isa AbstractMatrix
                Test.@test Pf isa AbstractMatrix
                Test.@test Xf ≈ P0  atol=ATOL
                Test.@test Pf ≈ -X0  atol=ATOL
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - HamiltonianFlow HamiltonianTrajectoryConfig
        # ====================================================================

        Test.@testset "HamiltonianFlow HamiltonianTrajectoryConfig" begin
            Test.@testset "scalar x0, p0" begin
                hflow = Flows.build_flow(HSYS_N1, INTEG)
                sol = hflow((0.0, π/2), 1.0, 0.0)
                Test.@test sol isa Solutions.HamiltonianVectorFieldSolution
            end

            Test.@testset "vector x0, p0" begin
                hflow = Flows.build_flow(HSYS_NO_N, INTEG)
                sol = hflow((0.0, π/2), [1.0, 0.0], [0.0, 1.0])
                Test.@test sol isa Solutions.HamiltonianVectorFieldSolution
            end

            Test.@testset "SVector x0, p0" begin
                hflow = Flows.build_flow(HSYS_N2, INTEG)
                sol = hflow((0.0, π/2), SA[1.0, 0.0], SA[0.0, 1.0])
                Test.@test sol isa Solutions.HamiltonianVectorFieldSolution
            end
        end
    end
end

end # module

test_flow_callables_sciml() = TestFlowCallablesSciML.test_flow_callables_sciml()
