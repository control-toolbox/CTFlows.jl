module TestVectorFieldTrajectoryShapes

using Test: Test
import CTFlows.Systems
import CTFlows.Flows
import CTFlows.Integrators
import CTFlows.Trajectories
import CTBase.Data

import SciMLBase
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, Tsit5
using StaticArrays: SA, SVector

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# issue #357 — target (fixed) shape behaviour for state-flow constructors.
#
# `Flow(VectorField)` and `Flow(::ODEFunction)` (SciMLFunctionSystem) both go through
# CTFlows' own Systems/Trajectories dispatch, so both must become 1-D = scalar END TO
# END (point AND trajectory calls), mirroring what `Flow(HamiltonianVectorField)`
# already does — see test_hamiltonian_vf_trajectory_shapes.jl.
#
# `Flow(::ODEProblem)` (SciMLProblemFlow) genuinely bypasses that dispatch (direct
# remake+solve), so it must stay shape-preserving forever — its testset below uses
# plain @test, not @test_broken, and must never need to change.
#
# Written test-first (Phase C): the 7 assertions that were false before the fix were
# marked `Test.@test_broken` and confirmed red; Phase D/E's fix then made every one of
# them genuinely pass, which `Test.jl` itself caught as "Unexpected Pass" (a `@test_broken`
# that starts passing is an error, not a silent skip) — forcing each to be flipped to
# plain `Test.@test` here, done, with none left un-flipped by construction.
#
# Value checks use `first(x)` rather than a bare `x ≈ ...` comparison: `first` reads the
# same scalar whether `x` is `1.0` or `[1.0]`, so correctness assertions stay stable
# across the whole red → green transition and only the `isa`/`length` shape assertions
# need to flip.
# ==============================================================================

const VF_DECAY = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
const ATOL = 1e-5
const E = exp(-1.0)

# SciMLFunctionSystem is always NonAutonomous/NonFixed (SciML's uniform (u,p,t)
# signature), so every call passes variable=1.0 explicitly; dynamics ẋ = -p·x with
# p=1.0 gives the same x(1) = x0·e⁻¹ as VF_DECAY.
const F_SCF = SciMLBase.ODEFunction{false}((u, p, t) -> -p .* u)

# ==============================================================================
# Test function
# ==============================================================================

