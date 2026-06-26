module TestHamiltonianVFTrajectoryShapes

import Test
import CTFlows.Systems
import CTFlows.Flows
import CTFlows.Integrators
import CTFlows.Trajectories
import CTFlows.Common
import CTBase.Data
import CTBase.Traits

using SciMLBase: SciMLBase
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, Tsit5
using StaticArrays: SA, SVector, MVector, SMatrix

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Reference systems for numerical testing
# ==============================================================================

# Harmonic oscillator: x' = p, p' = -x
const HVF_HARMONIC = Data.HamiltonianVectorField((x, p) -> (p, -x); is_autonomous=true, is_variable=false)
const HSYS = Systems.HamiltonianVectorFieldSystem(HVF_HARMONIC)
const INTEG = Integrators.SciML()
const ATOL = 1e-5

# ==============================================================================
# Test function
# ==============================================================================

function test_hamiltonian_vf_trajectory_shapes()
    Test.@testset "HamiltonianVectorFieldTrajectory Shape Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # SHAPE TESTS - sol(t) for HamiltonianVectorFieldTrajectory
        # ====================================================================

        Test.@testset "sol(t) shape preservation" begin
            Test.@testset "scalar x0, p0 → scalar output" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                sol = hflow((0.0, π/2), 1.0, 0.0)
                Test.@test sol isa Trajectories.HamiltonianVectorFieldTrajectory
                
                # Test sol(t) at t=π/2
                x, p = sol(π/2)
                Test.@test x isa Real
                Test.@test p isa Real
                Test.@test x ≈ 0.0  atol=ATOL
                Test.@test p ≈ -1.0  atol=ATOL
            end

            Test.@testset "vector x0, p0 → vector output" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                sol = hflow((0.0, π/2), [1.0, 0.0], [0.0, 1.0])
                Test.@test sol isa Trajectories.HamiltonianVectorFieldTrajectory
                
                # Test sol(t) at t=π/2
                x, p = sol(π/2)
                Test.@test x isa AbstractVector && length(x) == 2
                Test.@test p isa AbstractVector && length(p) == 2
                Test.@test x ≈ [0.0, 1.0]  atol=ATOL
                Test.@test p ≈ [-1.0, 0.0]  atol=ATOL
            end

            Test.@testset "SVector x0, p0 → vector output" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                sol = hflow((0.0, π/2), SA[1.0, 0.0], SA[0.0, 1.0])
                Test.@test sol isa Trajectories.HamiltonianVectorFieldTrajectory
                
                # Test sol(t) at t=π/2
                x, p = sol(π/2)
                Test.@test x isa AbstractVector
                Test.@test p isa AbstractVector
                Test.@test x ≈ [0.0, 1.0]  atol=ATOL
                Test.@test p ≈ [-1.0, 0.0]  atol=ATOL
            end

            Test.@testset "matrix x0, p0 → matrix output" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                X0 = [1.0 2.0; 3.0 4.0]
                P0 = [0.0 0.0; 1.0 1.0]
                sol = hflow((0.0, π/2), X0, P0)
                Test.@test sol isa Trajectories.HamiltonianVectorFieldTrajectory
                
                # Test sol(t) at t=π/2
                X, P = sol(π/2)
                Test.@test X isa AbstractMatrix
                Test.@test P isa AbstractMatrix
                Test.@test size(X) == (2, 2)
                Test.@test size(P) == (2, 2)
                Test.@test X ≈ P0  atol=ATOL
                Test.@test P ≈ -X0  atol=ATOL
            end

            Test.@testset "SMatrix x0, p0 → matrix output" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                X0 = SMatrix{2,2}(1.0, 3.0, 2.0, 4.0)
                P0 = SMatrix{2,2}(0.0, 1.0, 0.0, 1.0)
                sol = hflow((0.0, π/2), X0, P0)
                Test.@test sol isa Trajectories.HamiltonianVectorFieldTrajectory
                
                # Test sol(t) at t=π/2
                X, P = sol(π/2)
                Test.@test X isa AbstractMatrix
                Test.@test P isa AbstractMatrix
                Test.@test X ≈ P0  atol=ATOL
                Test.@test P ≈ -X0  atol=ATOL
            end

            Test.@testset "complex scalar x0, p0 → complex scalar output" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                sol = hflow((0.0, π/2), 1.0+2.0im, 0.0+0.0im)
                Test.@test sol isa Trajectories.HamiltonianVectorFieldTrajectory
                
                # Test sol(t) at t=π/2
                x, p = sol(π/2)
                Test.@test x isa Complex
                Test.@test p isa Complex
                Test.@test x ≈ 0.0+0.0im  atol=ATOL
                Test.@test p ≈ -(1.0+2.0im)  atol=ATOL
            end

            Test.@testset "complex vector x0, p0 → complex vector output" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                x0 = [1.0+2.0im, 0.0+0.0im]
                p0 = [0.0+0.0im, 1.0+1.0im]
                sol = hflow((0.0, π/2), x0, p0)
                Test.@test sol isa Trajectories.HamiltonianVectorFieldTrajectory
                
                # Test sol(t) at t=π/2
                x, p = sol(π/2)
                Test.@test x isa AbstractVector
                Test.@test p isa AbstractVector
                Test.@test x ≈ p0  atol=ATOL
                Test.@test p ≈ -x0  atol=ATOL
            end

            Test.@testset "complex matrix x0, p0 → complex matrix output" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                X0 = [1.0+2.0im  5.0+6.0im; 3.0+4.0im  7.0+8.0im]
                P0 = [0.0+0.0im  1.0+1.0im; 2.0+2.0im  3.0+3.0im]
                sol = hflow((0.0, π/2), X0, P0)
                Test.@test sol isa Trajectories.HamiltonianVectorFieldTrajectory
                
                # Test sol(t) at t=π/2
                X, P = sol(π/2)
                Test.@test X isa AbstractMatrix
                Test.@test P isa AbstractMatrix
                Test.@test X ≈ P0  atol=ATOL
                Test.@test P ≈ -X0  atol=ATOL
            end
        end

        # ====================================================================
        # SHAPE TESTS - final time evaluation
        # ====================================================================

        Test.@testset "final time evaluation shape preservation" begin
            Test.@testset "scalar x0, p0 → scalar output" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                sol = hflow((0.0, π/2), 1.0, 0.0)
                
                x, p = sol(π/2)
                Test.@test x isa Real
                Test.@test p isa Real
                Test.@test x ≈ 0.0  atol=ATOL
                Test.@test p ≈ -1.0  atol=ATOL
            end

            Test.@testset "vector x0, p0 → vector output" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                sol = hflow((0.0, π/2), [1.0, 0.0], [0.0, 1.0])
                
                x, p = sol(π/2)
                Test.@test x isa AbstractVector && length(x) == 2
                Test.@test p isa AbstractVector && length(p) == 2
                Test.@test x ≈ [0.0, 1.0]  atol=ATOL
                Test.@test p ≈ [-1.0, 0.0]  atol=ATOL
            end

            Test.@testset "matrix x0, p0 → matrix output" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                X0 = [1.0 2.0; 3.0 4.0]
                P0 = [0.0 0.0; 1.0 1.0]
                sol = hflow((0.0, π/2), X0, P0)
                
                X, P = sol(π/2)
                Test.@test X isa AbstractMatrix
                Test.@test P isa AbstractMatrix
                Test.@test size(X) == (2, 2)
                Test.@test size(P) == (2, 2)
                Test.@test X ≈ P0  atol=ATOL
                Test.@test P ≈ -X0  atol=ATOL
            end
        end

        # ====================================================================
        # SHAPE TESTS - intermediate times
        # ====================================================================

        Test.@testset "intermediate time evaluation" begin
            Test.@testset "scalar x0, p0 at t=π/4" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                sol = hflow((0.0, π/2), 1.0, 0.0)
                
                # At t=π/4: x = cos(π/4) ≈ 0.707, p = -sin(π/4) ≈ -0.707
                x, p = sol(π/4)
                Test.@test x isa Real
                Test.@test p isa Real
                Test.@test x ≈ 0.7071  atol=ATOL
                Test.@test p ≈ -0.7071  atol=ATOL
            end

            Test.@testset "vector x0, p0 at t=π/4" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                sol = hflow((0.0, π/2), [1.0, 0.0], [0.0, 1.0])
                
                x, p = sol(π/4)
                Test.@test x isa AbstractVector && length(x) == 2
                Test.@test p isa AbstractVector && length(p) == 2
                Test.@test x ≈ [0.7071, 0.7071]  atol=ATOL
                Test.@test p ≈ [-0.7071, 0.7071]  atol=ATOL
            end
        end
    end
end

end # module

test_hamiltonian_vf_trajectory_shapes() = TestHamiltonianVFTrajectoryShapes.test_hamiltonian_vf_trajectory_shapes()
