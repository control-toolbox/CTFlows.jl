module TestFlowCallablesSciMLHamiltonianVectorField

using Test: Test
import CTFlows.Systems
import CTFlows.Flows
import CTFlows.Integrators
import CTFlows.Trajectories
import CTBase.Data

using SciMLBase: SciMLBase
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, Tsit5
using StaticArrays: SA, SVector, MVector, SMatrix
using ForwardDiff: ForwardDiff

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Reference systems for numerical testing
# ==============================================================================

# For HamiltonianFlow: harmonic oscillator  (x' = p, p' = -x)
# Solution: x(t) = x0 cos(t) + p0 sin(t),  p(t) = -x0 sin(t) + p0 cos(t)
const HVF_HARMONIC = Data.HamiltonianVectorField(
    (x, p) -> (p, -x); is_autonomous=true, is_variable=false
)
const HSYS = Systems.HamiltonianVectorFieldSystem(HVF_HARMONIC)           # lazy (N inferred at build_problem time)
const ATOL = 1e-5

# InPlace variants (same dynamics, different function signature)
const HVF_HARMONIC_IP = Data.HamiltonianVectorField(
    (dx, dp, x, p) -> (dx.=p; dp.=(-x)); is_autonomous=true, is_variable=false
)
const HSYS_IP = Systems.HamiltonianVectorFieldSystem(HVF_HARMONIC_IP)

const INTEG = Integrators.SciML()

# ==============================================================================
# Test function
# ==============================================================================

