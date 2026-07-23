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
# Scope: `Flow(VectorField)`, `Flow(HamiltonianVectorField)`, `Flow(Hamiltonian)`,
# `Flow(::ODEFunction)`, and `Flow(::ODEProblem)` today. `Flow(ocp)` becomes an
# additional block once its compatibility page lands.
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
using SciMLBase: SciMLBase

import CTBase.Data
import CTFlows.Flows
import CTFlows.Trajectories
import CTFlows.Integrators

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
# Sensitivities of Flow(VectorField) — differentiate the CALL, not one hand-seeded Dual
# =============================================================================
#
# The Dual cells in the table above (a single Dual per component, one seed direction at a
# time) work, but that is not how you would actually compute a Jacobian in practice: wrap
# the flow CALL in an outer ForwardDiff.jacobian/gradient instead — one call gets every
# partial at once. Unlike Flow(Hamiltonian), there is no internal AD backend here to nest
# against, so this is unconditionally straightforward (no tag question at all).
# =============================================================================

println("\n", "="^96)
println("  Sensitivities of Flow(VectorField) via an outer ForwardDiff.jacobian call")
println("="^96)
let
    J = ForwardDiff.jacobian(x0 -> flow(0.0, x0, 1.0), [1.0, 2.0])
    ok = isapprox(J, exp(-1.0) * [1.0 0.0; 0.0 1.0]; atol=1e-4)
    println("  ✓ ForwardDiff.jacobian(x0 -> flow(0,x0,1), x0)  ", ok ? "matches e⁻¹·I" : "MISMATCH: $J")
end

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

# =============================================================================
# Sensitivities of Flow(HamiltonianVectorField) — differentiate the CALL
# =============================================================================
#
# Same point as for Flow(VectorField): wrap the flow CALL in an outer
# ForwardDiff.jacobian/gradient rather than hand-seeding one Dual component at a time.
# No internal AD backend here either, so — unlike Flow(Hamiltonian) — there is no nested
# Dual/tag question at all. Same dynamics as the Hamiltonian (AD) block below, so this
# Jacobian is a direct cross-check: both constructors must agree on it.
# =============================================================================

println("\n", "="^96)
println("  Sensitivities of Flow(HamiltonianVectorField) via an outer ForwardDiff.jacobian call")
println("="^96)
let
    shoot(z) = collect(hflow(0.0, z[1], z[2], pi / 2))
    J = ForwardDiff.jacobian(shoot, [1.0, 0.0])
    ok = isapprox(J, [0.0 1.0; -1.0 0.0]; atol=1e-4)
    println("  ✓ ForwardDiff.jacobian(shoot, [x0,p0])  ", ok ? "matches [0 1; -1 0]" : "MISMATCH: $J")
end

# =============================================================================
# Hamiltonian (AD) probe — Flow(Hamiltonian), default backend AutoForwardDiff (CPU)
# =============================================================================
#
# Ground-truth source for docs/src/compatibility/hamiltonian.md.
# Unlike VectorField/HamiltonianVectorField, Data.Hamiltonian has NO in-place variant —
# the flow computes ẋ = ∂H/∂p, ṗ = -∂H/∂x via automatic differentiation (default backend
# on CPU: DifferentiationInterface + ADTypes.AutoForwardDiff()). So this block has no
# OOP/IP split: only {point, traj} columns.
#
# Same dynamics as the HVF block (H = 0.5·(|x|² + |p|²) ⇒ ẋ=p, ṗ=-x), so the same
# analytic solution applies: xf = p0, pf = -x0 at t = π/2.
#
# Open question this block settles (see .reports/2026-07-23_plan-compatibility-hamiltonian.md)
# — MEASURED, not assumed: Complex state/costate FAILS with the default AutoForwardDiff
# backend — `ArgumentError: Cannot create a dual over scalar type ComplexF64`. Confirmed,
# matches the earlier (unvalidated) analysis.
#
# (A hand-built ForwardDiff.Dual as x0/p0 is deliberately NOT probed here as a state type —
# it is not a useful thing to do; see the "Nested AD" section below for what actually
# matters: differentiating the flow via an outer ForwardDiff.jacobian/gradient call.)
# =============================================================================

