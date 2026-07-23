#!/usr/bin/env julia
# =============================================================================
# GPU capability probe for CTFlows  —  runs on the kkt (NVIDIA/CUDA) runner
# =============================================================================
#
# Purpose
# -------
# Turn the *hypotheses* of the GPU design report into *measured facts* on real
# hardware, WITHOUT modifying any package. It probes, against the CURRENT
# (unparameterized) CTFlows/CTSolvers/CTBase, which combinations of (array type,
# AD backend, flow source) already work on GPU and which fail — and, for the
# failures, WITH WHICH ERROR.
#
# It is a diagnostic, not a test suite: nothing here asserts pass/fail. Every
# experiment is wrapped in try/catch so a single failure never stops the run, and
# every outcome is printed inline plus collected into a final matrix. Read the
# SUMMARY at the bottom of the CI log, then fold the findings back into the report.
#
# How it is run
# -------------
# A dedicated workflow (.github/workflows/GPUProbe.yml) checks out the repo, adds
# the private ct-registry, and runs:
#     julia --project=probe/gpu probe/gpu/probe_gpu.jl
# The header below activates this folder's own environment and `dev`s the checked
# out CTFlows so the probe measures the PR's source (not the registered version).
# =============================================================================

# ---------------------------------------------------------------------------
# Environment: activate this probe's project and dev the checked-out CTFlows
# (mirrors the .extras/ pattern; Manifest is intentionally not committed)
# ---------------------------------------------------------------------------
using Pkg
Pkg.activate(@__DIR__)
Pkg.develop(; path=joinpath(@__DIR__, "..", ".."))   # the repo root (this CTFlows)
Pkg.instantiate()

using Printf: @printf

using CUDA: CUDA
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5   # activates the CTFlows SciML integrator ext
using SciMLBase: SciMLBase
using ADTypes: ADTypes
using ForwardDiff: ForwardDiff                   # activates DI AutoForwardDiff
using Zygote: Zygote                             # activates DI AutoZygote
using Mooncake: Mooncake                         # activates DI AutoMooncake  (Block 7/8)
using Enzyme: Enzyme                             # activates DI AutoEnzyme    (Block 7/8)
using DiffEqGPU: DiffEqGPU                        # ensemble GPU tooling (Block 6)
using StaticArrays: SVector                       # for the EnsembleGPUKernel path

import CTBase.Data
import CTBase.Differentiation
import CTFlows.Flows
import CTModels: CTModels                        # OCP fixture for Block 8

# ---------------------------------------------------------------------------
# Probe harness: run a labelled experiment, catch everything, record + print
# ---------------------------------------------------------------------------
struct ProbeResult
    block::String
    name::String
    status::Symbol           # :ok | :fail | :xfail | :skip   (:xfail = failed as expected)
    detail::String           # value summary, or exception type + message (truncated)
    fulltrace::String        # full showerror + backtrace, kept only for unexpected :fail
end
ProbeResult(b, n, s, d) = ProbeResult(b, n, s, d, "")
const RESULTS = ProbeResult[]

_truncate(s, n=140) = length(s) > n ? first(s, n) * " …" : s

function _is_scalar_indexing_error(err)
    s = lowercase(sprint(showerror, err))
    return occursin("scalar indexing", s) || occursin("allowscalar", s)
end

