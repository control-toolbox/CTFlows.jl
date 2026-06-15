"""
Mirror of test_flow_callables_sciml_hamiltonian_system.jl using real DifferentiationInterface backend.
"""

module TestFlowCallablesSciMLHamiltonianSystemDI

import Test
import CTBase.Exceptions
import CTFlows.Data: Data
import CTFlows.Common: Common
import CTFlows.Systems: Systems
import CTFlows.Flows: Flows
import CTFlows.Integrators: Integrators
import CTFlows.Differentiation: Differentiation
import CTFlows.Solutions: Solutions

using SciMLBase: SciMLBase
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, Tsit5
using StaticArrays: SA, SVector, MVector
using ForwardDiff: ForwardDiff
using ADTypes: ADTypes
using DifferentiationInterface: DifferentiationInterface as DI

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Reference systems for numerical testing
# ==============================================================================

# Harmonic oscillator: H = 0.5*(sum(x²) + sum(p²)) → ẋ = p, ṗ = -x
const H_HARMONIC = Data.Hamiltonian((x, p) -> 0.5*(sum(abs2, x) + sum(abs2, p));
                                    is_autonomous=true, is_variable=false)

const DI_BACKEND = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
const HSYS       = Systems.HamiltonianSystem(H_HARMONIC, DI_BACKEND)
const INTEG      = Integrators.SciML()
const ATOL       = 1e-5

# ==============================================================================
# Test function
# ==============================================================================

function test_flow_callables_sciml_hamiltonian_system_di()
    Test.@testset "Flow Callables SciML HamiltonianSystem DI Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        Test.@testset "HamiltonianFlow HamiltonianEndPointConfig" begin
            Test.@testset "scalar x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                xf, pf = hflow(0.0, 1.0, 0.0, π/2)
                Test.@test xf isa Real
                Test.@test pf isa Real
                Test.@test xf ≈ 0.0  atol=ATOL
                Test.@test pf ≈ -1.0  atol=ATOL
            end

            Test.@testset "vector x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                xf, pf = hflow(0.0, [1.0, 0.0], [0.0, 1.0], π/2)
                Test.@test xf isa AbstractVector && length(xf) == 2
                Test.@test pf isa AbstractVector && length(pf) == 2
                Test.@test xf ≈ [0.0, 1.0]  atol=ATOL
                Test.@test pf ≈ [-1.0, 0.0]  atol=ATOL
            end

            Test.@testset "SVector x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                xf, pf = hflow(0.0, SA[1.0, 0.0], SA[0.0, 1.0], π/2)
                Test.@test xf isa AbstractVector
                Test.@test pf isa AbstractVector
                Test.@test xf ≈ [0.0, 1.0]  atol=ATOL
                Test.@test pf ≈ [-1.0, 0.0]  atol=ATOL
            end

            Test.@testset "MVector x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                xf, pf = hflow(0.0, MVector{2}(1.0, 0.0), MVector{2}(0.0, 1.0), π/2)
                Test.@test xf isa AbstractVector
                Test.@test pf isa AbstractVector
                Test.@test xf ≈ [0.0, 1.0]  atol=ATOL
                Test.@test pf ≈ [-1.0, 0.0]  atol=ATOL
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
                Test.@test Xf ≈ P0  atol=ATOL
                Test.@test Pf ≈ -X0  atol=ATOL
            end
        end

        Test.@testset "HamiltonianFlow HamiltonianTrajectoryConfig" begin
            Test.@testset "scalar x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                sol = hflow((0.0, π/2), 1.0, 0.0)
                Test.@test sol isa Solutions.HamiltonianVectorFieldSolution
            end

            Test.@testset "vector x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                sol = hflow((0.0, π/2), [1.0, 0.0], [0.0, 1.0])
                Test.@test sol isa Solutions.HamiltonianVectorFieldSolution
            end

            Test.@testset "SVector x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                sol = hflow((0.0, π/2), SA[1.0, 0.0], SA[0.0, 1.0])
                Test.@test sol isa Solutions.HamiltonianVectorFieldSolution
            end
        end

        Test.@testset "build_system pipeline" begin
            Test.@testset "via Systems.build_system" begin
                sys = Systems.build_system(H_HARMONIC, DI_BACKEND)
                flow = Flows.build_flow(sys, INTEG)
                xf, pf = flow(0.0, [1.0, 0.0], [0.0, 1.0], π/2)
                Test.@test xf ≈ [0.0, 1.0]  atol=ATOL
                Test.@test pf ≈ [-1.0, 0.0]  atol=ATOL
            end
        end
    end
end

end # module

test_flow_callables_sciml_hamiltonian_system_di() = TestFlowCallablesSciMLHamiltonianSystemDI.test_flow_callables_sciml_hamiltonian_system_di()