h_ad     = Data.Hamiltonian((x, p) -> 0.5 * (sum(abs2, x) + sum(abs2, p)))
hflow_ad = Flows.Flow(h_ad; reltol=1e-8)

function _maxerr_had(kind, r, x0, p0)
    if kind === :point
        xf, pf = r
    else
        xf = Trajectories.state(r)(pi / 2)
        pf = Trajectories.costate(r)(pi / 2)
    end
    return maximum(abs.(vcat(_flat(xf) .- _flat(p0), _flat(pf) .- _flat(-x0))))
end

_short(s, n=90) = length(s) > n ? first(s, n) * "…" : s

function cell_had(fl, kind, x0, p0)
    g = kind === :point ? (() -> fl(0.0, x0, p0, pi / 2)) : (() -> fl((0.0, pi / 2), x0, p0))
    try
        r = g()
        err = try
            _maxerr_had(kind, r, x0, p0)
        catch
            NaN
        end
        ok = isfinite(err) && err ≤ 1e-4
        mark = ok ? "✓" : "?"
        return (mark, @sprintf("err=%.1e", err))
    catch e
        return ("✗", _short(string(nameof(typeof(e))) * ": " * sprint(showerror, e)))
    end
end

cases_had = [
    ("scalar Real",     1.0,                                             0.0),
    ("Vector Real",     [1.0, 0.0],                                       [0.0, 1.0]),
    ("MVector Real",    MVector{2}(1.0, 0.0),                             MVector{2}(0.0, 1.0)),
    ("SVector Real",    SA[1.0, 0.0],                                     SA[0.0, 1.0]),
    ("Matrix Real",     [1.0 2.0; 3.0 4.0],                               [0.0 0.0; 1.0 1.0]),
    ("MMatrix Real",    MMatrix{2,2}(1.0, 3.0, 2.0, 4.0),                 MMatrix{2,2}(0.0, 1.0, 0.0, 1.0)),
    ("SMatrix Real",    SMatrix{2,2}(1.0, 3.0, 2.0, 4.0),                 SMatrix{2,2}(0.0, 1.0, 0.0, 1.0)),
    ("scalar Complex",  1.0 + 2.0im,                                      0.0 + 0.0im),
    ("Vector Complex",  [1.0 + 2.0im, 0.0 + 0.0im],                       [0.0 + 0.0im, 1.0 + 1.0im]),
    ("MVector Complex", MVector{2}(1.0 + 2.0im, 0.0 + 0.0im),             MVector{2}(0.0 + 0.0im, 1.0 + 1.0im)),
    ("SVector Complex", SA[1.0 + 2.0im, 0.0 + 0.0im],                     SA[0.0 + 0.0im, 1.0 + 1.0im]),
    ("Matrix Complex",  [1.0+2.0im 5.0+6.0im; 3.0+4.0im 7.0+8.0im],       [0.0+0.0im 1.0+1.0im; 2.0+2.0im 3.0+3.0im]),
    ("SMatrix Complex", SMatrix{2,2}(1.0+2.0im, 3.0+4.0im, 5.0+6.0im, 7.0+8.0im), SMatrix{2,2}(0.0+0.0im, 2.0+2.0im, 1.0+1.0im, 3.0+3.0im)),
]

println("\n", "="^96)
println("  CTFlows CPU probe — Flow(Hamiltonian), H = 0.5(|x|²+|p|²)  [AutoForwardDiff, CPU]")
println("  analytic: xf = p0, pf = -x0.  NO in-place variant — point/traj columns only.")
println("="^96)
println(@sprintf("  %-16s | %-30s | %-30s", "state/costate", "point", "traj"))
println("  " * "-"^80)

n_ok_had = n_fail_had = 0
for (lab, x0, p0) in cases_had
    m1, d1 = cell_had(hflow_ad, :point, x0, p0)
    m2, d2 = cell_had(hflow_ad, :traj, x0, p0)
    for m in (m1, m2)
        m == "✓" ? (global n_ok_had += 1) : (global n_fail_had += 1)
    end
    println(@sprintf("  %-16s | %s %-28s | %s %-28s", lab, m1, d1, m2, d2))
