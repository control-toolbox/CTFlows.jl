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
import ADTypes
using ForwardDiff: ForwardDiff                   # activates DI AutoForwardDiff
using Zygote: Zygote                             # activates DI AutoZygote

import CTBase.Data
import CTBase.Differentiation
import CTFlows.Flows

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
function probe(f, block, name; skip_if::Bool=false, skip_reason::String="", expect_fail::Bool=false)
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
    println("="^92)
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

probe("B0", "CuArray construction + broadcast (-x)"; skip_if=!CUDA_OK) do
    Array(-_dev([1.0, 2.0, 3.0]))
end
probe("B0", "vcat(x0, p0) on device"; skip_if=!CUDA_OK) do
    Array(vcat(_dev([1.0, 2.0]), _dev([3.0, 4.0])))
end
# calling.jl:515 builds pv0 as `zeros(eltype(x0), n)` → a HOST Vector; the augmented
# init cond is then vcat(x0, p0, pv0). Measure whether that host/device vcat is even a
# hard failure (result: it is NOT — vcat promotes), vs the device-native `similar` form.
probe("B0", "mixed host/device: vcat(dev, dev, zeros(1))"; skip_if=!CUDA_OK) do
    Array(vcat(_dev([1.0, 2.0]), _dev([3.0, 4.0]), zeros(Float64, 1)))
end
probe("B0", "device-native: vcat(dev, dev, similar-zeros)"; skip_if=!CUDA_OK) do
    x0 = _dev([1.0, 2.0])
    Array(vcat(x0, _dev([3.0, 4.0]), fill!(similar(x0, 1), 0)))
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
        Array(Differentiation.gradient(b, _f_scalar, x))   # expect ≈ 2x
    end
end

_grad_probe("AutoForwardDiff", () -> ADTypes.AutoForwardDiff(); expect_fail=true)  # ForwardDiff scalar-indexes on GPU
_grad_probe("AutoZygote", () -> ADTypes.AutoZygote())
_grad_probe("AutoForwardDiff", () -> ADTypes.AutoForwardDiff(); device=false)  # baseline

# ===========================================================================
# BLOCK 2 — the ACTUAL CTFlows AD call: hamiltonian_gradient on device (§4.2)
#   H(x,p) = (|x|² + |p|²)/2  ⇒  ∂H/∂x = x, ∂H/∂p = p
# ===========================================================================
section("BLOCK 2 — Differentiation.hamiltonian_gradient on device")

function _hamgrad_probe(backend_name, make_backend; expect_fail=false)
    probe("B2", "hamiltonian_gradient $backend_name (CuArray)"; skip_if=!CUDA_OK, expect_fail=expect_fail) do
        h = Data.Hamiltonian((x, p) -> (sum(abs2, x) + sum(abs2, p)) / 2)
        b = Differentiation.DifferentiationInterface(; ad_backend=make_backend())
        ∂x, ∂p = Differentiation.hamiltonian_gradient(
            b, h, 0.0, _dev([1.0, 2.0]), _dev([3.0, 4.0]), nothing
        )
        (Array(∂x), Array(∂p))
    end
end
_hamgrad_probe("AutoForwardDiff", () -> ADTypes.AutoForwardDiff(); expect_fail=true)
_hamgrad_probe("AutoZygote", () -> ADTypes.AutoZygote())

# ===========================================================================
# BLOCK 3 — flows on device with CURRENT CTFlows (no code change) (§5 matrix)
# ===========================================================================
section("BLOCK 3 — flows on device (current, unparameterized CTFlows)")

# 3a — AD-FREE: Flow(VectorField), state flow. Expected: works (WithoutAD path).
probe("B3", "Flow(VectorField) point  f(t0,x0,tf)"; skip_if=!CUDA_OK) do
    f = Flows.Flow(Data.VectorField(x -> -x))          # ẋ = -x
    Array(f(0.0, _dev([1.0, 2.0]), 1.0))
end
probe("B3", "Flow(VectorField) trajectory  f((t0,tf),x0)"; skip_if=!CUDA_OK) do
    f = Flows.Flow(Data.VectorField(x -> -x))
    string(typeof(f((0.0, 1.0), _dev([1.0, 2.0]))))
end

# 3b — AD-FREE: Flow(HamiltonianVectorField) (X_H given explicitly). Expected: works.
probe("B3", "Flow(HamiltonianVectorField) point"; skip_if=!CUDA_OK) do
    f = Flows.Flow(Data.HamiltonianVectorField((x, p) -> (p, -x)))   # harmonic oscillator
    xf, pf = f(0.0, _dev([1.0, 0.0]), _dev([0.0, 1.0]), 1.0)
    (Array(xf), Array(pf))
end