function test_vector_field_trajectory_shapes()
    Test.@testset "VectorFieldTrajectory Shape Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # Flow(VectorField) — VectorFieldSystem
        # ====================================================================

        Test.@testset "Flow(VectorField): sol(t) shape" begin
            flow = Flows.Flow(VF_DECAY; reltol=1e-10)

            Test.@testset "scalar x0 → scalar output" begin
                xf = flow(0.0, 1.0, 1.0)
                Test.@test xf isa Real
                Test.@test first(xf) ≈ E atol=ATOL

                sol = flow((0.0, 1.0), 1.0)
                Test.@test sol isa Trajectories.VectorFieldTrajectory
                x = Trajectories.state(sol)(1.0)
                Test.@test x isa Real
                Test.@test first(x) ≈ E atol=ATOL
            end

            Test.@testset "length-1 Vector x0 → scalar output (coerced, like Hamiltonian family)" begin
                xf = flow(0.0, [1.0], 1.0)
                Test.@test xf isa Real
                Test.@test first(xf) ≈ E atol=ATOL

                sol = flow((0.0, 1.0), [1.0])
                x = Trajectories.state(sol)(1.0)
                Test.@test x isa Real
                Test.@test first(x) ≈ E atol=ATOL
            end

            Test.@testset "length-1 SVector x0 → scalar output (coerced)" begin
                xf = flow(0.0, SA[1.0], 1.0)
                Test.@test xf isa Real
                Test.@test first(xf) ≈ E atol=ATOL
            end

            Test.@testset "vector x0 → vector output (unaffected by the fix)" begin
                xf = flow(0.0, [1.0, 2.0], 1.0)
                Test.@test xf isa AbstractVector && length(xf) == 2
                Test.@test xf ≈ [1.0, 2.0] .* E atol=ATOL

                sol = flow((0.0, 1.0), [1.0, 2.0])
                x = Trajectories.state(sol)(1.0)
                Test.@test x isa AbstractVector && length(x) == 2
            end

            Test.@testset "1×1 Matrix x0 → matrix output (matrices never collapse)" begin
                X0 = fill(1.0, 1, 1)
                Xf = flow(0.0, X0, 1.0)
                Test.@test Xf isa AbstractMatrix
                Test.@test size(Xf) == (1, 1)

                sol = flow((0.0, 1.0), X0)
                X = Trajectories.state(sol)(1.0)
                Test.@test X isa AbstractMatrix
                Test.@test size(X) == (1, 1)
            end

            Test.@testset "complex scalar x0 → complex scalar output" begin
                xf = flow(0.0, 1.0 + 2.0im, 1.0)
                Test.@test xf isa Complex
                Test.@test first(xf) ≈ (1.0 + 2.0im) * E atol=ATOL

                sol = flow((0.0, 1.0), 1.0 + 2.0im)
                x = Trajectories.state(sol)(1.0)
                Test.@test x isa Complex
                Test.@test first(x) ≈ (1.0 + 2.0im) * E atol=ATOL
            end
        end

        # ====================================================================
        # Flow(::SciMLBase.ODEFunction) — SciMLFunctionSystem
        #
        # Shares the exact same StateDynamics/build_trajectory dispatch and config
        # types as VectorFieldSystem (confirmed by the probe: identical shape profile),
        # so per issue #357's resolved design decision it is IN SCOPE for the same fix.
        # ====================================================================

        Test.@testset "Flow(::ODEFunction): sol(t) shape" begin
            flow = Flows.Flow(F_SCF; reltol=1e-10)

            Test.@testset "scalar x0 → scalar output" begin
                xf = flow(0.0, 1.0, 1.0; variable=1.0)
                Test.@test xf isa Real
                Test.@test first(xf) ≈ E atol=ATOL

                sol = flow((0.0, 1.0), 1.0; variable=1.0)
                x = Trajectories.state(sol)(1.0)
                Test.@test x isa Real
                Test.@test first(x) ≈ E atol=ATOL
            end

            Test.@testset "length-1 Vector x0 → scalar output (coerced)" begin
                xf = flow(0.0, [1.0], 1.0; variable=1.0)
                Test.@test xf isa Real
                Test.@test first(xf) ≈ E atol=ATOL
            end

            Test.@testset "vector x0 → vector output (unaffected by the fix)" begin
                xf = flow(0.0, [1.0, 2.0], 1.0; variable=1.0)
                Test.@test xf isa AbstractVector && length(xf) == 2
            end
        end

        # ====================================================================
        # Flow(::SciMLBase.ODEProblem) — SciMLProblemFlow
        #
        # Genuine SciML bypass: no CTFlows Systems/Trajectories dispatch at all
        # (direct remake + solve). MUST stay shape-preserving forever — plain @test
        # throughout, never @test_broken; this testset must never need to change.
        # ====================================================================

        Test.@testset "Flow(::ODEProblem): shape-preserving passthrough (must never change)" begin
            prob = SciMLBase.ODEProblem(F_SCF, [1.0], (0.0, 1.0), 1.0)
            flow = Flows.Flow(prob; reltol=1e-10)

            Test.@testset "scalar x0 stays scalar" begin
                xf = flow(0.0, 1.0, 1.0; variable=1.0)
                Test.@test xf isa Real
                Test.@test first(xf) ≈ E atol=ATOL

                result = flow((0.0, 1.0), 1.0; variable=1.0)
                x = Integrators.evaluate_at(result, 1.0)
                Test.@test x isa Real
                Test.@test first(x) ≈ E atol=ATOL
            end

            Test.@testset "length-1 vector x0 stays length-1 vector" begin
                xf = flow(0.0, [1.0], 1.0; variable=1.0)
                Test.@test xf isa AbstractVector && length(xf) == 1
                Test.@test first(xf) ≈ E atol=ATOL

                result = flow((0.0, 1.0), [1.0]; variable=1.0)
                x = Integrators.evaluate_at(result, 1.0)
                Test.@test x isa AbstractVector && length(x) == 1
            end
        end
    end
end

end # module

function test_vector_field_trajectory_shapes()
    return TestVectorFieldTrajectoryShapes.test_vector_field_trajectory_shapes()
end
