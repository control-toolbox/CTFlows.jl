"""
Family-B GPU **execution** tests: run CTFlows single-flows on a CUDA device and assert values
against analytic references, under `CUDA.allowscalar(false)` (so every pass is genuinely
scalar-index-free). Mirrors the green surface pinned by `probe/gpu/probe_gpu.jl` (design report
§6bis.1, H200 runs 3–6) and exercises the phase-3 augmented / `_safe_only` fixes on-device.

The whole suite self-gates on `is_cuda_on()`: on a machine without a functional device (dev
laptops, CPU CI runners) it skips cleanly. The real run is the `test-gpu-kkt` job on the `kkt`
NVIDIA runner (PR label `run ci gpu`).

GPU-friendly test integrands use `sum`/`dot`/broadcasts, never scalar indexing (`v[i]`, `x[i]`)
— a device scalar read is blocked by `allowscalar(false)` (probe run 4/5).

Out of scope here: `Flow(ocp, …)` on device (phase 4c — OCP host-buffers + CTModels `dynamics!`
gate) and the ensemble path (phase 4b).
"""

module TestGPUFlows

using Test: Test
import CUDA: CUDA
import CTBase.Data: Data
import CTFlows.Flows: Flows
import ADTypes: ADTypes
import SciMLBase: SciMLBase
import Zygote: Zygote  # loads the Zygote backend so the AutoZygote GPU AD default can differentiate

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

is_cuda_on() = CUDA.functional()

# Move a host array onto the device. Only ever called inside an `is_cuda_on()` guard.
_dev(x) = CUDA.CuArray(x)

# Analytic references (tf = 1).
const _E1 = exp(-1.0)                    # ẋ = -x  ⇒  x(1) = x0·e⁻¹
const _C1 = cos(1.0)
const _S1 = sin(1.0)
# Harmonic oscillator ẋ = p, ṗ = -x with x0 = [1,0], p0 = [0,1]:
#   x(1) = [cos1,  sin1],  p(1) = [-sin1, cos1]
const _OSC_X = [_C1, _S1]
const _OSC_P = [-_S1, _C1]

