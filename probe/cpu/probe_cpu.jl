#!/usr/bin/env julia
# =============================================================================
# CPU capability probe for CTFlows  —  Flow constructor state-type matrices
# =============================================================================
#
# Purpose
# -------
# Turn the compatibility *claims* of the docs into *measured facts* on CPU, WITHOUT
# modifying any package. It probes, against the CURRENT working-tree CTFlows, which
# combinations of (state container, scalar element type, call style, vector-field
# mutability) actually work — and, for the ones that warn or fail, how.
#
# It is the ground-truth source for `docs/src/compatibility/vector_field.md`: every
# ✓ / ⚠ in that page's table is backed by a green cell here.
#
# It is a diagnostic, not a test suite: nothing here asserts pass/fail. Every
# experiment is wrapped in try/catch so a single failure never stops the run, and every
# outcome is collected into a final capability MATRIX printed at the bottom of the log.
#
# How it is run
# -------------
#     julia --project=probe/cpu probe/cpu/probe_cpu.jl
# The header activates this folder's own environment and `dev`s the checked-out CTFlows
# so the probe measures the working-tree source (not the registered version).
#
# Scope: `Flow(VectorField)` and `Flow(HamiltonianVectorField)` today. Other
# constructors (Hamiltonian, ODEFunction/ODEProblem, ocp) become additional
# blocks as their compatibility pages land.
# =============================================================================

# ---------------------------------------------------------------------------
# Environment: activate this probe's project and dev the checked-out CTFlows
# (mirrors probe/gpu; Manifest is intentionally not committed)
# ---------------------------------------------------------------------------
using Pkg
Pkg.activate(@__DIR__)
Pkg.develop(; path=joinpath(@__DIR__, "..", ".."))   # the repo root (this CTFlows)
Pkg.instantiate()

using Printf: @printf, @sprintf
using Logging

using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5   # activates the CTFlows SciML integrator ext
using StaticArrays: SA, SVector, MVector, SMatrix, MMatrix
using ForwardDiff: ForwardDiff

import CTBase.Data
import CTFlows.Flows
import CTFlows.Trajectories

# ---------------------------------------------------------------------------
# Log collector to detect the "InPlace VectorField" performance warning
# ---------------------------------------------------------------------------
struct CollectLogger <: Logging.AbstractLogger
    msgs::Vector{String}
end
Logging.min_enabled_level(::CollectLogger) = Logging.Debug
Logging.shouldlog(::CollectLogger, args...) = true
function Logging.handle_message(l::CollectLogger, lvl, msg, _mod, grp, id, file, line; kw...)
    push!(l.msgs, string(msg))
    return nothing
end
Logging.catch_exceptions(::CollectLogger) = false

# ---------------------------------------------------------------------------
# Correctness helper: compare against the analytic solution x(1) = x0 · e⁻¹
# (strips ForwardDiff.Dual to its value; flattens scalars/vectors/matrices)
# ---------------------------------------------------------------------------
const E = exp(-1.0)
_val(x) = x isa ForwardDiff.Dual ? ForwardDiff.value(x) : x
_flat(a) = a isa Number ? [_val(a)] : _val.(vec(collect(a)))

function _maxerr(kind, r, x0)
    got = kind === :point ? r : Trajectories.state(r)(1.0)
    return maximum(abs.(_flat(got) .- _flat(x0 .* E)))
end

# ---------------------------------------------------------------------------
# Run one cell: returns (mark, detail). mark ∈ {"✓","⚠","✗"}.
# ---------------------------------------------------------------------------
function cell(fl, kind, x0)
    g = kind === :point ? (() -> fl(0.0, x0, 1.0)) : (() -> fl((0.0, 1.0), x0))
    l = CollectLogger(String[])
    try
        r = Logging.with_logger(l) do
            g()
        end
        warned = any(m -> occursin("InPlace VectorField", m), l.msgs)
        err = try
            _maxerr(kind, r, x0)
        catch
            NaN
        end
        ok = isfinite(err) && err ≤ 1e-4
        mark = ok ? (warned ? "⚠" : "✓") : "?"
        return (mark, @sprintf("err=%.1e%s", err, warned ? " (warns)" : ""))
    catch e
        return ("✗", string(nameof(typeof(e))))
    end