# Run the experiment `f`. Prints ✓ / ✗ / ∅ with a one-line detail and records it.
# A returned value is stringified as the success detail; any thrown error is caught,
# classified (scalar-indexing errors flagged explicitly) and recorded. Set
# `expect_fail=true` for experiments that are SUPPOSED to fail today (e.g. the
# AutoForwardDiff-on-GPU cases): a failure is then recorded as :xfail (expected), and an
# unexpected *success* is flagged loudly.
function probe(
    f, block, name; skip_if::Bool=false, skip_reason::String="", expect_fail::Bool=false
)
    if skip_if
        push!(RESULTS, ProbeResult(block, name, :skip, skip_reason))
        @printf("  ∅ %-50s  SKIP  (%s)\n", name, skip_reason)
        return nothing
    end
    try
        val = f()
        detail = _truncate(string(val))
        if expect_fail
            push!(RESULTS, ProbeResult(block, name, :fail, "UNEXPECTED PASS: $detail"))
            @printf("  ⚠ %-50s  UNEXPECTED-PASS  %s\n", name, detail)
        else
            push!(RESULTS, ProbeResult(block, name, :ok, detail))
            @printf("  ✓ %-50s  OK    %s\n", name, detail)
        end
        return val
    catch err
        bt = catch_backtrace()
        etype = string(typeof(err))
        tag = _is_scalar_indexing_error(err) ? "SCALAR-INDEXING" : "ERROR"
        msg = _truncate(sprint(showerror, err))
        status = expect_fail ? :xfail : :fail
        mark = expect_fail ? "✗ xfail" : "✗ FAIL "
        # Keep the full error + backtrace only for UNEXPECTED failures (xfails are the
        # known scalar-indexing cases — no need to dump their traces).
        fulltrace = status == :fail ? sprint(showerror, err, bt) : ""
        push!(RESULTS, ProbeResult(block, name, status, "$etype: $msg", fulltrace))
        @printf("  %s %-50s  %-15s %s :: %s\n", mark, name, tag, etype, msg)
        return nothing
    end
end

function section(title)
    println()
    println("="^92)
    println("  ", title)
    return println("="^92)
end

# ---------------------------------------------------------------------------
# Environment report
# ---------------------------------------------------------------------------
section("ENVIRONMENT")
const CUDA_OK = try
    CUDA.functional()
catch
    false
end
if CUDA_OK
    println("  ✓ CUDA.functional() == true — GPU probes enabled")
    try
        println("  device: ", CUDA.name(CUDA.device()))
    catch
    end
    CUDA.allowscalar(false)   # the meaningful mode: no silent scalar fallback
    println("  ✓ CUDA.allowscalar(false) set (scalar indexing will error, as intended)")
else
    println("  ⚠️  CUDA not functional — GPU probes SKIPPED (CPU baselines still run)")
end

_dev(x) = CUDA_OK ? CUDA.CuArray(x) : x

# ===========================================================================
# BLOCK 0 — array primitives used by the flow plumbing (report §6 audit points)
# ===========================================================================
section("BLOCK 0 — array primitives on device (array-type audit)")

probe("B0", "CuArray construction + broadcast (-x)"; skip_if=(!CUDA_OK)) do
    return Array(-_dev([1.0, 2.0, 3.0]))
end
probe("B0", "vcat(x0, p0) on device"; skip_if=(!CUDA_OK)) do
    return Array(vcat(_dev([1.0, 2.0]), _dev([3.0, 4.0])))
end
# calling.jl:515 builds pv0 as `zeros(eltype(x0), n)` → a HOST Vector; the augmented
# init cond is then vcat(x0, p0, pv0). Measure whether that host/device vcat is even a
# hard failure (result: it is NOT — vcat promotes), vs the device-native `similar` form.
probe("B0", "mixed host/device: vcat(dev, dev, zeros(1))"; skip_if=(!CUDA_OK)) do
    return Array(vcat(_dev([1.0, 2.0]), _dev([3.0, 4.0]), zeros(Float64, 1)))
end
probe("B0", "device-native: vcat(dev, dev, similar-zeros)"; skip_if=(!CUDA_OK)) do
    x0 = _dev([1.0, 2.0])
    return Array(vcat(x0, _dev([3.0, 4.0]), fill!(similar(x0, 1), 0)))
end

# ===========================================================================
# BLOCK 1 — AD primitives on CuArray (the core GPU gate, report §4.2)
#   f(x) = sum(abs2, x)  ⇒  ∇f = 2x  (GPU-friendly: no scalar indexing/mutation)
# ===========================================================================
section("BLOCK 1 — DifferentiationInterface.gradient on device (the AD gate)")

_f_scalar(x) = sum(abs2, x)

function _grad_probe(backend_name, make_backend; device=true, expect_fail=false)
    label = "DI.gradient $backend_name  ($(device ? "CuArray" : "host baseline"))"
    probe("B1", label; skip_if=(device && !CUDA_OK), expect_fail=expect_fail) do
        b = Differentiation.DifferentiationInterface(; ad_backend=make_backend())
        x = device ? _dev([1.0, 2.0, 3.0]) : [1.0, 2.0, 3.0]
        return Array(Differentiation.gradient(b, _f_scalar, x))   # expect ≈ 2x
    end
end