function test_gpu_flows()
    Test.@testset "GPU flows (Family-B, device execution)" verbose=VERBOSE showtiming=SHOWTIMING begin
        if !is_cuda_on()
            @info "CUDA not functional — GPU flow tests skipped (run on the kkt runner)"
            return nothing
        end

        CUDA.allowscalar(false)  # every ✓ below is genuinely scalar-index-free

        # ================================================================
        # AD-FREE flows (GPU-ready first: no AD gate)
        # ================================================================

        Test.@testset "Flow(VectorField) point + trajectory" begin
            f = Flows.Flow(Data.VectorField(x -> -x))          # ẋ = -x
            x0 = _dev([1.0, 2.0])
            xf = f(0.0, x0, 1.0)
            Test.@test xf isa CUDA.CuArray                     # array type preserved
            Test.@test Array(xf) ≈ [1.0, 2.0] .* _E1 atol = 1e-6
            # trajectory construction stays device-clean under allowscalar(false)
            traj = f((0.0, 1.0), x0)
            Test.@test traj !== nothing
        end

        Test.@testset "Flow(HamiltonianVectorField) point vs analytic" begin
            f = Flows.Flow(Data.HamiltonianVectorField((x, p) -> (p, -x)))   # oscillator
            xf, pf = f(0.0, _dev([1.0, 0.0]), _dev([0.0, 1.0]), 1.0)
            Test.@test xf isa CUDA.CuArray
            Test.@test Array(xf) ≈ _OSC_X atol = 1e-6
            Test.@test Array(pf) ≈ _OSC_P atol = 1e-6
        end

        Test.@testset "Flow(ODEProblem) device u0, remake point-call" begin
            prob = SciMLBase.ODEProblem(
                (du, u, p, t) -> (du .= .-u), _dev([1.0, 2.0]), (0.0, 1.0)
            )
            f = Flows.Flow(prob)
            xf = f(0.0, _dev([1.0, 2.0]), 1.0)                 # returns the final state directly
            Test.@test xf isa CUDA.CuArray
            Test.@test Array(xf) ≈ [1.0, 2.0] .* _E1 atol = 1e-6
        end

        Test.@testset "Flow(ODEFunction) device u0" begin
            odef = SciMLBase.ODEFunction((du, u, p, t) -> (du .= .-u))
            f = Flows.Flow(odef)
            xf = f(0.0, _dev([1.0, 2.0]), 1.0)
            Test.@test xf isa CUDA.CuArray
            Test.@test Array(xf) ≈ [1.0, 2.0] .* _E1 atol = 1e-6
        end

        # ================================================================
        # AD-dependent flows (GPU AD default = AutoZygote, phase 1b/2)
        # ================================================================

        Test.@testset "Flow(Hamiltonian; method=:gpu) — AutoZygote default" begin
            h = Data.Hamiltonian((x, p) -> (sum(abs2, x) + sum(abs2, p)) / 2)   # oscillator
            f = Flows.Flow(h; method=:gpu)
            xf, pf = f(0.0, _dev([1.0, 0.0]), _dev([0.0, 1.0]), 1.0)
            Test.@test Array(xf) ≈ _OSC_X atol = 1e-6
            Test.@test Array(pf) ≈ _OSC_P atol = 1e-6
        end

        Test.@testset "Flow(Hamiltonian; ad_backend=AutoZygote())" begin
            h = Data.Hamiltonian((x, p) -> (sum(abs2, x) + sum(abs2, p)) / 2)
            f = Flows.Flow(h; ad_backend=ADTypes.AutoZygote())
            xf, pf = f(0.0, _dev([1.0, 0.0]), _dev([0.0, 1.0]), 1.0)
            Test.@test Array(xf) ≈ _OSC_X atol = 1e-6
            Test.@test Array(pf) ≈ _OSC_P atol = 1e-6
        end

        # The DEFAULT backend (AutoForwardDiff) scalar-indexes on a device array: documents the
        # gate that makes `method=:gpu` (AutoZygote) necessary (probe B3-3c, expected failure).
        Test.@testset "Flow(Hamiltonian) default backend fails on device" begin
            h = Data.Hamiltonian((x, p) -> (sum(abs2, x) + sum(abs2, p)) / 2)
            f = Flows.Flow(h)                                  # default = AutoForwardDiff
            Test.@test_throws Exception f(0.0, _dev([1.0, 0.0]), _dev([0.0, 1.0]), 1.0)
        end

        # ================================================================
        # Augmented variable_costate on device (phase-3 B4a + _safe_only fixes)
        #   H = (‖x‖² + ‖p‖²)/2 + sum(v): the ∂H/∂v term does not enter ẋ/ṗ, so (x,p) still
        #   follow the plain oscillator — a clean analytic reference for all three variants.
        # ================================================================

        _h_var() = Data.Hamiltonian(
            (x, p, v) -> (sum(abs2, x) + sum(abs2, p)) / 2 + sum(v); is_variable=true
        )

        Test.@testset "variable_costate — HOST variable (B4a)" begin
            f = Flows.Flow(_h_var(); ad_backend=ADTypes.AutoZygote())
            xf, pf = f(
                0.0,
                _dev([1.0, 0.0]),
                _dev([0.0, 1.0]),
                1.0;
                variable=[0.5],
                variable_costate=true,
            )
            Test.@test Array(xf) ≈ _OSC_X atol = 1e-6
            Test.@test Array(pf) ≈ _OSC_P atol = 1e-6
        end

        Test.@testset "variable_costate — DEVICE variable, length 1 (_safe_only)" begin
            f = Flows.Flow(_h_var(); ad_backend=ADTypes.AutoZygote())
            xf, pf = f(
                0.0,
                _dev([1.0, 0.0]),
                _dev([0.0, 1.0]),
                1.0;
                variable=_dev([0.5]),
                variable_costate=true,
            )
            Test.@test Array(xf) ≈ _OSC_X atol = 1e-6
            Test.@test Array(pf) ≈ _OSC_P atol = 1e-6
        end

        Test.@testset "variable_costate — DEVICE variable, length 2" begin
            f = Flows.Flow(_h_var(); ad_backend=ADTypes.AutoZygote())
            xf, pf = f(
                0.0,
                _dev([1.0, 0.0]),
                _dev([0.0, 1.0]),
                1.0;
                variable=_dev([0.5, 0.5]),
                variable_costate=true,
            )
            Test.@test Array(xf) ≈ _OSC_X atol = 1e-6
            Test.@test Array(pf) ≈ _OSC_P atol = 1e-6
        end

        # ================================================================
        # Float32 end-to-end (GPUs prefer Float32; nothing promotes to Float64)
        # ================================================================

        Test.@testset "Float32 end-to-end, eltype preserved" begin
            f = Flows.Flow(Data.VectorField(x -> -x))
            xf = f(0.0f0, _dev(Float32[1, 2]), 1.0f0)
            Test.@test eltype(xf) == Float32
            Test.@test Array(xf) ≈ Float32[1, 2] .* Float32(_E1) atol = 1.0f-5
        end

        # ================================================================
        # Multi-phase concatenation on device — probe-unverified; enable after the first
        # green kkt run confirms the concatenation path is scalar-index-free on device.
        # ================================================================

        Test.@testset "multi-phase on device (pending kkt confirmation)" begin
            Test.@test_skip false
        end
    end
    return nothing
end

end # module

# CRITICAL: redefine in the outer scope so the runner can call it
test_gpu_flows() = TestGPUFlows.test_gpu_flows()