end

# ---------------------------------------------------------------------------
# The two flows (defined ONCE, exactly as the doc's @setup block does)
# ---------------------------------------------------------------------------
vf      = Data.VectorField(x -> -x)                                                       # out-of-place
flow    = Flows.Flow(vf; reltol=1e-8)
vf_ip   = Data.VectorField((du, x) -> (du .= -x); is_autonomous=true, is_variable=false)  # in-place
flow_ip = Flows.Flow(vf_ip; reltol=1e-8)

# ---------------------------------------------------------------------------
# State samples: (label, x0). Everything decays to x0 · e⁻¹ under ẋ = -x.
# ---------------------------------------------------------------------------
cases = [
    ("scalar Real",     1.0),
    ("Vector Real",     [1.0, 2.0]),
    ("MVector Real",    MVector{2}(1.0, 2.0)),
    ("SVector Real",    SA[1.0, 2.0]),
    ("Matrix Real",     [1.0 2.0; 3.0 4.0]),
    ("MMatrix Real",    MMatrix{2,2}(1.0, 3.0, 2.0, 4.0)),
    ("SMatrix Real",    SMatrix{2,2}(1.0, 3.0, 2.0, 4.0)),
    ("scalar Complex",  1.0 + 2.0im),
    ("Vector Complex",  [1.0 + 2.0im, 3.0 + 4.0im]),
    ("MVector Complex", MVector{2}(1.0 + 2.0im, 3.0 + 4.0im)),
    ("SVector Complex", SA[1.0 + 2.0im, 3.0 + 4.0im]),
    ("Matrix Complex",  [1.0+2.0im 5.0+6.0im; 3.0+4.0im 7.0+8.0im]),
    ("SMatrix Complex", SMatrix{2,2}(1.0+2.0im, 3.0+4.0im, 5.0+6.0im, 7.0+8.0im)),
    ("Dual scalar",     ForwardDiff.Dual(1.0, 1.0)),
    ("Dual Vector",     [ForwardDiff.Dual(1.0, 1.0), ForwardDiff.Dual(2.0, 0.0)]),
    ("Dual MVector",    MVector{2}(ForwardDiff.Dual(1.0, 1.0), ForwardDiff.Dual(2.0, 0.0))),
    ("Dual SVector",    SA[ForwardDiff.Dual(1.0, 1.0), ForwardDiff.Dual(2.0, 0.0)]),
]

# ---------------------------------------------------------------------------
# Run the matrix
# ---------------------------------------------------------------------------
println("\n", "="^96)
println("  CTFlows CPU probe — Flow(VectorField), dynamics ẋ = -x,  x(1) = x0·e⁻¹")
println("  columns describe the vector-field kind (OOP: x->-x  |  IP: (du,x)->du.=-x)")
println("="^96)
println(@sprintf("  %-16s | %-14s | %-14s | %-14s | %-14s",
    "state", "OOP point", "OOP traj", "IP point", "IP traj"))
println("  " * "-"^92)

n_ok = n_warn = n_fail = 0
for (lab, x0) in cases
    marks = String[]
    for (fl, kind) in ((flow, :point), (flow, :traj), (flow_ip, :point), (flow_ip, :traj))
        m, d = cell(fl, kind, x0)
        m == "✓" && (global n_ok += 1)
        m == "⚠" && (global n_warn += 1)
        (m == "✗" || m == "?") && (global n_fail += 1)
        push!(marks, @sprintf("%s %-12s", m, d))
    end
    println(@sprintf("  %-16s | %s | %s | %s | %s", lab, marks[1], marks[2], marks[3], marks[4]))
end

println("  " * "-"^92)
println(@sprintf("  totals:  ✓ %d works   ⚠ %d works-with-warning   ✗/? %d fail-or-wrong   (of %d)",
    n_ok, n_warn, n_fail, 4 * length(cases)))