"""
The AD backends under test (phase 4e). DifferentiationInterface supports many more, but
these are the ones worth spending GPU time on:

  * `AutoForwardDiff` — the CTFlows default; scalar-indexes on GPU, so `expect_fail` on device.
  * `AutoZygote`      — the current GPU default (CTBase D2). Reverse-mode, GPU-capable, but
                        cannot differentiate mutation — which is exactly the 4f blocker.
  * `AutoMooncake`    — reverse-mode; ships GPU rules and handles mutation. The candidate.
  * `AutoEnzyme`      — reverse-mode; handles mutation. The other candidate.

Deliberately excluded: ReverseDiff and Tracker (tape-based, no DI `Cache` support, a poor fit
for `CuArray`), Diffractor (documented as broken with DI), and the remaining forward-mode
backends (same scalar-indexing barrier as ForwardDiff). Note that the DI backend page makes
**no** GPU-support claims either way — hence measuring rather than reading release notes.
"""
const AD_BACKENDS = [
    ("AutoZygote", () -> ADTypes.AutoZygote()),
    ("AutoMooncake", () -> ADTypes.AutoMooncake(; config=nothing)),
    ("AutoEnzyme", () -> ADTypes.AutoEnzyme(; mode=Enzyme.Reverse)),
]

_grad_probe("AutoForwardDiff", () -> ADTypes.AutoForwardDiff(); expect_fail=true)  # ForwardDiff scalar-indexes on GPU
for (name, make) in AD_BACKENDS
    _grad_probe(name, make)
end
_grad_probe("AutoForwardDiff", () -> ADTypes.AutoForwardDiff(); device=false)  # baseline

# ===========================================================================
# BLOCK 2 — the ACTUAL CTFlows AD call: hamiltonian_gradient on device (§4.2)
#   H(x,p) = (|x|² + |p|²)/2  ⇒  ∂H/∂x = x, ∂H/∂p = p
# ===========================================================================
section("BLOCK 2 — Differentiation.hamiltonian_gradient on device")

function _hamgrad_probe(backend_name, make_backend; expect_fail=false)
    probe(
        "B2",
        "hamiltonian_gradient $backend_name (CuArray)";
        skip_if=(!CUDA_OK),
        expect_fail=expect_fail,
    ) do
        h = Data.Hamiltonian((x, p) -> (sum(abs2, x) + sum(abs2, p)) / 2)
        b = Differentiation.DifferentiationInterface(; ad_backend=make_backend())
        ∂x, ∂p = Differentiation.hamiltonian_gradient(
            b, h, 0.0, _dev([1.0, 2.0]), _dev([3.0, 4.0]), nothing
        )
        return (Array(∂x), Array(∂p))
    end
end
_hamgrad_probe("AutoForwardDiff", () -> ADTypes.AutoForwardDiff(); expect_fail=true)
for (name, make) in AD_BACKENDS
    _hamgrad_probe(name, make)
end

# ===========================================================================
# BLOCK 3 — flows on device with CURRENT CTFlows (no code change) (§5 matrix)
# ===========================================================================
section("BLOCK 3 — flows on device (current, unparameterized CTFlows)")

# 3a — AD-FREE: Flow(VectorField), state flow. Expected: works (WithoutAD path).
probe("B3", "Flow(VectorField) point  f(t0,x0,tf)"; skip_if=(!CUDA_OK)) do
    f = Flows.Flow(Data.VectorField(x -> -x))          # ẋ = -x
    return Array(f(0.0, _dev([1.0, 2.0]), 1.0))
end
probe("B3", "Flow(VectorField) trajectory  f((t0,tf),x0)"; skip_if=(!CUDA_OK)) do
    f = Flows.Flow(Data.VectorField(x -> -x))
    return string(typeof(f((0.0, 1.0), _dev([1.0, 2.0]))))
end

# 3b — AD-FREE: Flow(HamiltonianVectorField) (X_H given explicitly). Expected: works.
probe("B3", "Flow(HamiltonianVectorField) point"; skip_if=(!CUDA_OK)) do
    f = Flows.Flow(Data.HamiltonianVectorField((x, p) -> (p, -x)))   # harmonic oscillator
    xf, pf = f(0.0, _dev([1.0, 0.0]), _dev([0.0, 1.0]), 1.0)
    return (Array(xf), Array(pf))
end

