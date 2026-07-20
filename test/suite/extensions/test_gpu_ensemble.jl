"""
Family-C GPU **ensemble** tooling PoC: solve N independent small ODEs in parallel on a CUDA
device with `DiffEqGPU`, and pin — on real hardware — which ensemble algorithm works and what
shape of RHS each one needs. This is a *tooling spike*, NOT a benchmark and NOT yet wired to
CTFlows `Flow`s (that batched user API is the real Family-C follow-up, design report §8).

Mirrors `probe/gpu/probe_gpu.jl` Block 6 (H200 runs 8–11, both algorithms green):
  * `EnsembleGPUArray`  — permissive, in-place RHS `f!(du,u,p,t)`, host arrays moved by the algo;
  * `EnsembleGPUKernel` — kernel-compiled, needs an out-of-place `SVector` RHS, no host closures.

Each trajectory `i` integrates ẋ = -x from a perturbed x0, so x(1) = x0·e⁻¹ — a clean analytic
reference. The in-place path is additionally cross-checked against a CPU `EnsembleThreads()` solve.

Self-gates on `is_cuda_on()`: on a machine without a functional device it skips cleanly; the real
run is the `test-gpu-kkt` job on the `kkt` NVIDIA runner (PR label `run ci gpu`). Everything runs
under `CUDA.allowscalar(false)`.

Accessor discipline (probe runs 9–10): read a trajectory's final state via the raw `.u` field —
`sol.u[i].u[end]` — never `sol[i][end]`, which is Cartesian tensor indexing into the
(component × time) shape and silently returns a scalar, not the final state vector.
"""

module TestGPUEnsemble

using Test: Test
import CUDA: CUDA
import SciMLBase: SciMLBase
import DiffEqGPU: DiffEqGPU
import OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5   # Tsit5 for the CPU/EnsembleGPUArray paths
import StaticArrays: StaticArrays                 # SVector for the EnsembleGPUKernel path

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

is_cuda_on() = CUDA.functional()

# N independent trajectories of ẋ = -x, trajectory i starting at [i, 2i] ⇒ x(1) = [i, 2i]·e⁻¹.
const _N_ENS = 8
_u0(i) = [Float64(i), 2.0 * i]
_expected(i) = _u0(i) .* exp(-1.0)

function test_gpu_ensemble()
    Test.@testset "GPU ensemble (Family-C, DiffEqGPU tooling PoC)" verbose = VERBOSE showtiming =
        SHOWTIMING begin
        if !is_cuda_on()
            @info "CUDA not functional — GPU ensemble tests skipped (run on the kkt runner)"
            return nothing
        end

        CUDA.allowscalar(false)  # every ✓ below is genuinely scalar-index-free

        # ================================================================
        # EnsembleGPUArray — in-place RHS, host u0 moved to device by the algorithm.
        #   Most permissive path; closest to how a CTFlows in-place RHS functor would plug in.
        # ================================================================
        Test.@testset "EnsembleGPUArray (in-place, N=$_N_ENS)" begin
            f!(du, u, p, t) = (du .= .-u)
            prob = SciMLBase.ODEProblem(f!, _u0(1), (0.0, 1.0))
            eprob = SciMLBase.EnsembleProblem(
                prob; prob_func=(p, ctx) -> SciMLBase.remake(p; u0=_u0(ctx.sim_id))
            )
            sol = SciMLBase.solve(
                eprob,
                OrdinaryDiffEqTsit5.Tsit5(),
                DiffEqGPU.EnsembleGPUArray(CUDA.CUDABackend());
                trajectories=_N_ENS,
                save_everystep=false,
            )
            # each trajectory matches the analytic endpoint
            for i in 1:_N_ENS
                Test.@test Array(sol.u[i].u[end]) ≈ _expected(i) atol = 1e-5
            end

            # cross-check against the CPU EnsembleThreads() reference (same problem, host solve)
            csol = SciMLBase.solve(
                eprob,
                OrdinaryDiffEqTsit5.Tsit5(),
                SciMLBase.EnsembleThreads();
                trajectories=_N_ENS,
                save_everystep=false,
            )
            for i in 1:_N_ENS
                Test.@test Array(sol.u[i].u[end]) ≈ csol.u[i].u[end] atol = 1e-6
            end
        end

        # ================================================================
        # EnsembleGPUKernel — kernel-compiled path: out-of-place SVector RHS, no host-state
        #   closures. Pins what a GPU-kernel-ready CTFlows RHS would have to satisfy.
        # ================================================================
        Test.@testset "EnsembleGPUKernel (out-of-place SVector, N=$_N_ENS)" begin
            f_oop(u, p, t) = -u
            u0 = StaticArrays.SVector{2,Float64}(1.0, 2.0)
            prob = SciMLBase.ODEProblem(f_oop, u0, (0.0, 1.0))
            eprob = SciMLBase.EnsembleProblem(
                prob;
                prob_func=(p, ctx) -> SciMLBase.remake(
                    p;
                    u0=StaticArrays.SVector{2,Float64}(
                        Float64(ctx.sim_id), 2.0 * ctx.sim_id
                    ),
                ),
            )
            sol = SciMLBase.solve(
                eprob,
                DiffEqGPU.GPUTsit5(),
                DiffEqGPU.EnsembleGPUKernel(CUDA.CUDABackend());
                trajectories=_N_ENS,
                save_everystep=false,
            )
            for i in 1:_N_ENS
                Test.@test Array(sol.u[i].u[end]) ≈ _expected(i) atol = 1e-5
            end
        end
    end
    return nothing
end

end # module

# CRITICAL: redefine in the outer scope so the runner can call it
test_gpu_ensemble() = TestGPUEnsemble.test_gpu_ensemble()