println("="^96)
println("""
  Legend & notes
  ──────────────
  ✓  works, result matches analytic to err ≤ 1e-4
  ⚠  works but emits a performance @warn — in-place VF + immutable u0 (SVector/SMatrix):
     the flow falls back to an out-of-place "finalize" RHS (correct, slower).
  ✗  raised the named error type    ?  ran but result did not match analytic

  Observed nuances (fold into docs/src/compatibility/vector_field.md):
   • Everything is green on CPU — no unsupported (✗) state type.
   • Scalar state: the POINT call returns a scalar; the TRAJECTORY call's state(sol)(t)
     returns a length-1 vector (state flows preserve vector shape). Both are correct.
   • In-place VF + scalar WORKS (scalar is promoted to a length-1 vector before the
     mutability dispatch), so it is NOT rejected via the public flow API.
   • Only ⚠ cells: SVector / SMatrix with an in-place vector field.
""")

# =============================================================================
# HamiltonianVectorField probe — Flow(HamiltonianVectorField) state/costate matrix
# =============================================================================
#
# Ground-truth source for docs/src/compatibility/hamiltonian_vector_field.md.
# Dynamics: the harmonic oscillator x' = p, p' = -x, integrated (0, π/2). Analytic
# solution: x(t) = x0·cos(t) + p0·sin(t), p(t) = -x0·sin(t) + p0·cos(t), so at
# t = π/2: xf = p0, pf = -x0. (x0, p0) pairs mirror the values already used in
# test/suite/extensions/test_flow_callables_sciml_hamiltonian_vector_field.jl.
# =============================================================================

hvf      = Data.HamiltonianVectorField((x, p) -> (p, -x))                                                                # out-of-place
hflow    = Flows.Flow(hvf; reltol=1e-8)
hvf_ip   = Data.HamiltonianVectorField(
    (dx, dp, x, p) -> (dx .= p; dp .= -x); is_autonomous=true, is_variable=false
)                                                                                                                          # in-place
hflow_ip = Flows.Flow(hvf_ip; reltol=1e-8)

function _maxerr_hvf(kind, r, x0, p0)
    if kind === :point
        xf, pf = r
    else
        xf = Trajectories.state(r)(pi / 2)
        pf = Trajectories.costate(r)(pi / 2)
    end
    return maximum(abs.(vcat(_flat(xf) .- _flat(p0), _flat(pf) .- _flat(-x0))))
end

function cell_hvf(fl, kind, x0, p0)
    g = kind === :point ? (() -> fl(0.0, x0, p0, pi / 2)) : (() -> fl((0.0, pi / 2), x0, p0))
    l = CollectLogger(String[])
    try
        r = Logging.with_logger(l) do
            g()
        end
        warned = any(m -> occursin("InPlace HamiltonianVectorField", m), l.msgs)
        err = try
            _maxerr_hvf(kind, r, x0, p0)
        catch
            NaN
        end
        ok = isfinite(err) && err ≤ 1e-4
        mark = ok ? (warned ? "⚠" : "✓") : "?"
        return (mark, @sprintf("err=%.1e%s", err, warned ? " (warns)" : ""))
    catch e
        return ("✗", string(nameof(typeof(e))))
    end
end

