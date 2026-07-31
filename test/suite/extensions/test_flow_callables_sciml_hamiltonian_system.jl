module TestFlowCallablesSciMLHamiltonianSystem

using Test: Test
using CTBase: Exceptions
using CTBase: Data
using CTFlows: Systems
using CTFlows: Flows
using CTFlows: Integrators
using CTBase: Differentiation
using CTFlows: Trajectories

using SciMLBase: SciMLBase
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, Tsit5
using StaticArrays: SA, SVector, MVector
using ForwardDiff: ForwardDiff

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Fake AD backend for testing (no actual AD, just harmonic oscillator)
# ==============================================================================

struct FakeHarmonicADBackend <: Differentiation.AbstractADBackend end

function Differentiation.hamiltonian_gradient(
    backend::FakeHarmonicADBackend, h::Data.AbstractHamiltonian, t, x, p, v
)
    if h === H_SCALAR_ONLY
        return (x*x, -1/p)
    else
        return (x, p)
    end
end

function Differentiation.variable_gradient(
    backend::FakeHarmonicADBackend, h::Data.AbstractHamiltonian, t, x, p, v
)
    return v === nothing ? 0.0 : v
end

# ==============================================================================
# Reference systems for numerical testing
# ==============================================================================

# Harmonic oscillator: H = 0.5*(sum(x²) + sum(p²)) → ẋ = p, ṗ = -x
const H_HARMONIC = Data.Hamiltonian(
    (x, p) -> 0.5*(sum(abs2, x) + sum(abs2, p)); is_autonomous=true, is_variable=false
)
const BACKEND = FakeHarmonicADBackend()
const HSYS = Systems.HamiltonianSystem(H_HARMONIC, BACKEND)
const INTEG = Integrators.SciML()

# Scalar-only Hamiltonian: H = x*x + p*p (requires scalar x, p)
# This will fail if x or p are treated as vectors
const H_SCALAR_ONLY = Data.Hamiltonian(
    (x, p) -> x*x + p*p; is_autonomous=true, is_variable=false
)
const HSYS_SCALAR = Systems.HamiltonianSystem(H_SCALAR_ONLY, BACKEND)
const ATOL = 1e-5

# ==============================================================================
# Test function
# ==============================================================================

function test_flow_callables_sciml_hamiltonian_system()
    Test.@testset "Flow Callables SciML HamiltonianSystem Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # INTEGRATION TESTS - HamiltonianSystem → HamiltonianFlow HamiltonianEndPointConfig
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

            Test.@testset "scalar complex x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                xf, pf = hflow(0.0, 1.0+2.0im, 0.0+0.0im, π/2)
                Test.@test xf isa Complex
                Test.@test pf isa Complex
                Test.@test xf ≈ 0.0+0.0im atol=ATOL
                Test.@test pf ≈ -(1.0+2.0im) atol=ATOL
            end

            Test.@testset "complex vector x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
                x0 = [1.0+2.0im, 0.0+0.0im]
                p0 = [0.0+0.0im, 1.0+1.0im]
                xf, pf = hflow(0.0, x0, p0, π/2)
                Test.@test xf isa AbstractVector
                Test.@test pf isa AbstractVector
                Test.@test xf ≈ p0 atol=ATOL
                Test.@test pf ≈ -x0 atol=ATOL
            end

            Test.@testset "complex SVector x0, p0" begin
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
                Test.@test Xf ≈ P0 atol=ATOL
                Test.@test Pf ≈ -X0 atol=ATOL
            end

            Test.@testset "complex matrix x0, p0" begin
                hflow = Flows.build_flow(HSYS, INTEG)
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
        # INTEGRATION TESTS - HamiltonianSystem → HamiltonianFlow HamiltonianTrajectoryConfig
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
        end

        # ====================================================================
        # SCALAR-ONLY TESTS - verify scalar dispatch (x*x, not sum(x²))
        # ====================================================================

        Test.@testset "Scalar-only Hamiltonian (x³/3 - log(p))" begin
            Test.@testset "scalar x0, p0" begin
                hflow = Flows.build_flow(HSYS_SCALAR, INTEG)
                # H = x³/3 - log(p) → ∂H/∂x = x², ∂H/∂p = -1/p
                # Equations: ẋ = 1/p, ṗ = -x²
                # This will fail if x or p are treated as vectors (can't do x*x or 1/p on vectors)
                xf, pf = hflow(0.0, 0.5, 1.0, 0.1)
                # Just verify it integrates without error and returns scalars
                Test.@test xf isa Real
                Test.@test pf isa Real
                Test.@test pf > 0  # p should stay positive
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - build_system pipeline
        # ====================================================================

        Test.@testset "build_system pipeline" begin
            Test.@testset "via Systems.build_system" begin
                sys = Systems.build_system(H_HARMONIC, BACKEND)
                flow = Flows.build_flow(sys, INTEG)
                xf, pf = flow(0.0, [1.0, 0.0], [0.0, 1.0], π/2)
                Test.@test xf ≈ [0.0, 1.0] atol=ATOL
                Test.@test pf ≈ [-1.0, 0.0] atol=ATOL
            end
        end
    end
end

end # module

function test_flow_callables_sciml_hamiltonian_system()
    return TestFlowCallablesSciMLHamiltonianSystem.test_flow_callables_sciml_hamiltonian_system()
end
