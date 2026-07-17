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
import CTFlows.Integrators

# ---------------------------------------------------------------------------
# Probe harness: run a labelled experiment, catch everything, record + print
# ---------------------------------------------------------------------------
struct ProbeResult
    block::String
    name::String
    status::Symbol           # :ok | :fail | :skip
    detail::String           # value summary, or exception type + message
end
const RESULTS = ProbeResult[]

_truncate(s, n=140) = length(s) > n ? first(s, n) * " …" : s

function _is_scalar_indexing_error(err)
    s = lowercase(sprint(showerror, err))
    return occursin("scalar indexing", s) || occursin("allowscalar", s)
end

# Run the experiment `f`. Prints ✓ / ✗ / ∅ with a one-line detail and records it.
# A returned value is stringified as the success detail; any thrown error is caught,
# classified (scalar-indexing errors flagged explicitly) and recorded as :fail.
function probe(f, block, name; skip_if::Bool=false, skip_reason::String="")
    if skip_if
        push!(RESULTS, ProbeResult(block, name, :skip, skip_reason))
        @printf("  ∅ %-50s  SKIP  (%s)\n", name, skip_reason)
        return nothing
    end
    try
        val = f()
        detail = _truncate(string(val))
        push!(RESULTS, ProbeResult(block, name, :ok, detail))
        @printf("  ✓ %-50s  OK    %s\n", name, detail)
        return val
    catch err
        etype = string(typeof(err))
        tag = _is_scalar_indexing_error(err) ? "SCALAR-INDEXING" : "ERROR"
        msg = _truncate(sprint(showerror, err))
        push!(RESULTS, ProbeResult(block, name, :fail, "$etype: $msg"))
        @printf("  ✗ %-50s  %-15s %s :: %s\n", name, tag, etype, msg)
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
# The pv0 bug: calling.jl:515 does `zeros(eltype(x0), n)` → a host Vector; then
# vcat(x0, p0, pv0) mixes device + host. Probe the buggy form and the proposed fix.
probe("B0", "BUG repro: vcat(dev, dev, zeros(1)) [host pv0]"; skip_if=!CUDA_OK) do
    Array(vcat(_dev([1.0, 2.0]), _dev([3.0, 4.0]), zeros(Float64, 1)))
end
probe("B0", "FIX repro: vcat(dev, dev, similar-zeros)"; skip_if=!CUDA_OK) do
    x0 = _dev([1.0, 2.0])
    Array(vcat(x0, _dev([3.0, 4.0]), fill!(similar(x0, 1), 0)))
end

# ===========================================================================
# BLOCK 1 — AD primitives on CuArray (the core GPU gate, report §4.2)
#   f(x) = sum(abs2, x)  ⇒  ∇f = 2x  (GPU-friendly: no scalar indexing/mutation)
# ===========================================================================
section("BLOCK 1 — DifferentiationInterface.gradient on device (the AD gate)")

_f_scalar(x) = sum(abs2, x)

function _grad_probe(backend_name, make_backend; device=true)
    label = "DI.gradient $backend_name  ($(device ? "CuArray" : "host baseline"))"
    probe("B1", label; skip_if=(device && !CUDA_OK)) do
        b = Differentiation.DifferentiationInterface(; ad_backend=make_backend())
        x = device ? _dev([1.0, 2.0, 3.0]) : [1.0, 2.0, 3.0]
        Array(Differentiation.gradient(b, _f_scalar, x))   # expect ≈ 2x
    end
end

_grad_probe("AutoForwardDiff", () -> ADTypes.AutoForwardDiff())
_grad_probe("AutoZygote", () -> ADTypes.AutoZygote())
_grad_probe("AutoForwardDiff", () -> ADTypes.AutoForwardDiff(); device=false)  # baseline

# ===========================================================================
# BLOCK 2 — the ACTUAL CTFlows AD call: hamiltonian_gradient on device (§4.2)
#   H(x,p) = (|x|² + |p|²)/2  ⇒  ∂H/∂x = x, ∂H/∂p = p
# ===========================================================================
section("BLOCK 2 — Differentiation.hamiltonian_gradient on device")

function _hamgrad_probe(backend_name, make_backend)
    probe("B2", "hamiltonian_gradient $backend_name (CuArray)"; skip_if=!CUDA_OK) do
        h = Data.Hamiltonian((x, p) -> (sum(abs2, x) + sum(abs2, p)) / 2)
        b = Differentiation.DifferentiationInterface(; ad_backend=make_backend())
        ∂x, ∂p = Differentiation.hamiltonian_gradient(
            b, h, 0.0, _dev([1.0, 2.0]), _dev([3.0, 4.0]), nothing
        )
        (Array(∂x), Array(∂p))
    end
end
_hamgrad_probe("AutoForwardDiff", () -> ADTypes.AutoForwardDiff())
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
probe("B3", "Flow(Hamiltonian) DEFAULT backend (expect fail)"; skip_if=!CUDA_OK) do
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
probe("B3", "Flow(ODEProblem) point remake"; skip_if=!CUDA_OK) do
    prob = SciMLBase.ODEProblem((du, u, p, t) -> (du .= .-u), _dev([1.0, 2.0]), (0.0, 1.0))
    f = Flows.Flow(prob)
    Array(Integrators.final_state(f(0.0, _dev([1.0, 2.0]), 1.0)))
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
    n_skip = count(r -> r.status == :skip, RESULTS)

    for r in RESULTS
        mark = r.status == :ok ? "✓ OK  " : r.status == :fail ? "✗ FAIL" : "∅ SKIP"
        @printf("  [%s] %-4s %-50s %s\n", mark, r.block, r.name, _truncate(r.detail, 90))
    end
    println()
    @printf(
        "  totals:  ✓ %d ok   ✗ %d fail   ∅ %d skip   (of %d)\n",
        n_ok, n_fail, n_skip, length(RESULTS)
    )
    println()
    println("  Interpretation guide:")
    println("   • B1/B2 FAIL (SCALAR-INDEXING) on AutoForwardDiff, OK on AutoZygote")
    println("     ⇒ confirms §4.2 (AD is the GPU gate; ForwardDiff scalar-indexes).")
    println("   • B3 3a/3b/3e OK ⇒ confirms §5 'AD-free flows are GPU-ready first'.")
    println("   • B3 3c FAIL vs 3d OK ⇒ confirms the AD-backend default is what must change.")
    println("   • B0 BUG-repro FAIL vs FIX-repro OK, and B4 ⇒ confirms the pv0 fix (§6).")
    println("   • B5 eltype == Float32 ⇒ no silent Float64 promotion.")
end
