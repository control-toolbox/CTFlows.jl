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

Phase 4c adds the **AD-free** OCP surface: `Flow(ocp)`'s state flow (no costate) and
`Flow(ocp, OpenLoop/ClosedLoop)`. The AD-dependent OCP surface (`Flow(ocp)` Hamiltonian,
`Flow(ocp, DynClosedLoop)`) is **deferred**: those right-hand sides fill a buffer through
CTModels' in-place `dynamics!`, and Zygote — the `method=:gpu` AD default — cannot
differentiate array mutation. That gate fails on CPU too, so it is an AD-architecture issue,
not a GPU one; the negative row below documents it.

Out of scope here: the ensemble path (phase 4b, `test_gpu_ensemble.jl`).
"""

module TestGPUFlows

using Test: Test
import CUDA: CUDA
import CTBase.Data: Data
import CTFlows.Flows: Flows
import CTFlows.Trajectories: Trajectories
import CTModels: CTModels
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

# =============================================================================
# OCP fixtures (module top-level, per the repo convention)
#
# GPU-friendly dynamics: the RHS is written as a BROADCAST (`r .= .-x`), never with
# component-wise scalar writes (`r[1] = x[2]`). CTModels itself is device-clean — it only
# ever hands the user closure a contiguous `@view` of the buffer — so the whole GPU-safety
# burden sits in the user's `dynamics!` body. The canonical docs idiom (`r[1] = …`) would
# scalar-index a device buffer and fail here; this is the contract phase 5 documents.
# =============================================================================

# control-free, autonomous, fixed, 2-D: ẋ = -x ⇒ x(1) = x0·e⁻¹
#
# The MAYER term must be device-safe too, not just the dynamics: a trajectory call evaluates
# it as `may(x(t0), x(tf), v)` (`ocp_readouts.jl:48`) with the flow's own — here device —
# endpoints. The natural `xf[1]` scalar-indexes a `CuArray` and is rejected under
# `allowscalar(false)`; `sum` is a reduction and stays on device.
# ⇒ objective = sum(x(1)) = (1+2)·e⁻¹.
function _build_gpu_cf_ocp()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r .= .-x; nothing))
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> sum(xf))
    return CTModels.Building.build(pre)
end

# with-control, autonomous, fixed, 2-D: ẋ = -x + u. The control dimension is 1, so CTFlows
# coerces `u` to a SCALAR before calling the dynamics (1-D = scalar), which broadcasts
# cleanly against a device state. With the ClosedLoop law u ≡ 0 the reference is x0·e⁻¹.
function _build_gpu_ctrl_ocp()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r .= .-x .+ u; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.0)
    return CTModels.Building.build(pre)
end

const OCP_GPU_CF = _build_gpu_cf_ocp()
const OCP_GPU_CTRL = _build_gpu_ctrl_ocp()

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
            # An ODEFunction carries a parameter slot `p`, so its flow is NonFixed: `p` is
            # supplied via `variable=` at call time (here the decay rate, a host scalar that
            # broadcasts cleanly against the device state).
            odef = SciMLBase.ODEFunction((du, u, p, t) -> (du .= .-p .* u))
            f = Flows.Flow(odef)
            xf = f(0.0, _dev([1.0, 2.0]), 1.0; variable=1.0)   # ẋ = -1·u
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
        # Multi-phase concatenation on device (state flow, point config).
        #   Confirmed scalar-index-free: `_extract_final_state` reads `final_state`
        #   (no scalar getindex) and jumps are applied as broadcasts `v .+ j`, so a
        #   state-flow `*` concatenation runs under `allowscalar(false)`.
        # ================================================================

        Test.@testset "multi-phase concat — no jump == single flow" begin
            f = Flows.Flow(Data.VectorField(x -> -x))              # ẋ = -x
            mpf = f * (0.5, f)                                     # split at t = 0.5, no jump
            xf = mpf(0.0, _dev([1.0, 2.0]), 1.0)
            Test.@test xf isa CUDA.CuArray
            # splitting a flow with no jump leaves the endpoint unchanged: x(1) = x0·e⁻¹
            Test.@test Array(xf) ≈ [1.0, 2.0] .* _E1 atol = 1e-6
        end

        Test.@testset "multi-phase concat — scalar additive jump" begin
            f = Flows.Flow(Data.VectorField(x -> -x))              # ẋ = -x
            mpf = f * (0.5, 0.1, f)                                # x ← x .+ 0.1 at t = 0.5
            xf = mpf(0.0, _dev([1.0, 2.0]), 1.0)
            Test.@test xf isa CUDA.CuArray
            # phase 1 to 0.5, +0.1, phase 2 to 1.0
            x_mid = [1.0, 2.0] .* exp(-0.5) .+ 0.1
            x_ref = x_mid .* exp(-0.5)
            Test.@test Array(xf) ≈ x_ref atol = 1e-6
        end

        # ================================================================
        # OCP flows on device (phase 4c) — the AD-FREE surface only.
        #   Exercises the `_buffer_like` migration: the in-place `dynamics!` buffer is
        #   now allocated from the state, so a device state yields a device buffer.
        # ================================================================

        Test.@testset "Flow(ocp) state flow (no costate) on device" begin
            f = Flows.Flow(OCP_GPU_CF)
            xf = f(0.0, _dev([1.0, 2.0]), 1.0)          # basic call: no p0
            Test.@test xf isa CUDA.CuArray               # buffer stayed on device
            Test.@test Array(xf) ≈ [1.0, 2.0] .* _E1 atol = 1e-6
        end

        Test.@testset "Flow(ocp) state trajectory on device" begin
            # The tspan call returns a StateFlowTrajectory (NOT a CTModels.Solution), so it
            # does not cross the host-pinned `build_solution` boundary. It DOES evaluate the
            # Mayer objective on the device endpoints, so this row also covers the
            # `_flow_objective` Mayer path (mayer = sum(xf) ⇒ (1+2)·e⁻¹).
            f = Flows.Flow(OCP_GPU_CF)
            traj = f((0.0, 1.0), _dev([1.0, 2.0]))
            Test.@test traj !== nothing
            Test.@test Trajectories.objective(traj) ≈ 3.0 * _E1 atol = 1e-6
        end

        Test.@testset "Flow(ocp, ClosedLoop) on device" begin
            # ClosedLoop ⇒ AD-free controlled state flow through `_ocp_controlled_vf`.
            # u ≡ 0, so ẋ = -x and the reference is the same exponential decay.
            f = Flows.Flow(OCP_GPU_CTRL, Data.ClosedLoop(x -> 0.0))
            xf = f(0.0, _dev([1.0, 2.0]), 1.0)
            Test.@test xf isa CUDA.CuArray
            Test.@test Array(xf) ≈ [1.0, 2.0] .* _E1 atol = 1e-6
        end

        # The AD-dependent OCP surface is DEFERRED, and the reason is not GPU-specific:
        # `_ocp_H` fills its buffer through CTModels' in-place `dynamics!`, and Zygote (the
        # `method=:gpu` AD default, phase 1b) cannot differentiate array mutation — it throws
        # "Mutating arrays is not supported". This reproduces on CPU; the row records the gate
        # so a future fix (Enzyme, Zygote.Buffer, or an out-of-place dynamics contract) flips
        # it deliberately rather than silently.
        Test.@testset "Flow(ocp) Hamiltonian on device — deferred (AD/mutation gate)" begin
            f = Flows.Flow(OCP_GPU_CF; method=:gpu)
            Test.@test_throws Exception f(
                0.0, _dev([1.0, 2.0]), _dev([0.0, 0.0]), 1.0
            )
        end
    end
    return nothing
end

end # module

# CRITICAL: redefine in the outer scope so the runner can call it
test_gpu_flows() = TestGPUFlows.test_gpu_flows()