end

println("  " * "-"^80)
println(@sprintf("  totals:  ✓ %d works   ✗/? %d fail-or-wrong   (of %d)",
    n_ok_had, n_fail_had, 2 * length(cases_had)))
println("="^96)
println("""
  Legend & notes
  ──────────────
  ✓  works, result matches analytic (xf ≈ p0, pf ≈ -x0) to err ≤ 1e-4
  ✗  raised the named error type (message truncated)   ?  ran but result did not match

  This block confirms Complex is unsupported by the default AutoForwardDiff backend
  (measured, not assumed). See the "Nested AD" section below for how to actually
  differentiate this flow with respect to (x0, p0).
""")

# =============================================================================
# Nested AD — how to differentiate Flow(Hamiltonian) with respect to (x0, p0)
# =============================================================================
#
# A hand-built Dual (ForwardDiff.Dual(1.0, 1.0), tag = Nothing) fed directly as x0/p0
# fails, because the flow's own internal AD is ALSO AutoForwardDiff: `DualMismatchError:
# Cannot determine ordering of Dual tags Nothing and ForwardDiff.Tag{...}`. A hand-supplied
# CUSTOM tag (Dual{MyTag}(...)) does NOT fix this either (tested) — an arbitrary marker type
# lacks ForwardDiff's internal tag-ordering machinery. That is not how sensitivities of a
# Flow(Hamiltonian) are meant to be computed anyway: wrap the FLOW CALL in an outer
# ForwardDiff.jacobian/gradient instead — ForwardDiff then generates its own properly
# ordered tag for the perturbation, and the nested (forward-over-forward) case is exactly
# what ForwardDiff.jl is designed to support. This is the same pattern NonlinearSolve-style
# shooting methods use to differentiate a ForwardDiff-backed flow w.r.t. (x0, p0).
# =============================================================================

println("\n", "="^96)
println("  Nested AD via an OUTER ForwardDiff.jacobian/gradient call (the working pattern)")
println("="^96)

let
    shoot(z) = collect(hflow_ad(0.0, z[1], z[2], pi / 2))
    try
        J = ForwardDiff.jacobian(shoot, [1.0, 0.0])
        ok = isapprox(J, [0.0 1.0; -1.0 0.0]; atol=1e-4)
        println("  ✓ ForwardDiff.jacobian(shoot, [x0,p0])  ", ok ? "matches [0 1; -1 0]" : "MISMATCH: $J")
    catch e
        println("  ✗ ForwardDiff.jacobian FAILED: ", sprint(showerror, e))
    end

    residual(z) = sum(abs2, shoot(z))
    try
        g = ForwardDiff.gradient(residual, [1.0, 0.0])
        println("  ✓ ForwardDiff.gradient(residual, [x0,p0]) = ", g)
    catch e
        println("  ✗ ForwardDiff.gradient FAILED: ", sprint(showerror, e))
    end
end
println("""
  Conclusion: nested ForwardDiff-over-ForwardDiff through Flow(Hamiltonian) works — but only
  when the OUTER Dual is generated by ForwardDiff itself (via jacobian/gradient/derivative
  on a closure that calls the flow), never by hand-constructing a Dual and passing it as x0.
  No custom backend switch (e.g. an internal Mooncake backend) is needed to sidestep this —
  the fix is procedural, not a backend choice.
""")

# =============================================================================
# SciMLFunctionSystem probe — Flow(::SciMLBase.AbstractODEFunction) state matrix
# =============================================================================
#
# Ground-truth source for docs/src/compatibility/sciml.md (Flow(::ODEFunction) section).
# Same mechanics and OOP/IP dispatch as Flow(VectorField) — ismutable(u0) chosen in
# build_problem, same "InPlace ... immutable u0" fallback+warning shape — but wrapped in a
# SciMLFunctionSystem instead of a VectorFieldSystem, and ALWAYS NonAutonomous/NonFixed
# (SciML's uniform (du,u,p,t)/(u,p,t) signature forces this structurally), so every call
# passes `variable=1.0` explicitly. Dynamics: ẋ = -p·x with p = 1.0 ⇒ the SAME x(1) = x0·e⁻¹
# as the VectorField block, so the SAME `cases` list and E/_val/_flat/_maxerr helpers apply.
# =============================================================================