# 3c — AD: Flow(Hamiltonian), DEFAULT backend (AutoForwardDiff). Expected: FAIL on device.
probe("B3", "Flow(Hamiltonian) DEFAULT backend"; skip_if=(!CUDA_OK), expect_fail=true) do
    h = Data.Hamiltonian((x, p) -> (sum(abs2, x) + sum(abs2, p)) / 2)
    f = Flows.Flow(h)                                  # default ad_backend = AutoForwardDiff
    xf, pf = f(0.0, _dev([1.0, 0.0]), _dev([0.0, 1.0]), 1.0)
    return (Array(xf), Array(pf))
end

# 3d — AD: Flow(Hamiltonian) with a GPU-capable backend. Measure whether it works.
probe("B3", "Flow(Hamiltonian) ad_backend=AutoZygote"; skip_if=(!CUDA_OK)) do
    h = Data.Hamiltonian((x, p) -> (sum(abs2, x) + sum(abs2, p)) / 2)
    f = Flows.Flow(h; ad_backend=ADTypes.AutoZygote())
    xf, pf = f(0.0, _dev([1.0, 0.0]), _dev([0.0, 1.0]), 1.0)
    return (Array(xf), Array(pf))
end

# 3e — AD-FREE: Flow(ODEProblem) with device u0 (SciMLProblemFlow, remake path).
# The point-call returns the final state directly (a CuArray) — no final_state() wrapper.
probe("B3", "Flow(ODEProblem) point remake"; skip_if=(!CUDA_OK)) do
    prob = SciMLBase.ODEProblem((du, u, p, t) -> (du .= .-u), _dev([1.0, 2.0]), (0.0, 1.0))
    f = Flows.Flow(prob)
    return Array(f(0.0, _dev([1.0, 2.0]), 1.0))
end

# ===========================================================================
# BLOCK 4 — augmented / variable_costate on device (exercises the pv0 bug, §6)
# ===========================================================================
section("BLOCK 4 — variable_costate flow on device (pv0 construction)")

# B4a — HOST variable (the default D4 behaviour). Run 3 pinned this to a KernelError:
# _aug_assign! broadcasts the HOST ∂pv (= -∂H/∂v, host because v is host) into the DEVICE du.
probe("B4", "variable_costate, HOST variable"; skip_if=(!CUDA_OK)) do
    h = Data.Hamiltonian(
        (x, p, v) -> (sum(abs2, x) + sum(abs2, p)) / 2 + sum(v);
        is_variable=true,  # sum(v), not v[1]: scalar indexing a device v is disallowed
    )
    f = Flows.Flow(h; ad_backend=ADTypes.AutoZygote())
    xf, pf = f(
        0.0, _dev([1.0, 0.0]), _dev([0.0, 1.0]), 1.0; variable=[0.5], variable_costate=true
    )
    return (Array(xf), Array(pf))
end

# B4b — DEVICE variable, length 1. Runs 3-6 pinned this to `only(::CuArray)` scalar-indexing
# in Trajectories._aug_split_solution (the "1-D=scalar" coercion). THIS BRANCH applies the
# proposed fix (`_safe_only` = GPUArraysCore.@allowscalar only, dispatched on the live array in
# Systems._coerce_state), so this probe should now be ✓ — validating the fix end-to-end.
probe(
    "B4",
    "variable_costate, DEVICE variable, length 1 (fix: _safe_only)";
    skip_if=(!CUDA_OK),
) do
    h = Data.Hamiltonian(
        (x, p, v) -> (sum(abs2, x) + sum(abs2, p)) / 2 + sum(v);
        is_variable=true,  # sum(v), not v[1]: scalar indexing a device v is disallowed
    )
    f = Flows.Flow(h; ad_backend=ADTypes.AutoZygote())
    xf, pf = f(
        0.0,
        _dev([1.0, 0.0]),
        _dev([0.0, 1.0]),
        1.0;
        variable=_dev([0.5]),
        variable_costate=true,
    )
    return (Array(xf), Array(pf))
end