# 3c — AD: Flow(Hamiltonian), DEFAULT backend (AutoForwardDiff). Expected: FAIL on device.
probe("B3", "Flow(Hamiltonian) DEFAULT backend"; skip_if=!CUDA_OK, expect_fail=true) do
    h = Data.Hamiltonian((x, p) -> (sum(abs2, x) + sum(abs2, p)) / 2)
    f = Flows.Flow(h)                                  # default ad_backend = AutoForwardDiff
    xf, pf = f(0.0, _dev([1.0, 0.0]), _dev([0.0, 1.0]), 1.0)
    (Array(xf), Array(pf))
end

# 3d — AD: Flow(Hamiltonian) with a GPU-capable backend. Measure whether it works.
probe("B3", "Flow(Hamiltonian) ad_backend=AutoZygote"; skip_if=!CUDA_OK) do
    h = Data.Hamiltonian((x, p) -> (sum(abs2, x) + sum(abs2, p)) / 2)
    f = Flows.Flow(h; ad_backend=ADTypes.AutoZygote())
    xf, pf = f(0.0, _dev([1.0, 0.0]), _dev([0.0, 1.0]), 1.0)
    (Array(xf), Array(pf))
end

# 3e — AD-FREE: Flow(ODEProblem) with device u0 (SciMLProblemFlow, remake path).
# The point-call returns the final state directly (a CuArray) — no final_state() wrapper.
probe("B3", "Flow(ODEProblem) point remake"; skip_if=!CUDA_OK) do
    prob = SciMLBase.ODEProblem((du, u, p, t) -> (du .= .-u), _dev([1.0, 2.0]), (0.0, 1.0))
    f = Flows.Flow(prob)
    Array(f(0.0, _dev([1.0, 2.0]), 1.0))
end

# ===========================================================================
# BLOCK 4 — augmented / variable_costate on device (exercises the pv0 bug, §6)
# ===========================================================================
section("BLOCK 4 — variable_costate flow on device (pv0 construction)")

probe("B4", "Flow(Hamiltonian) variable_costate=true"; skip_if=!CUDA_OK) do
    h = Data.Hamiltonian(
        (x, p, v) -> (sum(abs2, x) + sum(abs2, p)) / 2 + v[1]; is_variable=true
    )
    f = Flows.Flow(h; ad_backend=ADTypes.AutoZygote())
    xf, pf = f(
        0.0, _dev([1.0, 0.0]), _dev([0.0, 1.0]), 1.0; variable=[0.5], variable_costate=true
    )
    (Array(xf), Array(pf))
end

# ===========================================================================
# BLOCK 5 — Float32 end-to-end (GPUs prefer Float32; check nothing promotes)
# ===========================================================================
section("BLOCK 5 — Float32 end-to-end on device")

probe("B5", "Flow(VectorField) Float32, eltype preserved"; skip_if=!CUDA_OK) do
    f = Flows.Flow(Data.VectorField(x -> -x))
    xf = f(0.0f0, _dev(Float32[1, 2]), 1.0f0)
    (eltype(xf), Array(xf))
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
        mark =
            r.status == :ok ? "✓ OK   " :
            r.status == :xfail ? "✗ xfail" :
            r.status == :fail ? "✗ FAIL " : "∅ SKIP "
        @printf("  [%s] %-4s %-50s %s\n", mark, r.block, r.name, _truncate(r.detail, 90))
    end
    println()
    @printf(
        "  totals:  ✓ %d ok   ✗ %d xfail(expected)   ✗ %d FAIL(unexpected)   ∅ %d skip   (of %d)\n",
        n_ok, n_xfail, n_fail, n_skip, length(RESULTS)
    )
    println()
    println("  Interpretation guide (xfail = failed as expected; a bare FAIL is a real limit):")
    println("   • B1/B2 xfail (SCALAR-INDEXING) on AutoForwardDiff, OK on AutoZygote")
    println("     ⇒ confirms §4.2 (AD is the GPU gate; ForwardDiff scalar-indexes; Zygote works).")
    println("   • B3 3a/3b/3e OK ⇒ confirms §5 'AD-free flows are GPU-ready first'.")
    println("   • B3 3c xfail vs 3d OK ⇒ Flow(Hamiltonian; ad_backend=AutoZygote) already runs;")
    println("     only the DEFAULT backend must change (D2 = AutoZygote).")
    println("   • B0 both OK ⇒ host/device vcat is NOT a hard failure; the pv0 `zeros` is hygiene,")
    println("     not the augmented blocker. The real augmented blocker is B4 (kernel compilation).")
    println("   • B4 FAIL ⇒ variable_costate augmented RHS is not GPU-compilable yet — investigate.")
    println("   • B5 eltype == Float32 ⇒ no silent Float64 promotion.")
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