function test_flow_callables_sciml_hamiltonian_vector_field()
    Test.@testset "Flow Callables SciML HamiltonianVectorField Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # INTEGRATION TESTS - HamiltonianFlow HamiltonianEndPointConfig
        # ====================================================================

        Test.@testset "HamiltonianFlow HamiltonianEndPointConfig" begin
            Test.@testset "scalar x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                xf, pf = hflow(0.0, 1.0, 0.0, π/2)
                Test.@test xf isa Real
                Test.@test pf isa Real
                Test.@test xf ≈ 0.0 atol=ATOL
                Test.@test pf ≈ -1.0 atol=ATOL
            end

            Test.@testset "scalar complex x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                xf, pf = hflow(0.0, 1.0+2.0im, 0.0+0.0im, π/2)
                Test.@test xf isa Complex
                Test.@test pf isa Complex
                Test.@test xf ≈ 0.0+0.0im atol=ATOL
                Test.@test pf ≈ -(1.0+2.0im) atol=ATOL
            end

            Test.@testset "vector x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                xf, pf = hflow(0.0, [1.0, 0.0], [0.0, 1.0], π/2)
                Test.@test xf isa AbstractVector && length(xf) == 2
                Test.@test pf isa AbstractVector && length(pf) == 2
                Test.@test xf ≈ [0.0, 1.0] atol=ATOL
                Test.@test pf ≈ [-1.0, 0.0] atol=ATOL
            end

            Test.@testset "SVector x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                xf, pf = hflow(0.0, SA[1.0, 0.0], SA[0.0, 1.0], π/2)
                Test.@test xf isa AbstractVector
                Test.@test pf isa AbstractVector
                Test.@test xf ≈ [0.0, 1.0] atol=ATOL
                Test.@test pf ≈ [-1.0, 0.0] atol=ATOL
            end

            Test.@testset "MVector x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                xf, pf = hflow(0.0, MVector{2}(1.0, 0.0), MVector{2}(0.0, 1.0), π/2)
                Test.@test xf isa AbstractVector
                Test.@test pf isa AbstractVector
                Test.@test xf ≈ [0.0, 1.0] atol=ATOL
                Test.@test pf ≈ [-1.0, 0.0] atol=ATOL
            end

            Test.@testset "SVector complex x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                xf, pf = hflow(
                    0.0, SA[1.0 + 2.0im, 0.0 + 0.0im], SA[0.0 + 0.0im, 1.0 + 1.0im], π/2
                )
                Test.@test xf isa AbstractVector
                Test.@test pf isa AbstractVector
                Test.@test xf ≈ SA[0.0 + 0.0im, 1.0 + 1.0im] atol=ATOL
                Test.@test pf ≈ SA[-1.0 - 2.0im, 0.0 + 0.0im] atol=ATOL
            end

            Test.@testset "matrix x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                X0 = [1.0 2.0; 3.0 4.0]
                P0 = [0.0 0.0; 1.0 1.0]
                Xf, Pf = hflow(0.0, X0, P0, π/2)
                Test.@test Xf isa AbstractMatrix
                Test.@test Pf isa AbstractMatrix
                Test.@test size(Xf) == (2, 2)
                Test.@test size(Pf) == (2, 2)
                # For harmonic oscillator: x(t) = x0 cos(t) + p0 sin(t), p(t) = -x0 sin(t) + p0 cos(t)
                # At t=π/2: x(π/2) = p0, p(π/2) = -x0
                Test.@test Xf ≈ P0 atol=ATOL
                Test.@test Pf ≈ -X0 atol=ATOL
            end

            Test.@testset "SMatrix x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                X0 = SMatrix{2,2}(1.0, 3.0, 2.0, 4.0)  # column-major: [1 2; 3 4]
                P0 = SMatrix{2,2}(0.0, 1.0, 0.0, 1.0)  # column-major: [0 0; 1 1]
                Xf, Pf = hflow(0.0, X0, P0, π/2)
                # vcat(SMatrix, SMatrix) → Matrix, so ODE returns AbstractMatrix
                Test.@test Xf isa AbstractMatrix
                Test.@test Pf isa AbstractMatrix
                Test.@test Xf ≈ P0 atol=ATOL
                Test.@test Pf ≈ -X0 atol=ATOL
            end

            Test.@testset "complex vector x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                # x' = p, p' = -x  →  at t=π/2: xf = p0, pf = -x0
                x0 = [1.0+2.0im, 0.0+0.0im]
                p0 = [0.0+0.0im, 1.0+1.0im]
                xf, pf = hflow(0.0, x0, p0, π/2)
                Test.@test xf isa AbstractVector
                Test.@test pf isa AbstractVector
                Test.@test xf ≈ p0 atol=ATOL
                Test.@test pf ≈ -x0 atol=ATOL
            end

            Test.@testset "complex matrix x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                # x' = p, p' = -x  →  at t=π/2: Xf = P0, Pf = -X0
                X0 = [1.0+2.0im 5.0+6.0im; 3.0+4.0im 7.0+8.0im]
                P0 = [0.0+0.0im 1.0+1.0im; 2.0+2.0im 3.0+3.0im]
                Xf, Pf = hflow(0.0, X0, P0, π/2)
                Test.@test Xf isa AbstractMatrix
                Test.@test Pf isa AbstractMatrix
                Test.@test Xf ≈ P0 atol=ATOL
                Test.@test Pf ≈ -X0 atol=ATOL
            end

            Test.@testset "1×1 matrix x0, p0 → matrix output" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                X0 = fill(1.0, 1, 1)
                P0 = fill(0.0, 1, 1)
                Xf, Pf = hflow(0.0, X0, P0, π/2)
                Test.@test Xf isa AbstractMatrix   # must NOT collapse to scalar
                Test.@test Pf isa AbstractMatrix
                Test.@test size(Xf) == (1, 1)
                Test.@test size(Pf) == (1, 1)
                Test.@test Xf ≈ P0 atol=ATOL
                Test.@test Pf ≈ -X0 atol=ATOL
            end

            Test.@testset "ForwardDiff.Dual scalar x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                x0 = ForwardDiff.Dual(1.0, 1.0)
                p0 = ForwardDiff.Dual(0.0, 0.0)
                xf, pf = hflow(0.0, x0, p0, π/2)
                Test.@test xf isa ForwardDiff.Dual
                Test.@test pf isa ForwardDiff.Dual
                Test.@test ForwardDiff.value(xf) ≈ 0.0 atol=ATOL
                Test.@test ForwardDiff.value(pf) ≈ -1.0 atol=ATOL
            end

            Test.@testset "ForwardDiff.Dual vector x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                x0 = [ForwardDiff.Dual(1.0, 1.0), ForwardDiff.Dual(0.0, 0.0)]
                p0 = [ForwardDiff.Dual(0.0, 0.0), ForwardDiff.Dual(1.0, 0.0)]
                xf, pf = hflow(0.0, x0, p0, π/2)
                Test.@test xf isa AbstractVector
                Test.@test pf isa AbstractVector
                Test.@test ForwardDiff.value(xf[1]) ≈ 0.0 atol=ATOL
                Test.@test ForwardDiff.value(pf[1]) ≈ -1.0 atol=ATOL
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - HamiltonianFlow HamiltonianTrajectoryConfig
        # ====================================================================

        Test.@testset "HamiltonianFlow HamiltonianTrajectoryConfig" begin
            Test.@testset "scalar x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                sol = hflow((0.0, π/2), 1.0, 0.0)
                Test.@test sol isa Trajectories.HamiltonianVectorFieldTrajectory
            end

            Test.@testset "vector x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                sol = hflow((0.0, π/2), [1.0, 0.0], [0.0, 1.0])
                Test.@test sol isa Trajectories.HamiltonianVectorFieldTrajectory
            end

            Test.@testset "SVector x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                sol = hflow((0.0, π/2), SA[1.0, 0.0], SA[0.0, 1.0])
                Test.@test sol isa Trajectories.HamiltonianVectorFieldTrajectory
            end

            Test.@testset "MVector x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                sol = hflow((0.0, π/2), MVector{2}(1.0, 0.0), MVector{2}(0.0, 1.0))
                Test.@test sol isa Trajectories.HamiltonianVectorFieldTrajectory
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - InPlace HamiltonianFlow
        # ====================================================================

        Test.@testset "InPlace HamiltonianFlow" begin
            Test.@testset "IP HVF + Vector u0 (no warning)" begin
                hflow = Flows.build_flow(HSYS_IP, INTEG)
                xf, pf = hflow(0.0, 1.0, 0.0, π/2)
                Test.@test xf ≈ 0.0 atol=ATOL
                Test.@test pf ≈ -1.0 atol=ATOL
            end

            Test.@testset "IP HVF + SVector u0 (warns)" begin
                hflow = Flows.build_flow(HSYS_IP, INTEG)
                xf, pf = Test.@test_logs (:warn, r"InPlace HamiltonianVectorField") hflow(
                    0.0, SA[1.0, 0.0], SA[0.0, 1.0], π/2
                )
                Test.@test xf ≈ [0.0, 1.0] atol=ATOL
                Test.@test pf ≈ [-1.0, 0.0] atol=ATOL
            end

            Test.@testset "IP HVF + MVector u0 (no warning)" begin
                hflow = Flows.build_flow(HSYS_IP, INTEG)
                xf, pf = hflow(0.0, MVector{2}(1.0, 0.0), MVector{2}(0.0, 1.0), π/2)
                Test.@test xf ≈ [0.0, 1.0] atol=ATOL
                Test.@test pf ≈ [-1.0, 0.0] atol=ATOL
            end
        end
    end
end

end # module

function test_flow_callables_sciml_hamiltonian_vector_field()
    return TestFlowCallablesSciMLHamiltonianVectorField.test_flow_callables_sciml_hamiltonian_vector_field()
end