# B4c — DEVICE variable, length 2: avoids the length==1 `only` coercion entirely (both x0/p0
# and pv0 have length > 1, so _coerce_state returns `identity` everywhere). If this is ✓, it
# confirms the augmented RHS + solution-splitting pipeline is fully GPU-clean once no
# dimension is 1-D-scalar-coerced — isolating "1-D=scalar on GPU" as the ONLY remaining gap.
probe(
    "B4", "variable_costate, DEVICE variable, length 2 (avoids only())"; skip_if=(!CUDA_OK)
) do
    h = Data.Hamiltonian(
        (x, p, v) -> (sum(abs2, x) + sum(abs2, p)) / 2 + sum(v); is_variable=true
    )
    f = Flows.Flow(h; ad_backend=ADTypes.AutoZygote())
    xf, pf = f(
        0.0,
        _dev([1.0, 0.0]),
        _dev([0.0, 1.0]),
        1.0;
        variable=_dev([0.5, 0.5]),
        variable_costate=true,
    )
    return (Array(xf), Array(pf))
end

# ===========================================================================
# BLOCK 5 — Float32 end-to-end (GPUs prefer Float32; check nothing promotes)
# ===========================================================================
section("BLOCK 5 — Float32 end-to-end on device")

probe("B5", "Flow(VectorField) Float32, eltype preserved"; skip_if=(!CUDA_OK)) do
    f = Flows.Flow(Data.VectorField(x -> -x))
    xf = f(0.0f0, _dev(Float32[1, 2]), 1.0f0)
    return (eltype(xf), Array(xf))
end

# ===========================================================================
# BLOCK 6 — Ensemble GPU tooling PoC (§3 model 2 / §7 Family C)
#   Pin the DiffEqGPU tooling on the kkt hardware: N independent small ODEs solved in
#   parallel on the GPU. This is the tooling spike (which ensemble algorithm, what the RHS
#   must look like), NOT yet wired to CTFlows flows — that is the real Family C follow-up.
#   Dynamics: ẋ = -x, x(1) = x0·e⁻¹. Each trajectory perturbs x0.
# ===========================================================================
section("BLOCK 6 — ensemble GPU tooling PoC (DiffEqGPU)")

const _N_ENS = 8
const _ENS_U0(i) = [Float64(i), 2.0 * i]                 # per-trajectory initial condition
_ens_expected(i) = _ENS_U0(i) .* exp(-1.0)

# 6a — EnsembleGPUArray: in-place RHS, host arrays moved to GPU by the ensemble algorithm.
#      Most permissive path; closest to how a CTFlows in-place RHS functor would plug in.
probe("B6", "EnsembleGPUArray (in-place, N=$_N_ENS)"; skip_if=(!CUDA_OK)) do
    f!(du, u, p, t) = (du .= .-u)
    prob = SciMLBase.ODEProblem(f!, _ENS_U0(1), (0.0, 1.0))
    eprob = SciMLBase.EnsembleProblem(
        prob; prob_func=(p, ctx) -> SciMLBase.remake(p; u0=_ENS_U0(ctx.sim_id))
    )
    sol = SciMLBase.solve(
        eprob,
        OrdinaryDiffEqTsit5.Tsit5(),
        DiffEqGPU.EnsembleGPUArray(CUDA.CUDABackend());
        trajectories=_N_ENS,
        save_everystep=false,
    )
    # sol.u[i] is the i-th trajectory's ODESolution. ODESolution is itself an
    # AbstractVectorOfArray (component x time), so `[end]` on it is Cartesian linear
    # indexing into that 2-D shape (returns a single component, not the final state
    # vector) — go through its raw `.u` field (`.u[end]`) to get the actual final state.
    maxerr = maximum(
        maximum(abs.(Array(sol.u[i].u[end]) .- _ens_expected(i))) for i in 1:_N_ENS
    )
    # Device-residency check: is the per-trajectory result still a device array, or has
    # DiffEqGPU already gathered it to host before returning?
    ftype = typeof(sol.u[1].u[end])
    return "max abs err vs analytic = $maxerr; final-state type = $ftype"
end