cases_hvf = [
    ("scalar Real",     1.0,                                  0.0),
    ("Vector Real",     [1.0, 0.0],                            [0.0, 1.0]),
    ("MVector Real",    MVector{2}(1.0, 0.0),                  MVector{2}(0.0, 1.0)),
    ("SVector Real",    SA[1.0, 0.0],                          SA[0.0, 1.0]),
    ("Matrix Real",     [1.0 2.0; 3.0 4.0],                    [0.0 0.0; 1.0 1.0]),
    ("MMatrix Real",    MMatrix{2,2}(1.0, 3.0, 2.0, 4.0),      MMatrix{2,2}(0.0, 1.0, 0.0, 1.0)),
    ("SMatrix Real",    SMatrix{2,2}(1.0, 3.0, 2.0, 4.0),      SMatrix{2,2}(0.0, 1.0, 0.0, 1.0)),
    ("scalar Complex",  1.0 + 2.0im,                           0.0 + 0.0im),
    ("Vector Complex",  [1.0 + 2.0im, 0.0 + 0.0im],            [0.0 + 0.0im, 1.0 + 1.0im]),
    ("MVector Complex", MVector{2}(1.0 + 2.0im, 0.0 + 0.0im),  MVector{2}(0.0 + 0.0im, 1.0 + 1.0im)),
    ("SVector Complex", SA[1.0 + 2.0im, 0.0 + 0.0im],          SA[0.0 + 0.0im, 1.0 + 1.0im]),
    ("Matrix Complex",  [1.0+2.0im 5.0+6.0im; 3.0+4.0im 7.0+8.0im], [0.0+0.0im 1.0+1.0im; 2.0+2.0im 3.0+3.0im]),
    ("SMatrix Complex", SMatrix{2,2}(1.0+2.0im, 3.0+4.0im, 5.0+6.0im, 7.0+8.0im), SMatrix{2,2}(0.0+0.0im, 2.0+2.0im, 1.0+1.0im, 3.0+3.0im)),
    ("Dual scalar",     ForwardDiff.Dual(1.0, 1.0),            ForwardDiff.Dual(0.0, 0.0)),
    ("Dual Vector",     [ForwardDiff.Dual(1.0, 1.0), ForwardDiff.Dual(0.0, 0.0)], [ForwardDiff.Dual(0.0, 0.0), ForwardDiff.Dual(1.0, 0.0)]),
    ("Dual MVector",    MVector{2}(ForwardDiff.Dual(1.0, 1.0), ForwardDiff.Dual(0.0, 0.0)), MVector{2}(ForwardDiff.Dual(0.0, 0.0), ForwardDiff.Dual(1.0, 0.0))),
    ("Dual SVector",    SA[ForwardDiff.Dual(1.0, 1.0), ForwardDiff.Dual(0.0, 0.0)], SA[ForwardDiff.Dual(0.0, 0.0), ForwardDiff.Dual(1.0, 0.0)]),
]

println("\n", "="^96)
println("  CTFlows CPU probe — Flow(HamiltonianVectorField), x' = p, p' = -x,  (0, π/2)")
println("  analytic: xf = p0, pf = -x0.  columns: OOP (x,p)->(p,-x)  |  IP (dx,dp,x,p)->…")
println("="^96)
println(@sprintf("  %-16s | %-14s | %-14s | %-14s | %-14s",
    "state/costate", "OOP point", "OOP traj", "IP point", "IP traj"))
println("  " * "-"^92)

n_ok_hvf = n_warn_hvf = n_fail_hvf = 0
for (lab, x0, p0) in cases_hvf
    marks = String[]
    for (fl, kind) in ((hflow, :point), (hflow, :traj), (hflow_ip, :point), (hflow_ip, :traj))
        m, d = cell_hvf(fl, kind, x0, p0)
        m == "✓" && (global n_ok_hvf += 1)
        m == "⚠" && (global n_warn_hvf += 1)
        (m == "✗" || m == "?") && (global n_fail_hvf += 1)
        push!(marks, @sprintf("%s %-12s", m, d))
    end
    println(@sprintf("  %-16s | %s | %s | %s | %s", lab, marks[1], marks[2], marks[3], marks[4]))
end

println("  " * "-"^92)
println(@sprintf("  totals:  ✓ %d works   ⚠ %d works-with-warning   ✗/? %d fail-or-wrong   (of %d)",
    n_ok_hvf, n_warn_hvf, n_fail_hvf, 4 * length(cases_hvf)))
println("="^96)
println("""
  Legend & notes
  ──────────────
  ✓  works, result matches analytic (xf ≈ p0, pf ≈ -x0) to err ≤ 1e-4
  ⚠  works but emits a performance @warn — in-place HVF + immutable u0 (SVector/SMatrix):
     same fallback as Flow(VectorField).
  ✗  raised the named error type    ?  ran but result did not match analytic

  Observed nuances (fold into docs/src/compatibility/hamiltonian_vector_field.md):
   • Everything is green on CPU — no unsupported (✗) state/costate type.
   • Unlike Flow(VectorField), Flow(HamiltonianVectorField) is 1-D = scalar END TO END:
     for a scalar (x0, p0), the TRAJECTORY accessors state(sol)(t)/costate(sol)(t) also
     return scalars — not length-1 vectors. See issue #357 (Flow(VectorField) should
     eventually match this).
   • Only ⚠ cells: SVector / SMatrix with an in-place Hamiltonian vector field.
""")