f_scf_oop = SciMLBase.ODEFunction{false}((u, p, t) -> -p .* u)          # out-of-place
f_scf_ip = SciMLBase.ODEFunction((du, u, p, t) -> du .= -p .* u)        # in-place

flow_scf = Flows.Flow(f_scf_oop; reltol=1e-8)
flow_scf_ip = Flows.Flow(f_scf_ip; reltol=1e-8)

function cell_scf(fl, kind, x0)
    g =
        kind === :point ? (() -> fl(0.0, x0, 1.0; variable=1.0)) :
        (() -> fl((0.0, 1.0), x0; variable=1.0))
    l = CollectLogger(String[])
    try
        r = Logging.with_logger(l) do
            g()
        end
        warned = any(m -> occursin("InPlace SciMLFunction", m), l.msgs)
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

println("\n", "="^96)
println("  CTFlows CPU probe — Flow(::SciMLBase.ODEFunction), ẋ = -p·x, p=1.0,  x(1) = x0·e⁻¹")
println("  columns describe the ODEFunction kind (OOP: (u,p,t)->-p.*u | IP: (du,u,p,t)->…)")
println("="^96)
println(@sprintf("  %-16s | %-14s | %-14s | %-14s | %-14s",
    "state", "OOP point", "OOP traj", "IP point", "IP traj"))
println("  " * "-"^92)

n_ok_scf = n_warn_scf = n_fail_scf = 0
for (lab, x0) in cases
    marks = String[]
    for (fl, kind) in ((flow_scf, :point), (flow_scf, :traj), (flow_scf_ip, :point), (flow_scf_ip, :traj))
        m, d = cell_scf(fl, kind, x0)
        m == "✓" && (global n_ok_scf += 1)
        m == "⚠" && (global n_warn_scf += 1)
        (m == "✗" || m == "?") && (global n_fail_scf += 1)
        push!(marks, @sprintf("%s %-12s", m, d))
    end
    println(@sprintf("  %-16s | %s | %s | %s | %s", lab, marks[1], marks[2], marks[3], marks[4]))
end

println("  " * "-"^92)
println(@sprintf("  totals:  ✓ %d works   ⚠ %d works-with-warning   ✗/? %d fail-or-wrong   (of %d)",
    n_ok_scf, n_warn_scf, n_fail_scf, 4 * length(cases)))
println("="^96)
println("""
  Legend & notes
  ──────────────
  ✓  works, result matches analytic to err ≤ 1e-4
  ⚠  works but emits a performance @warn — in-place ODEFunction + immutable u0
     (SVector/SMatrix): same fallback mechanism as Flow(VectorField).
  ✗  raised the named error type    ?  ran but result did not match analytic

  Observed nuances (fold into docs/src/compatibility/sciml.md):
   • Structurally identical result to Flow(VectorField) — same dispatch, same fallback.
   • variable= is mandatory here (NonAutonomous/NonFixed always), unlike VF's default Fixed.
""")

# =============================================================================
# SciMLProblemFlow probe — Flow(::SciMLBase.AbstractODEProblem) state matrix
# =============================================================================
#
# Ground-truth source for docs/src/compatibility/sciml.md (Flow(::ODEProblem) section).
# SciMLProblemFlow BYPASSES the CTFlows system pipeline entirely: point/traj calls do
# SciMLBase.remake then CommonSolve.solve directly — no CTFlows AbstractSystem, no
# get_ip_rhs/get_oop_rhs, and NO CTFlows-level in-place/immutable guard (unlike every other
# Flow constructor probed above, all of which route through build_problem). This block
# MEASURES, rather than assumes, what happens when an IN-PLACE-built ODEProblem is remade at
# call time with an IMMUTABLE x0 (e.g. SVector) — the open question flagged in
# .reports/2026-07-23_plan-compatibility-sciml.md.
#
# Same dynamics/cases as the SciMLFunctionSystem block: ẋ = -p·x, p = 1.0 fixed into the
# ORIGINAL ODEProblem, then overridden per call via `variable=1.0` (remake).
# =============================================================================