# 6b — EnsembleGPUKernel: kernel-compiled path. Requires an out-of-place, StaticArrays RHS
#      with no host-state closures. Tells us what a GPU-kernel-ready CTFlows RHS must satisfy.
probe("B6", "EnsembleGPUKernel (out-of-place SVector, N=$_N_ENS)"; skip_if=(!CUDA_OK)) do
    f_oop(u, p, t) = -u
    u0 = SVector{2,Float64}(1.0, 2.0)
    prob = SciMLBase.ODEProblem(f_oop, u0, (0.0, 1.0))
    eprob = SciMLBase.EnsembleProblem(
        prob;
        prob_func=(p, ctx) -> SciMLBase.remake(
            p; u0=SVector{2,Float64}(Float64(ctx.sim_id), 2.0 * ctx.sim_id)
        ),
    )
    sol = SciMLBase.solve(
        eprob,
        DiffEqGPU.GPUTsit5(),
        DiffEqGPU.EnsembleGPUKernel(CUDA.CUDABackend());
        trajectories=_N_ENS,
        save_everystep=false,
    )
    maxerr = maximum(
        maximum(abs.(Array(sol.u[i].u[end]) .- _ens_expected(i))) for i in 1:_N_ENS
    )
    ftype = typeof(sol.u[1].u[end])
    return "max abs err vs analytic = $maxerr; final-state type = $ftype"
end

# 6c/6d — Coupled-oscillator RHS (ẋ = p, ṗ = -x). These rows settle a question phase 4b left
#   open, and the answer overturned BOTH earlier explanations — they are kept as executable
#   evidence for the phase-5 docs, so the mistake is not re-derived later:
#
#     • The ORIGINAL note claimed `du[1] = u[2]` was forbidden by `allowscalar(false)`.
#       False. Inside `EnsembleGPUArray` the RHS runs in a compiled kernel where du/u are
#       `CuDeviceMatrix` slices; component indexing there is ordinary device code.
#       `allowscalar(false)` guards HOST-side indexing of a device array — a different thing.
#
#     • The proposed fix — `du .= A * u`, "BLAS, not scalar indexing" — is WORSE: it does not
#       compile. `*` reaches `generic_matvecmul!` → `gemv!` plus a `similar` heap allocation,
#       none of which exist inside a GPU kernel (`InvalidIRError`). Hence expect_fail below.
#
#   The real rule: an `EnsembleGPUArray` RHS must be KERNEL-COMPILABLE — no BLAS, no heap
#   allocation. Component-wise writes are the correct idiom there; array-level linear algebra
#   is not. This is the opposite of the host-side `allowscalar(false)` rule, and the two must
#   not be conflated.
#
#   x(0) = i, p(0) = 0 ⇒ analytic x(1) = i·cos(1), p(1) = -i·sin(1).
const _HO_A = _dev([0.0 1.0; -1.0 0.0])
_ho_u0(i) = [Float64(i), 0.0]
_ho_expected(i) = [Float64(i) * cos(1.0), -Float64(i) * sin(1.0)]

probe(
    "B6",
    "EnsembleGPUArray coupled oscillator (in-place, du.=A*u, N=$_N_ENS)";
    skip_if=(!CUDA_OK),
    expect_fail=true,   # InvalidIRError: gemv! + similar are not kernel-compilable
) do
    f!(du, u, p, t) = (du .= _HO_A * u)
    prob = SciMLBase.ODEProblem(f!, _ho_u0(1), (0.0, 1.0))
    eprob = SciMLBase.EnsembleProblem(
        prob; prob_func=(p, ctx) -> SciMLBase.remake(p; u0=_ho_u0(ctx.sim_id))
    )
    sol = SciMLBase.solve(
        eprob,
        OrdinaryDiffEqTsit5.Tsit5(),
        DiffEqGPU.EnsembleGPUArray(CUDA.CUDABackend());
        trajectories=_N_ENS,
        save_everystep=false,
    )
    maxerr = maximum(
        maximum(abs.(Array(sol.u[i].u[end]) .- _ho_expected(i))) for i in 1:_N_ENS
    )
    ftype = typeof(sol.u[1].u[end])
    return "max abs err vs analytic = $maxerr; final-state type = $ftype"
end

probe(
    "B6",
    "EnsembleGPUKernel coupled oscillator (out-of-place SVector, N=$_N_ENS)";
    skip_if=(!CUDA_OK),
) do
    f_oop(u, p, t) = SVector(u[2], -u[1])
    u0 = SVector{2,Float64}(1.0, 0.0)
    prob = SciMLBase.ODEProblem(f_oop, u0, (0.0, 1.0))
    eprob = SciMLBase.EnsembleProblem(
        prob;
        prob_func=(p, ctx) ->
            SciMLBase.remake(p; u0=SVector{2,Float64}(Float64(ctx.sim_id), 0.0)),
    )
    sol = SciMLBase.solve(
        eprob,
        DiffEqGPU.GPUTsit5(),
        DiffEqGPU.EnsembleGPUKernel(CUDA.CUDABackend());
        trajectories=_N_ENS,
        save_everystep=false,
    )
    maxerr = maximum(
        maximum(abs.(Array(sol.u[i].u[end]) .- _ho_expected(i))) for i in 1:_N_ENS
    )
    ftype = typeof(sol.u[1].u[end])
    return "max abs err vs analytic = $maxerr; final-state type = $ftype"
end

# ===========================================================================
# BLOCK 7 — AD through a MUTATING in-place RHS (the actual 4f gate)
#   This is the shape of `_ocp_H`: a scalar function that fills a buffer through an
#   in-place closure, then reduces it. Zygote is the known-bad reference row — it cannot
#   differentiate mutation at all, which is *why* 4f is blocked.
#
#   Run on HOST first, then on DEVICE. That split is the point of this block: it separates
#   "this backend cannot do mutation" (host row red) from "this backend cannot do GPU"
#   (host row green, device row red). Conflating the two is what stalled 4f.
#
#   f(x) = sum(r) where r .= 2x  ⇒  ∇f = 2·ones
# ===========================================================================
section("BLOCK 7 — AD through a mutating in-place RHS (host vs device)")

_fill_twice!(r, x) = (r.=2 .* x; nothing)

function _mutating_scalar(x)
    r = similar(x, length(x))
    _fill_twice!(r, x)
    return sum(r)
end

function _mutgrad_probe(backend_name, make_backend; device=true, expect_fail=false)
    label = "DI.gradient mutating RHS $backend_name ($(device ? "CuArray" : "host"))"
    probe("B7", label; skip_if=(device && !CUDA_OK), expect_fail=expect_fail) do
        b = Differentiation.DifferentiationInterface(; ad_backend=make_backend())
        x = device ? _dev([1.0, 2.0, 3.0]) : [1.0, 2.0, 3.0]
        return Array(Differentiation.gradient(b, _mutating_scalar, x))   # expect ≈ 2·ones
    end
end

# Zygote: expected to fail on BOTH rows — mutation, not the device, is the problem.
_mutgrad_probe("AutoZygote", () -> ADTypes.AutoZygote(); device=false, expect_fail=true)
_mutgrad_probe("AutoZygote", () -> ADTypes.AutoZygote(); expect_fail=true)
for (name, make) in AD_BACKENDS
    name == "AutoZygote" && continue
    _mutgrad_probe(name, make; device=false)   # host: can it do mutation at all?
    _mutgrad_probe(name, make)                 # device: can it do mutation on GPU?
end

# ===========================================================================
# BLOCK 8 — Flow(ocp) Hamiltonian flow on device, per AD backend (the 4f question)
#   End-to-end: the OCP pseudo-Hamiltonian differentiates the user's MUTATING `dynamics!`.
#   Phase 4c shipped the AD-free OCP surface (state flows / ClosedLoop); this block asks
#   whether any backend unlocks the Hamiltonian one.
#   Fixture is device-safe by construction: broadcast dynamics (no component indexing) and
#   a `sum`-based Mayer (phase 4c: the objective is user-supplied code just like dynamics!).
# ===========================================================================
section("BLOCK 8 — Flow(ocp) Hamiltonian on device, per AD backend")

function _build_probe_ocp()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r.=(.-x); nothing))
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> sum(xf))
    return CTModels.Building.build(pre)
end

function _ocpflow_probe(backend_name, make_backend; expect_fail=false)
    probe(
        "B8",
        "Flow(ocp) Hamiltonian $backend_name (CuArray)";
        skip_if=(!CUDA_OK),
        expect_fail=expect_fail,
    ) do
        ocp = _build_probe_ocp()
        f = Flows.Flow(ocp, (x, p) -> 0.0; ad_backend=make_backend())
        xf, pf = f(0.0, _dev([1.0, 2.0]), _dev([0.0, 0.0]), 1.0)
        return (Array(xf), Array(pf))      # ẋ = -x with u ≡ 0 ⇒ xf ≈ x0·e⁻¹
    end
end