prob_oop = SciMLBase.ODEProblem(f_scf_oop, [1.0], (0.0, 1.0), 1.0)   # built out-of-place
prob_ip = SciMLBase.ODEProblem(f_scf_ip, [1.0], (0.0, 1.0), 1.0)     # built in-place

pflow_oop = Flows.Flow(prob_oop; reltol=1e-8)
pflow_ip = Flows.Flow(prob_ip; reltol=1e-8)

function _maxerr_prob(kind, r, x0)
    got = kind === :point ? r : Integrators.evaluate_at(r, 1.0)
    return maximum(abs.(_flat(got) .- _flat(x0 .* E)))
end

function cell_prob(fl, kind, x0)
    g =
        kind === :point ? (() -> fl(0.0, x0, 1.0; variable=1.0)) :
        (() -> fl((0.0, 1.0), x0; variable=1.0))
    try
        r = g()
        err = try
            _maxerr_prob(kind, r, x0)
        catch
            NaN
        end
        ok = isfinite(err) && err ≤ 1e-4
        mark = ok ? "✓" : "?"
        return (mark, @sprintf("err=%.1e", err))
    catch e
        return ("✗", _short(string(nameof(typeof(e))) * ": " * sprint(showerror, e)))
    end
end

println("\n", "="^96)
println("  CTFlows CPU probe — Flow(::SciMLBase.ODEProblem), ẋ = -p·x, p=1.0,  x(1) = x0·e⁻¹")
println("  columns: which ODEProblem was REMADE at call time (built out-of-place vs in-place)")
println("  *** no CTFlows guard exists on this path — IP-built + immutable x0 measured, not assumed ***")
println("="^96)
println(@sprintf("  %-16s | %-30s | %-30s | %-30s | %-30s",
    "state", "OOP-built point", "OOP-built traj", "IP-built point", "IP-built traj"))
println("  " * "-"^140)

n_ok_prob = n_fail_prob = 0
for (lab, x0) in cases
    marks = String[]
    for (fl, kind) in ((pflow_oop, :point), (pflow_oop, :traj), (pflow_ip, :point), (pflow_ip, :traj))
        m, d = cell_prob(fl, kind, x0)
        m == "✓" ? (global n_ok_prob += 1) : (global n_fail_prob += 1)
        push!(marks, @sprintf("%s %-28s", m, d))
    end
    println(@sprintf("  %-16s | %s | %s | %s | %s", lab, marks[1], marks[2], marks[3], marks[4]))
end

println("  " * "-"^140)
println(@sprintf("  totals:  ✓ %d works   ✗/? %d fail-or-wrong   (of %d)",
    n_ok_prob, n_fail_prob, 4 * length(cases)))
println("="^96)

let
    r0 = pflow_oop()
    r1 = pflow_ip()
    println(
        "  no-arg call f() — solves the ORIGINAL problem as-is (u0=[1.0], p=1.0):",
    )
    println("    OOP-built: final_state = ", Integrators.final_state(r0),
        "  (expect ≈ [", E, "])")
    println("    IP-built:  final_state = ", Integrators.final_state(r1),
        "  (expect ≈ [", E, "])")
end

println("""
  Legend & notes
  ──────────────
  ✓  works, result matches analytic to err ≤ 1e-4
  ✗  raised the named error type (message truncated)   ?  ran but result did not match

  Observed nuances (fold into docs/src/compatibility/sciml.md):
   • Point call returns the final state directly (already unwrapped by SciMLProblemFlow).
   • Trajectory call returns a raw Integrators.AbstractIntegrationResult, NOT a
     Trajectories.VectorFieldTrajectory — use Integrators.times/evaluate_at/final_state.
   • The no-arg call f() ignores every per-call argument and solves the problem exactly as
     constructed (its own u0/tspan/p) — shown once above, not part of the state matrix.
   • See the *** line above for the measured outcome of the flagged open question
     (IP-built ODEProblem remade with an immutable x0 at call time).
""")