for (name, make) in AD_BACKENDS
    # Zygote is the shipped GPU default (D2) and the known blocker — mark it xfail so an
    # UNEXPECTED PASS is reported loudly if the ecosystem has moved under us.
    _ocpflow_probe(name, make; expect_fail=(name == "AutoZygote"))
end

# ===========================================================================
# SUMMARY
# ===========================================================================
section("SUMMARY — capability matrix")
let n_ok = count(r -> r.status == :ok, RESULTS),
    n_fail = count(r -> r.status == :fail, RESULTS),
    n_xfail = count(r -> r.status == :xfail, RESULTS),
    n_skip = count(r -> r.status == :skip, RESULTS)

    for r in RESULTS
        mark = if r.status == :ok
            "✓ OK   "
        elseif r.status == :xfail
            "✗ xfail"
        elseif r.status == :fail
            "✗ FAIL "
        else
            "∅ SKIP "
        end
        @printf("  [%s] %-4s %-50s %s\n", mark, r.block, r.name, _truncate(r.detail, 90))
    end
    println()
    @printf(
        "  totals:  ✓ %d ok   ✗ %d xfail(expected)   ✗ %d FAIL(unexpected)   ∅ %d skip   (of %d)\n",
        n_ok,
        n_xfail,
        n_fail,
        n_skip,
        length(RESULTS)
    )
    println()
    println(
        "  Interpretation guide (xfail = failed as expected; a bare FAIL is a real limit):"
    )
    println("   • B1/B2 xfail (SCALAR-INDEXING) on AutoForwardDiff, OK on AutoZygote")
    println(
        "     ⇒ confirms §4.2 (AD is the GPU gate; ForwardDiff scalar-indexes; Zygote works).",
    )
    println("   • B3 3a/3b/3e OK ⇒ confirms §5 'AD-free flows are GPU-ready first'.")
    println(
        "   • B3 3c xfail vs 3d OK ⇒ Flow(Hamiltonian; ad_backend=AutoZygote) already runs;"
    )
    println("     only the DEFAULT backend must change (D2 = AutoZygote).")
    println(
        "   • B0 both OK ⇒ host/device vcat is NOT a hard failure; the pv0 `zeros` is hygiene.",
    )
    println("   • B4 (this branch applies the _safe_only fix):")
    println(
        "     - HOST variable ⇒ still _aug_assign! host-∂pv-into-device-du (KernelError, separate fix).",
    )
    println(
        "     - DEVICE variable, length 1 ⇒ should now be ✓ (_safe_only = @allowscalar only fixes the",
    )
    println(
        "       '1-D=scalar on GPU' solution-split coercion). This validates the chosen fix.",
    )
    println(
        "     - DEVICE variable, length 2 ⇒ ✓ (never hit `only`; augmented pipeline is GPU-clean).",
    )
    println("   • B5 eltype == Float32 ⇒ no silent Float64 promotion.")
    println(
        "   • B6 ⇒ DiffEqGPU ensemble tooling PoC: EnsembleGPUArray (permissive, in-place) and",
    )
    println(
        "     EnsembleGPUKernel (kernel-compiled, needs OOP + StaticArrays) both matching analytic.",
    )
    println(
        "   • B7 is the 4f gate, and the HOST rows already decide half of it (they run without CUDA):",
    )
    println(
        "     Zygote xfail on host ⇒ the blocker is mutation, NOT the device. Mooncake/Enzyme OK on",
    )
    println(
        "     host ⇒ both can differentiate mutation; the device rows say whether that survives GPU.",
    )
    println(
        "   • B8 ⇒ the end-to-end answer: if any backend is OK, 4f is a backend swap rather than a",
    )
    println(
        "     rewrite of `dynamics!`. An UNEXPECTED PASS on the Zygote row would mean D2 is fine.",
    )
end

# ---------------------------------------------------------------------------
# Full detail for UNEXPECTED failures (the untruncated error + backtrace) — this is
# what pins the root cause of a genuine limitation (currently B4's KernelError).
# ---------------------------------------------------------------------------
let unexpected = filter(r -> r.status == :fail && !isempty(r.fulltrace), RESULTS)
    if !isempty(unexpected)
        section("UNEXPECTED-FAILURE DETAIL (full error + backtrace)")
        for r in unexpected
            println()
            println("  ── [", r.block, "] ", r.name, " ──")
            println(r.fulltrace)
        end
    end
end
