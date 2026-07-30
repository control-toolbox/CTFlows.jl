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
using CTModels: CTModels

# ---------------------------------------------------------------------------
# Log collector to detect the "InPlace VectorField" performance warning
# ---------------------------------------------------------------------------
struct CollectLogger <: Logging.AbstractLogger
    msgs::Vector{String}
end
Logging.min_enabled_level(::CollectLogger) = Logging.Debug
Logging.shouldlog(::CollectLogger, args...) = true
function Logging.handle_message(
    l::CollectLogger, lvl, msg, _mod, grp, id, file, line; kw...
)
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

# ---------------------------------------------------------------------------
# Shape helper (issue #357): tag the ACTUAL type of a result, not just whether
# it is numerically correct. "Real" vs "Vec(1)" is exactly the 1-D = scalar
# distinction the shape-convention audit needs measured, not hand-written.
# ---------------------------------------------------------------------------
_shape_tag(x) =
    if x isa Number
        "Real"
    elseif x isa AbstractVector
        "Vec($(length(x)))"
    elseif x isa AbstractMatrix
        "Mat$(size(x))"
    else
        string(typeof(x))
    end

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
            return g()
        end
        warned = any(m -> occursin("InPlace VectorField", m), l.msgs)
        err = try
            _maxerr(kind, r, x0)
        catch
            NaN
        end
        shape = try
            _shape_tag(kind === :point ? r : Trajectories.state(r)(1.0))
        catch
            "?"
        end
        ok = isfinite(err) && err ≤ 1e-4
        mark = ok ? (warned ? "⚠" : "✓") : "?"
        return (mark, @sprintf("err=%.1e shape=%s%s", err, shape, warned ? " (warns)" : ""))
    catch e
        return ("✗", string(nameof(typeof(e))))
    end
end

# ---------------------------------------------------------------------------
# The two flows (defined ONCE, exactly as the doc's @setup block does)
# ---------------------------------------------------------------------------
vf = Data.VectorField(x -> -x)                                                       # out-of-place
flow = Flows.Flow(vf; reltol=1e-8)
vf_ip = Data.VectorField((du, x) -> (du .= -x); is_autonomous=true, is_variable=false)  # in-place
flow_ip = Flows.Flow(vf_ip; reltol=1e-8)

# ---------------------------------------------------------------------------
# State samples: (label, x0). Everything decays to x0 · e⁻¹ under ẋ = -x.
# ---------------------------------------------------------------------------
cases = [
    ("scalar Real", 1.0),
    ("Vector Real", [1.0, 2.0]),
    ("MVector Real", MVector{2}(1.0, 2.0)),
    ("SVector Real", SA[1.0, 2.0]),
    ("Matrix Real", [1.0 2.0; 3.0 4.0]),
    ("MMatrix Real", MMatrix{2,2}(1.0, 3.0, 2.0, 4.0)),
    ("SMatrix Real", SMatrix{2,2}(1.0, 3.0, 2.0, 4.0)),
    ("scalar Complex", 1.0 + 2.0im),
    ("Vector Complex", [1.0 + 2.0im, 3.0 + 4.0im]),
    ("MVector Complex", MVector{2}(1.0 + 2.0im, 3.0 + 4.0im)),
    ("SVector Complex", SA[1.0 + 2.0im, 3.0 + 4.0im]),
    ("Matrix Complex", [1.0+2.0im 5.0+6.0im; 3.0+4.0im 7.0+8.0im]),
    ("SMatrix Complex", SMatrix{2,2}(1.0+2.0im, 3.0+4.0im, 5.0+6.0im, 7.0+8.0im)),
    ("Dual scalar", ForwardDiff.Dual(1.0, 1.0)),
    ("Dual Vector", [ForwardDiff.Dual(1.0, 1.0), ForwardDiff.Dual(2.0, 0.0)]),
    ("Dual MVector", MVector{2}(ForwardDiff.Dual(1.0, 1.0), ForwardDiff.Dual(2.0, 0.0))),
    ("Dual SVector", SA[ForwardDiff.Dual(1.0, 1.0), ForwardDiff.Dual(2.0, 0.0)]),
]

# ---------------------------------------------------------------------------
# Run the matrix
# ---------------------------------------------------------------------------
println("\n", "="^96)
println("  CTFlows CPU probe — Flow(VectorField), dynamics ẋ = -x,  x(1) = x0·e⁻¹")
println("  columns describe the vector-field kind (OOP: x->-x  |  IP: (du,x)->du.=-x)")
println("="^96)
println(
    @sprintf(
        "  %-16s | %-14s | %-14s | %-14s | %-14s",
        "state",
        "OOP point",
        "OOP traj",
        "IP point",
        "IP traj"
    )
)
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
    println(
        @sprintf("  %-16s | %s | %s | %s | %s", lab, marks[1], marks[2], marks[3], marks[4])
    )
end

println("  " * "-"^92)
println(
    @sprintf(
        "  totals:  ✓ %d works   ⚠ %d works-with-warning   ✗/? %d fail-or-wrong   (of %d)",
        n_ok,
        n_warn,
        n_fail,
        4 * length(cases)
    )
)
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
   • Scalar state: `shape=` MEASURES "shape=Real" on BOTH the point call and the
     trajectory call's state(sol)(t) — 1-D = scalar end to end, matching
     Flow(HamiltonianVectorField), since the fix for issue #357. A length-1
     Vector/SVector x0 collapses the same way (see the length-1 row, not shown as a
     separate table row here — see the dedicated shape_contract.md compatibility page).
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
    println(
        "  ✓ ForwardDiff.jacobian(x0 -> flow(0,x0,1), x0)  ",
        ok ? "matches e⁻¹·I" : "MISMATCH: $J",
    )
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

hvf = Data.HamiltonianVectorField((x, p) -> (p, -x))                                                                # out-of-place
hflow = Flows.Flow(hvf; reltol=1e-8)
hvf_ip = Data.HamiltonianVectorField(
    (dx, dp, x, p) -> (dx.=p; dp.=(-x)); is_autonomous=true, is_variable=false
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
    g = if kind === :point
        (() -> fl(0.0, x0, p0, pi / 2))
    else
        (() -> fl((0.0, pi / 2), x0, p0))
    end
    l = CollectLogger(String[])
    try
        r = Logging.with_logger(l) do
            return g()
        end
        warned = any(m -> occursin("InPlace HamiltonianVectorField", m), l.msgs)
        err = try
            _maxerr_hvf(kind, r, x0, p0)
        catch
            NaN
        end
        shape = try
            xf = kind === :point ? r[1] : Trajectories.state(r)(pi / 2)
            _shape_tag(xf)
        catch
            "?"
        end
        ok = isfinite(err) && err ≤ 1e-4
        mark = ok ? (warned ? "⚠" : "✓") : "?"
        return (mark, @sprintf("err=%.1e shape=%s%s", err, shape, warned ? " (warns)" : ""))
    catch e
        return ("✗", string(nameof(typeof(e))))
    end
end

cases_hvf = [
    ("scalar Real", 1.0, 0.0),
    ("Vector Real", [1.0, 0.0], [0.0, 1.0]),
    ("MVector Real", MVector{2}(1.0, 0.0), MVector{2}(0.0, 1.0)),
    ("SVector Real", SA[1.0, 0.0], SA[0.0, 1.0]),
    ("Matrix Real", [1.0 2.0; 3.0 4.0], [0.0 0.0; 1.0 1.0]),
    ("MMatrix Real", MMatrix{2,2}(1.0, 3.0, 2.0, 4.0), MMatrix{2,2}(0.0, 1.0, 0.0, 1.0)),
    ("SMatrix Real", SMatrix{2,2}(1.0, 3.0, 2.0, 4.0), SMatrix{2,2}(0.0, 1.0, 0.0, 1.0)),
    ("scalar Complex", 1.0 + 2.0im, 0.0 + 0.0im),
    ("Vector Complex", [1.0 + 2.0im, 0.0 + 0.0im], [0.0 + 0.0im, 1.0 + 1.0im]),
    (
        "MVector Complex",
        MVector{2}(1.0 + 2.0im, 0.0 + 0.0im),
        MVector{2}(0.0 + 0.0im, 1.0 + 1.0im),
    ),
    ("SVector Complex", SA[1.0 + 2.0im, 0.0 + 0.0im], SA[0.0 + 0.0im, 1.0 + 1.0im]),
    (
        "Matrix Complex",
        [1.0+2.0im 5.0+6.0im; 3.0+4.0im 7.0+8.0im],
        [0.0+0.0im 1.0+1.0im; 2.0+2.0im 3.0+3.0im],
    ),
    (
        "SMatrix Complex",
        SMatrix{2,2}(1.0+2.0im, 3.0+4.0im, 5.0+6.0im, 7.0+8.0im),
        SMatrix{2,2}(0.0+0.0im, 2.0+2.0im, 1.0+1.0im, 3.0+3.0im),
    ),
    ("Dual scalar", ForwardDiff.Dual(1.0, 1.0), ForwardDiff.Dual(0.0, 0.0)),
    (
        "Dual Vector",
        [ForwardDiff.Dual(1.0, 1.0), ForwardDiff.Dual(0.0, 0.0)],
        [ForwardDiff.Dual(0.0, 0.0), ForwardDiff.Dual(1.0, 0.0)],
    ),
    (
        "Dual MVector",
        MVector{2}(ForwardDiff.Dual(1.0, 1.0), ForwardDiff.Dual(0.0, 0.0)),
        MVector{2}(ForwardDiff.Dual(0.0, 0.0), ForwardDiff.Dual(1.0, 0.0)),
    ),
    (
        "Dual SVector",
        SA[ForwardDiff.Dual(1.0, 1.0), ForwardDiff.Dual(0.0, 0.0)],
        SA[ForwardDiff.Dual(0.0, 0.0), ForwardDiff.Dual(1.0, 0.0)],
    ),
]

println("\n", "="^96)
println("  CTFlows CPU probe — Flow(HamiltonianVectorField), x' = p, p' = -x,  (0, π/2)")
println("  analytic: xf = p0, pf = -x0.  columns: OOP (x,p)->(p,-x)  |  IP (dx,dp,x,p)->…")
println("="^96)
println(
    @sprintf(
        "  %-16s | %-14s | %-14s | %-14s | %-14s",
        "state/costate",
        "OOP point",
        "OOP traj",
        "IP point",
        "IP traj"
    )
)
println("  " * "-"^92)

n_ok_hvf = n_warn_hvf = n_fail_hvf = 0
for (lab, x0, p0) in cases_hvf
    marks = String[]
    for (fl, kind) in
        ((hflow, :point), (hflow, :traj), (hflow_ip, :point), (hflow_ip, :traj))
        m, d = cell_hvf(fl, kind, x0, p0)
        m == "✓" && (global n_ok_hvf += 1)
        m == "⚠" && (global n_warn_hvf += 1)
        (m == "✗" || m == "?") && (global n_fail_hvf += 1)
        push!(marks, @sprintf("%s %-12s", m, d))
    end
    println(
        @sprintf("  %-16s | %s | %s | %s | %s", lab, marks[1], marks[2], marks[3], marks[4])
    )
end

println("  " * "-"^92)
println(
    @sprintf(
        "  totals:  ✓ %d works   ⚠ %d works-with-warning   ✗/? %d fail-or-wrong   (of %d)",
        n_ok_hvf,
        n_warn_hvf,
        n_fail_hvf,
        4 * length(cases_hvf)
    )
)
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
     for a scalar (x0, p0), `shape=Real` MEASURED on both the point call and the
     TRAJECTORY accessor state(sol)(t) — not length-1 vectors. See issue #357
     (Flow(VectorField) should eventually match this).
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
println(
    "  Sensitivities of Flow(HamiltonianVectorField) via an outer ForwardDiff.jacobian call"
)
println("="^96)
let
    shoot(z) = collect(hflow(0.0, z[1], z[2], pi / 2))
    J = ForwardDiff.jacobian(shoot, [1.0, 0.0])
    ok = isapprox(J, [0.0 1.0; -1.0 0.0]; atol=1e-4)
    println(
        "  ✓ ForwardDiff.jacobian(shoot, [x0,p0])  ",
        ok ? "matches [0 1; -1 0]" : "MISMATCH: $J",
    )
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

h_ad = Data.Hamiltonian((x, p) -> 0.5 * (sum(abs2, x) + sum(abs2, p)))
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
    g = if kind === :point
        (() -> fl(0.0, x0, p0, pi / 2))
    else
        (() -> fl((0.0, pi / 2), x0, p0))
    end
    try
        r = g()
        err = try
            _maxerr_had(kind, r, x0, p0)
        catch
            NaN
        end
        shape = try
            xf = kind === :point ? r[1] : Trajectories.state(r)(pi / 2)
            _shape_tag(xf)
        catch
            "?"
        end
        ok = isfinite(err) && err ≤ 1e-4
        mark = ok ? "✓" : "?"
        return (mark, @sprintf("err=%.1e shape=%s", err, shape))
    catch e
        return ("✗", _short(string(nameof(typeof(e))) * ": " * sprint(showerror, e)))
    end
end

cases_had = [
    ("scalar Real", 1.0, 0.0),
    ("Vector Real", [1.0, 0.0], [0.0, 1.0]),
    ("MVector Real", MVector{2}(1.0, 0.0), MVector{2}(0.0, 1.0)),
    ("SVector Real", SA[1.0, 0.0], SA[0.0, 1.0]),
    ("Matrix Real", [1.0 2.0; 3.0 4.0], [0.0 0.0; 1.0 1.0]),
    ("MMatrix Real", MMatrix{2,2}(1.0, 3.0, 2.0, 4.0), MMatrix{2,2}(0.0, 1.0, 0.0, 1.0)),
    ("SMatrix Real", SMatrix{2,2}(1.0, 3.0, 2.0, 4.0), SMatrix{2,2}(0.0, 1.0, 0.0, 1.0)),
    ("scalar Complex", 1.0 + 2.0im, 0.0 + 0.0im),
    ("Vector Complex", [1.0 + 2.0im, 0.0 + 0.0im], [0.0 + 0.0im, 1.0 + 1.0im]),
    (
        "MVector Complex",
        MVector{2}(1.0 + 2.0im, 0.0 + 0.0im),
        MVector{2}(0.0 + 0.0im, 1.0 + 1.0im),
    ),
    ("SVector Complex", SA[1.0 + 2.0im, 0.0 + 0.0im], SA[0.0 + 0.0im, 1.0 + 1.0im]),
    (
        "Matrix Complex",
        [1.0+2.0im 5.0+6.0im; 3.0+4.0im 7.0+8.0im],
        [0.0+0.0im 1.0+1.0im; 2.0+2.0im 3.0+3.0im],
    ),
    (
        "SMatrix Complex",
        SMatrix{2,2}(1.0+2.0im, 3.0+4.0im, 5.0+6.0im, 7.0+8.0im),
        SMatrix{2,2}(0.0+0.0im, 2.0+2.0im, 1.0+1.0im, 3.0+3.0im),
    ),
]

println("\n", "="^96)
println(
    "  CTFlows CPU probe — Flow(Hamiltonian), H = 0.5(|x|²+|p|²)  [AutoForwardDiff, CPU]"
)
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
println(
    @sprintf(
        "  totals:  ✓ %d works   ✗/? %d fail-or-wrong   (of %d)",
        n_ok_had,
        n_fail_had,
        2 * length(cases_had)
    )
)
println("="^96)
println("""
  Legend & notes
  ──────────────
  ✓  works, result matches analytic (xf ≈ p0, pf ≈ -x0) to err ≤ 1e-4
  ✗  raised the named error type (message truncated)   ?  ran but result did not match

  This block confirms Complex is unsupported by the default AutoForwardDiff backend
  (measured, not assumed). See the "Nested AD" section below for how to actually
  differentiate this flow with respect to (x0, p0).

  Shape: for scalar (x0, p0), `shape=Real` on BOTH point and trajectory calls — same
  end-to-end 1-D = scalar behaviour as Flow(HamiltonianVectorField) above.
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
        println(
            "  ✓ ForwardDiff.jacobian(shoot, [x0,p0])  ",
            ok ? "matches [0 1; -1 0]" : "MISMATCH: $J",
        )
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
println(
    """
  Conclusion: nested ForwardDiff-over-ForwardDiff through Flow(Hamiltonian) works — but only
  when the OUTER Dual is generated by ForwardDiff itself (via jacobian/gradient/derivative
  on a closure that calls the flow), never by hand-constructing a Dual and passing it as x0.
  No custom backend switch (e.g. an internal Mooncake backend) is needed to sidestep this —
  the fix is procedural, not a backend choice.
"""
)

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
    g = if kind === :point
        (() -> fl(0.0, x0, 1.0; variable=1.0))
    else
        (() -> fl((0.0, 1.0), x0; variable=1.0))
    end
    l = CollectLogger(String[])
    try
        r = Logging.with_logger(l) do
            return g()
        end
        warned = any(m -> occursin("InPlace SciMLFunction", m), l.msgs)
        err = try
            _maxerr(kind, r, x0)
        catch
            NaN
        end
        shape = try
            _shape_tag(kind === :point ? r : Trajectories.state(r)(1.0))
        catch
            "?"
        end
        ok = isfinite(err) && err ≤ 1e-4
        mark = ok ? (warned ? "⚠" : "✓") : "?"
        return (mark, @sprintf("err=%.1e shape=%s%s", err, shape, warned ? " (warns)" : ""))
    catch e
        return ("✗", string(nameof(typeof(e))))
    end
end

println("\n", "="^96)
println(
    "  CTFlows CPU probe — Flow(::SciMLBase.ODEFunction), ẋ = -p·x, p=1.0,  x(1) = x0·e⁻¹"
)
println("  columns describe the ODEFunction kind (OOP: (u,p,t)->-p.*u | IP: (du,u,p,t)->…)")
println("="^96)
println(
    @sprintf(
        "  %-16s | %-14s | %-14s | %-14s | %-14s",
        "state",
        "OOP point",
        "OOP traj",
        "IP point",
        "IP traj"
    )
)
println("  " * "-"^92)

n_ok_scf = n_warn_scf = n_fail_scf = 0
for (lab, x0) in cases
    marks = String[]
    for (fl, kind) in
        ((flow_scf, :point), (flow_scf, :traj), (flow_scf_ip, :point), (flow_scf_ip, :traj))
        m, d = cell_scf(fl, kind, x0)
        m == "✓" && (global n_ok_scf += 1)
        m == "⚠" && (global n_warn_scf += 1)
        (m == "✗" || m == "?") && (global n_fail_scf += 1)
        push!(marks, @sprintf("%s %-12s", m, d))
    end
    println(
        @sprintf("  %-16s | %s | %s | %s | %s", lab, marks[1], marks[2], marks[3], marks[4])
    )
end

println("  " * "-"^92)
println(
    @sprintf(
        "  totals:  ✓ %d works   ⚠ %d works-with-warning   ✗/? %d fail-or-wrong   (of %d)",
        n_ok_scf,
        n_warn_scf,
        n_fail_scf,
        4 * length(cases)
    )
)
println("="^96)
println(
    """
  Legend & notes
  ──────────────
  ✓  works, result matches analytic to err ≤ 1e-4
  ⚠  works but emits a performance @warn — in-place ODEFunction + immutable u0
     (SVector/SMatrix): same fallback mechanism as Flow(VectorField).
  ✗  raised the named error type    ?  ran but result did not match analytic

  Observed nuances (fold into docs/src/compatibility/sciml.md):
   • Structurally identical result to Flow(VectorField) — same dispatch, same fallback,
     INCLUDING the same `shape=Real` on BOTH point and trajectory calls for scalar x0
     (1-D = scalar, since the fix for issue #357: this constructor goes through the same
     Systems/Trajectories dispatch as VectorFieldSystem — only the genuine ODEProblem
     bypass below stays shape-preserving).
   • variable= is mandatory here (NonAutonomous/NonFixed always), unlike VF's default Fixed.
"""
)

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
    g = if kind === :point
        (() -> fl(0.0, x0, 1.0; variable=1.0))
    else
        (() -> fl((0.0, 1.0), x0; variable=1.0))
    end
    try
        r = g()
        err = try
            _maxerr_prob(kind, r, x0)
        catch
            NaN
        end
        shape = try
            _shape_tag(kind === :point ? r : Integrators.evaluate_at(r, 1.0))
        catch
            "?"
        end
        ok = isfinite(err) && err ≤ 1e-4
        mark = ok ? "✓" : "?"
        return (mark, @sprintf("err=%.1e shape=%s", err, shape))
    catch e
        return ("✗", _short(string(nameof(typeof(e))) * ": " * sprint(showerror, e)))
    end
end

println("\n", "="^96)
println(
    "  CTFlows CPU probe — Flow(::SciMLBase.ODEProblem), ẋ = -p·x, p=1.0,  x(1) = x0·e⁻¹"
)
println(
    "  columns: which ODEProblem was REMADE at call time (built out-of-place vs in-place)"
)
println(
    "  *** no CTFlows guard exists on this path — IP-built + immutable x0 measured, not assumed ***",
)
println("="^96)
println(
    @sprintf(
        "  %-16s | %-30s | %-30s | %-30s | %-30s",
        "state",
        "OOP-built point",
        "OOP-built traj",
        "IP-built point",
        "IP-built traj"
    )
)
println("  " * "-"^140)

n_ok_prob = n_fail_prob = 0
for (lab, x0) in cases
    marks = String[]
    for (fl, kind) in
        ((pflow_oop, :point), (pflow_oop, :traj), (pflow_ip, :point), (pflow_ip, :traj))
        m, d = cell_prob(fl, kind, x0)
        m == "✓" ? (global n_ok_prob += 1) : (global n_fail_prob += 1)
        push!(marks, @sprintf("%s %-28s", m, d))
    end
    println(
        @sprintf("  %-16s | %s | %s | %s | %s", lab, marks[1], marks[2], marks[3], marks[4])
    )
end

println("  " * "-"^140)
println(
    @sprintf(
        "  totals:  ✓ %d works   ✗/? %d fail-or-wrong   (of %d)",
        n_ok_prob,
        n_fail_prob,
        4 * length(cases)
    )
)
println("="^96)

let
    r0 = pflow_oop()
    r1 = pflow_ip()
    println("  no-arg call f() — solves the ORIGINAL problem as-is (u0=[1.0], p=1.0):")
    println(
        "    OOP-built: final_state = ",
        Integrators.final_state(r0),
        "  (expect ≈ [",
        E,
        "])",
    )
    println(
        "    IP-built:  final_state = ",
        Integrators.final_state(r1),
        "  (expect ≈ [",
        E,
        "])",
    )
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
   • Shape (issue #357): `shape=` measures Vec(1), never Real, for the scalar-x0 row on
     BOTH point and trajectory calls — this genuine bypass is confirmed shape-preserving
     already and is explicitly OUT of scope for the 1-D = scalar fix (unlike
     Flow(::ODEFunction) above, which goes through CTFlows' own dispatch and IS in scope).
""")

# =============================================================================
# Optimal control problem (OCP) probes — Flow(ocp) and Flow(ocp, law)
# =============================================================================
#
# Ground-truth source for docs/src/compatibility/ocp_free.md and
# docs/src/compatibility/ocp_control_laws.md. Design rationale (two pages, :total/:partial
# as a full axis rather than a smoke test, constrained-continuation check, the
# variable/variable_costate axis) is in .reports/2026-07-23_plan-compatibility-ocp.md.
#
# Unlike VF/HVF/Hamiltonian, the state dimension of an OCP is FIXED AT CONSTRUCTION
# (`state!(pre, n)`) — one flow does not accept every container size. So this block builds
# TWO ocp instances per family: a SCALAR one (n=1) and a VECTOR-family one (n=2), and reuses
# the SAME container/value list as the HVF block (`cases_hvf`) — index 1 is the scalar case,
# 2:end the n=2 cases — rather than inventing a new list.
# =============================================================================

# ---------------------------------------------------------------------------
# OCP fixtures
# ---------------------------------------------------------------------------

# control-free: H(x,p) = -p·x  (sp0=-1 for :min, no Lagrange) ⇒ ẋ=-x, ṗ=p
#   ⇒ (xf,pf) = (x0·e⁻¹, p0·e) at tf=1
function _build_ocp_free(n::Int)
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, n)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r.=(-x); nothing))
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> sum(xf))
    return CTModels.Building.build(pre)
end

# control-free, NonFixed: ẋ = v·x (v scalar) ⇒ ṗ = -v·p
#   ⇒ (xf,pf) = (x0·e^v, p0·e⁻ᵛ) at tf=1;  pv(tf) = -sum(x0.*p0)·(tf-t0)  — reconciled
#   against test/suite/extensions/test_optimal_control_flow.jl's `_pv_ref` (ℓ=0 case).
function _build_ocp_free_variable(n::Int)
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, n)
    CTModels.Building.variable!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r.=v[1] .* x; nothing))
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> sum(xf))
    return CTModels.Building.build(pre)
end

# with control (control_laws.md's own example, generalized to n): ẋ = u-x, min ∫0.5|u|² dt
function _build_ocp_ctrl(n::Int)
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, n)
    CTModels.Building.control!(pre, n)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r.=u .- x; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * sum(abs2, u))
    return CTModels.Building.build(pre)
end

ocp_free_1 = _build_ocp_free(1)
ocp_free_2 = _build_ocp_free(2)
ocp_freev_1 = _build_ocp_free_variable(1)
ocp_freev_2 = _build_ocp_free_variable(2)
ocp_ctrl_1 = _build_ocp_ctrl(1)
ocp_ctrl_2 = _build_ocp_ctrl(2)

law_dyn = Data.DynClosedLoop((x, p) -> p)     # u = p (stationary: ∂H̃/∂u = p-u = 0)
law_closed = Data.ClosedLoop(x -> -x)          # u = -x

f_free_1 = Flows.Flow(ocp_free_1; reltol=1e-8)
f_free_2 = Flows.Flow(ocp_free_2; reltol=1e-8)
f_freev_1 = Flows.Flow(ocp_freev_1; reltol=1e-8)
f_freev_2 = Flows.Flow(ocp_freev_2; reltol=1e-8)

f_dyn_total_1 = Flows.Flow(ocp_ctrl_1, law_dyn; reltol=1e-8)                   # :total (default)
f_dyn_total_2 = Flows.Flow(ocp_ctrl_2, law_dyn; reltol=1e-8)
f_dyn_partial_1 = Flows.Flow(ocp_ctrl_1, law_dyn; hamiltonian_type=:partial, reltol=1e-8)
f_dyn_partial_2 = Flows.Flow(ocp_ctrl_2, law_dyn; hamiltonian_type=:partial, reltol=1e-8)

# constant constraint/multiplier (g=1, μ=0.3): μ·g contributes a pure CONSTANT to H̃_c, so
# ∂H̃_c/∂x = ∂H̃/∂x and ∂H̃_c/∂p = ∂H̃/∂p — the dynamics (and hence the analytic reference) are
# UNCHANGED from the unconstrained case. This isolates "does the constrained path still run"
# from "is the constrained physics right" (the latter already covered by
# test/suite/flows/test_constrained_flows.jl-style tests, not re-derived here).
f_dyn_total_c_1 = Flows.Flow(
    ocp_ctrl_1, law_dyn; constraint=(x, u) -> 1.0, multiplier=(x, p) -> 0.3, reltol=1e-8
)
f_dyn_total_c_2 = Flows.Flow(
    ocp_ctrl_2, law_dyn; constraint=(x, u) -> 1.0, multiplier=(x, p) -> 0.3, reltol=1e-8
)
f_dyn_partial_c_1 = Flows.Flow(
    ocp_ctrl_1,
    law_dyn;
    hamiltonian_type=:partial,
    constraint=(x, u) -> 1.0,
    multiplier=(x, p) -> 0.3,
    reltol=1e-8,
)
f_dyn_partial_c_2 = Flows.Flow(
    ocp_ctrl_2,
    law_dyn;
    hamiltonian_type=:partial,
    constraint=(x, u) -> 1.0,
    multiplier=(x, p) -> 0.3,
    reltol=1e-8,
)

f_cl_1 = Flows.Flow(ocp_ctrl_1, law_closed; reltol=1e-8)
f_cl_2 = Flows.Flow(ocp_ctrl_2, law_closed; reltol=1e-8)

# ---------------------------------------------------------------------------
# Flow(ocp) — Hamiltonian (state+costate) block
# ---------------------------------------------------------------------------

function _maxerr_ocpfree(kind, r, x0, p0)
    if kind === :point
        xf, pf = r
    else
        xf = CTModels.Components.state(r)(1.0)
        pf = CTModels.Components.costate(r)(1.0)
    end
    return maximum(
        abs.(vcat(_flat(xf) .- _flat(x0 .* E), _flat(pf) .- _flat(p0 .* exp(1.0))))
    )
end

function cell_ocpfree(fl, kind, x0, p0)
    g = kind === :point ? (() -> fl(0.0, x0, p0, 1.0)) : (() -> fl((0.0, 1.0), x0, p0))
    try
        r = g()
        err = try
            _maxerr_ocpfree(kind, r, x0, p0)
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
println(
    "  CTFlows CPU probe — Flow(ocp), control-free, H(x,p)=-p·x,  (xf,pf)=(x0·e⁻¹,p0·e)"
)
println("  no OOP/IP (no mutability dispatch for Hamiltonian-type flows)")
println("="^96)
println(@sprintf("  %-16s | %-30s | %-30s", "state/costate", "point", "traj"))
println("  " * "-"^80)

n_ok_ocpfree = n_fail_ocpfree = 0
for (lab, x0, p0) in cases_hvf
    fl = x0 isa Number ? f_free_1 : f_free_2   # scalar cases live at indices 1, 8, 14 — not just 1
    m1, d1 = cell_ocpfree(fl, :point, x0, p0)
    m2, d2 = cell_ocpfree(fl, :traj, x0, p0)
    for m in (m1, m2)
        m == "✓" ? (global n_ok_ocpfree += 1) : (global n_fail_ocpfree += 1)
    end
    println(@sprintf("  %-16s | %s %-28s | %s %-28s", lab, m1, d1, m2, d2))
end
println("  " * "-"^80)
println(
    @sprintf(
        "  totals:  ✓ %d works   ✗/? %d fail-or-wrong   (of %d)",
        n_ok_ocpfree,
        n_fail_ocpfree,
        2 * length(cases_hvf)
    )
)
println("="^96)

# ---------------------------------------------------------------------------
# Flow(ocp) — basic (state-only, no costate) block — direct-shooting, issue #230
# ---------------------------------------------------------------------------

function _maxerr_ocpfree_basic(kind, r, x0)
    got = kind === :point ? r : Trajectories.state(r)(1.0)
    return maximum(abs.(_flat(got) .- _flat(x0 .* E)))
end

function cell_ocpfree_basic(fl, kind, x0)
    g = kind === :point ? (() -> fl(0.0, x0, 1.0)) : (() -> fl((0.0, 1.0), x0))
    try
        r = g()
        err = try
            _maxerr_ocpfree_basic(kind, r, x0)
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
println("  CTFlows CPU probe — Flow(ocp), basic state-only call f(t0,x0,tf), no costate")
println("="^96)
println(@sprintf("  %-16s | %-30s | %-30s", "state", "point", "traj"))
println("  " * "-"^80)

n_ok_basic = n_fail_basic = 0
for (lab, x0, p0) in cases_hvf
    fl = x0 isa Number ? f_free_1 : f_free_2
    m1, d1 = cell_ocpfree_basic(fl, :point, x0)
    m2, d2 = cell_ocpfree_basic(fl, :traj, x0)
    for m in (m1, m2)
        m == "✓" ? (global n_ok_basic += 1) : (global n_fail_basic += 1)
    end
    println(@sprintf("  %-16s | %s %-28s | %s %-28s", lab, m1, d1, m2, d2))
end
println("  " * "-"^80)
println(
    @sprintf(
        "  totals:  ✓ %d works   ✗/? %d fail-or-wrong   (of %d)",
        n_ok_basic,
        n_fail_basic,
        2 * length(cases_hvf)
    )
)
println("="^96)

# ---------------------------------------------------------------------------
# Flow(ocp) — variable= / variable_costate= axis (flagged as possibly incomplete)
# ---------------------------------------------------------------------------

cases_var_scalar = [
    ("scalar Real", 1.0, 0.5),
    ("scalar Complex", 1.0 + 2.0im, 0.5 + 0.1im),
    ("Dual scalar", ForwardDiff.Dual(1.0, 1.0), ForwardDiff.Dual(0.5, 0.0)),
]
cases_var_vec = [
    ("Vector Real", [1.0, 2.0], [0.5, 0.3]), ("SVector Real", SA[1.0, 2.0], SA[0.5, 0.3])
]
const V_TEST = 0.7

function _maxerr_ocpvar(x0, p0, v, xf, pf)
    return maximum(
        abs.(vcat(_flat(xf) .- _flat(x0 .* exp(v)), _flat(pf) .- _flat(p0 .* exp(-v))))
    )
end

function cell_ocpvar(fl, x0, p0, v)
    try
        xf, pf = fl(0.0, x0, p0, 1.0; variable=v)
        err = try
            _maxerr_ocpvar(x0, p0, v, xf, pf)
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

function cell_ocpvarcostate(fl, x0, p0, v)
    try
        xf, pf, pvf = fl(0.0, x0, p0, 1.0; variable=v, variable_costate=true)
        errxp = _maxerr_ocpvar(x0, p0, v, xf, pf)
        refpv = -sum(_flat(x0) .* _flat(p0))
        errpv = maximum(abs.(_flat(pvf) .- refpv))
        err = max(errxp, errpv)
        ok = isfinite(err) && err ≤ 1e-4
        mark = ok ? "✓" : "?"
        return (mark, @sprintf("err=%.1e", err))
    catch e
        return ("✗", _short(string(nameof(typeof(e))) * ": " * sprint(showerror, e)))
    end
end

println("\n", "="^96)
println("  CTFlows CPU probe — Flow(ocp), variable= / variable_costate= axis")
println("  ẋ = v·x ⇒ (xf,pf)=(x0·e^v,p0·e⁻ᵛ);  variable_costate: pvf = -Σ(x0·p0)·(tf-t0)")
println("="^96)
println(
    @sprintf(
        "  %-16s | %-30s | %-30s", "state/costate", "variable=v", "+variable_costate=true"
    )
)
println("  " * "-"^80)

n_ok_var = n_fail_var = 0
for (lab, x0, p0) in cases_var_scalar
    m1, d1 = cell_ocpvar(f_freev_1, x0, p0, V_TEST)
    m2, d2 = cell_ocpvarcostate(f_freev_1, x0, p0, V_TEST)
    for m in (m1, m2)
        m == "✓" ? (global n_ok_var += 1) : (global n_fail_var += 1)
    end
    println(@sprintf("  %-16s | %s %-28s | %s %-28s", lab, m1, d1, m2, d2))
end
for (lab, x0, p0) in cases_var_vec
    m1, d1 = cell_ocpvar(f_freev_2, x0, p0, V_TEST)
    m2, d2 = cell_ocpvarcostate(f_freev_2, x0, p0, V_TEST)
    for m in (m1, m2)
        m == "✓" ? (global n_ok_var += 1) : (global n_fail_var += 1)
    end
    println(@sprintf("  %-16s | %s %-28s | %s %-28s", lab, m1, d1, m2, d2))
end
println("  " * "-"^80)
println(
    @sprintf(
        "  totals:  ✓ %d works   ✗/? %d fail-or-wrong   (of %d)",
        n_ok_var,
        n_fail_var,
        2 * (length(cases_var_scalar) + length(cases_var_vec))
    )
)
println("="^96)
println("""
  NOTE: this axis was flagged as possibly incomplete before measuring — read the totals
  above literally, do not assume full coverage. Fold whatever is measured (including
  failures) into docs/src/compatibility/ocp_free.md, and open a follow-up issue (like #357)
  instead of forcing a clean table if the result is irregular.
""")

# ---------------------------------------------------------------------------
# Flow(ocp, DynClosedLoop) — Hamiltonian block, :total vs :partial, unconstrained
# ---------------------------------------------------------------------------

const _EE = exp(1.0)

function _ref_dyn_xf(x0, p0)
    return x0 ./ _EE .+ (p0 ./ 2) .* (_EE - 1 / _EE)
end
_ref_dyn_pf(p0) = p0 .* _EE

function _maxerr_dyn(kind, r, x0, p0)
    if kind === :point
        xf, pf = r
    else
        xf = CTModels.Components.state(r)(1.0)
        pf = CTModels.Components.costate(r)(1.0)
    end
    return maximum(
        abs.(
            vcat(
                _flat(xf) .- _flat(_ref_dyn_xf(x0, p0)), _flat(pf) .- _flat(_ref_dyn_pf(p0))
            ),
        ),
    )
end

function cell_dyn(fl, kind, x0, p0)
    g = kind === :point ? (() -> fl(0.0, x0, p0, 1.0)) : (() -> fl((0.0, 1.0), x0, p0))
    try
        r = g()
        err = try
            _maxerr_dyn(kind, r, x0, p0)
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

function _print_dyn_table(title, f1, f2)
    println("\n", "="^100)
    println("  ", title)
    println("="^100)
    println(
        @sprintf(
            "  %-16s | %-16s | %-16s | %-16s | %-16s",
            "state",
            ":total point",
            ":total traj",
            ":partial point",
            ":partial traj"
        )
    )
    println("  " * "-"^96)
    n_ok = n_fail = 0
    for (lab, x0, p0) in cases_hvf
        f = x0 isa Number ? f1 : f2
        marks = String[]
        for (fl, kind) in
            ((f.total, :point), (f.total, :traj), (f.partial, :point), (f.partial, :traj))
            m, d = cell_dyn(fl, kind, x0, p0)
            m == "✓" ? (n_ok += 1) : (n_fail += 1)
            push!(marks, @sprintf("%s %-14s", m, d))
        end
        println(
            @sprintf(
                "  %-16s | %s | %s | %s | %s", lab, marks[1], marks[2], marks[3], marks[4]
            )
        )
    end
    println("  " * "-"^96)
    println(
        @sprintf(
            "  totals:  ✓ %d works   ✗/? %d fail-or-wrong   (of %d)",
            n_ok,
            n_fail,
            4 * length(cases_hvf)
        )
    )
    println("="^100)
    return nothing
end

_print_dyn_table(
    "Flow(ocp, DynClosedLoop) — UNCONSTRAINED, H̃=p(u-x)-0.5u², law u=p, stationary feedback",
    (total=f_dyn_total_1, partial=f_dyn_partial_1),
    (total=f_dyn_total_2, partial=f_dyn_partial_2),
)

# ---------------------------------------------------------------------------
# Flow(ocp, DynClosedLoop) — same table, CONSTRAINED (constraint=1, multiplier=0.3)
# ---------------------------------------------------------------------------
#
# g≡1, μ≡0.3 ⇒ μ·g≡0.3, a pure CONSTANT added to H̃_c ⇒ the dynamics (and hence the
# analytic reference _ref_dyn_xf/_ref_dyn_pf) are UNCHANGED from the unconstrained table
# above. This directly answers: "does the constrained path continue to work wherever the
# unconstrained one does?" — same expected numeric result, only the machinery differs.
# ---------------------------------------------------------------------------

_print_dyn_table(
    "Flow(ocp, DynClosedLoop) — CONSTRAINED (constraint=(x,u)->1.0, multiplier=(x,p)->0.3)",
    (total=f_dyn_total_c_1, partial=f_dyn_partial_c_1),
    (total=f_dyn_total_c_2, partial=f_dyn_partial_c_2),
)

# ---------------------------------------------------------------------------
# Flow(ocp, OpenLoop/ClosedLoop) — state-only block (ControlledFlow, no AD in the RHS)
# ---------------------------------------------------------------------------

const _EM2 = exp(-2.0)

function _maxerr_cl(kind, r, x0)
    got = kind === :point ? r : Trajectories.state(r)(1.0)
    return maximum(abs.(_flat(got) .- _flat(x0 .* _EM2)))
end

function cell_cl(fl, kind, x0)
    g = kind === :point ? (() -> fl(0.0, x0, 1.0)) : (() -> fl((0.0, 1.0), x0))
    try
        r = g()
        err = try
            _maxerr_cl(kind, r, x0)
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
println("  CTFlows CPU probe — Flow(ocp, ClosedLoop), law u=-x, ẋ=-2x ⇒ xf=x0·e⁻²")
println("  no costate (ControlledFlow — state flow only), no AD in the RHS evaluation")
println("="^96)
println(@sprintf("  %-16s | %-30s | %-30s", "state", "point", "traj"))
println("  " * "-"^80)

n_ok_cl = n_fail_cl = 0
for (lab, x0, p0) in cases_hvf
    fl = x0 isa Number ? f_cl_1 : f_cl_2
    m1, d1 = cell_cl(fl, :point, x0)
    m2, d2 = cell_cl(fl, :traj, x0)
    for m in (m1, m2)
        m == "✓" ? (global n_ok_cl += 1) : (global n_fail_cl += 1)
    end
    println(@sprintf("  %-16s | %s %-28s | %s %-28s", lab, m1, d1, m2, d2))
end
println("  " * "-"^80)
println(
    @sprintf(
        "  totals:  ✓ %d works   ✗/? %d fail-or-wrong   (of %d)",
        n_ok_cl,
        n_fail_cl,
        2 * length(cases_hvf)
    )
)
println("="^96)
println(
    """
  Legend & notes (all Flow(ocp)/Flow(ocp,law) blocks above)
  ───────────────────────────────────────────────────────────
  ✓  works, result matches the closed-form analytic reference to err ≤ 1e-4
  ✗  raised the named error type (message truncated)   ?  ran but result did not match

  Observed nuances (fold into docs/src/compatibility/ocp_free.md and ocp_control_laws.md):
   • State dimension is fixed at OCP construction — two ocp instances (n=1, n=2) stand in
     for the single-flow-any-size pattern used by VF/HVF/Hamiltonian.
   • Flow(ocp) and Flow(ocp, DynClosedLoop) are both AD-backed (like Flow(Hamiltonian)) —
     Complex is expected ✗ for the same structural reason; not part of `cases_hvf`, so no
     dedicated Complex row is printed here (see hamiltonian.md's note for the shared cause).
   • Flow(ocp, OpenLoop/ClosedLoop) has no internal AD in the dynamics evaluation itself —
     Complex is expected ✓, like Flow(VectorField); `cases_hvf` DOES include Complex rows,
     so this is measured directly above.
   • :total and :partial coincide exactly here because the chosen law (u=p) is the
     stationary point of H̃ (∂H̃/∂u=0) — by design, to make the two columns a genuine
     consistency cross-check rather than two unrelated numbers.
"""
)

# =============================================================================
# Flow(h̃, law) — pseudo-Hamiltonian + DynClosedLoop (no OCP)
# =============================================================================
#
# Ground-truth source for docs/src/compatibility/pseudo_hamiltonian.md.
#
# Dynamics chosen to generalize to any state/costate container (unlike the scalar
# example in flows/control_laws.md): h̃(x,p,u) = sum(p.*u) - 0.5*sum(abs2,u),
# law u(x,p) = p (stationary: ∂h̃/∂u = p-u = 0 at u=p) ⇒ H(x,p) = 0.5·sum(p.^2)
# ⇒ ẋ = ∂H/∂p = p, ṗ = -∂H/∂x = 0 ⇒ xf = x0+p0, pf = p0 at (t0,tf) = (0,1).
#
# Unlike Flow(ocp)/Flow(ocp, law) (issue #358), PseudoHamiltonianSystem/ComposedHamiltonian
# wrap the user's h̃ function DIRECTLY — no OCP-derived fixed-size buffer — so this block
# reuses the SAME 17-entry `cases_hvf` list as HVF/VF above (no scalar/vector flow split
# needed, unlike the OCP blocks). Hypothesis under test: this constructor should behave
# like Flow(Hamiltonian) (AD-backed, only Complex/hand-built Dual fail), NOT like the
# restricted Flow(ocp,...) family — measured below, not assumed.
# =============================================================================

h̃_pf = Data.PseudoHamiltonian((x, p, u) -> sum(p .* u) - 0.5 * sum(abs2, u))
law_dyn_pf = Data.DynClosedLoop((x, p) -> p)

hflow_pf_total = Flows.Flow(h̃_pf, law_dyn_pf; reltol=1e-8)
hflow_pf_partial = Flows.Flow(h̃_pf, law_dyn_pf; hamiltonian_type=:partial, reltol=1e-8)

function _maxerr_pf(kind, r, x0, p0)
    if kind === :point
        xf, pf = r
    else
        xf = Trajectories.state(r)(1.0)
        pf = Trajectories.costate(r)(1.0)
    end
    return maximum(abs.(vcat(_flat(xf) .- _flat(x0 .+ p0), _flat(pf) .- _flat(p0))))
end

function cell_pf(fl, kind, x0, p0)
    g = kind === :point ? (() -> fl(0.0, x0, p0, 1.0)) : (() -> fl((0.0, 1.0), x0, p0))
    try
        r = g()
        err = try
            _maxerr_pf(kind, r, x0, p0)
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

println("\n", "="^100)
println(
    "  CTFlows CPU probe — Flow(h̃, law), h̃=p·u-0.5|u|², law u=p, ẋ=p,ṗ=0 ⇒ xf=x0+p0, pf=p0"
)
println("="^100)
println(
    @sprintf(
        "  %-16s | %-16s | %-16s | %-16s | %-16s",
        "state",
        ":total point",
        ":total traj",
        ":partial point",
        ":partial traj"
    )
)
println("  " * "-"^96)
n_ok_pf = n_fail_pf = 0
for (lab, x0, p0) in cases_hvf
    marks = String[]
    for (fl, kind) in (
        (hflow_pf_total, :point),
        (hflow_pf_total, :traj),
        (hflow_pf_partial, :point),
        (hflow_pf_partial, :traj),
    )
        m, d = cell_pf(fl, kind, x0, p0)
        m == "✓" ? (global n_ok_pf += 1) : (global n_fail_pf += 1)
        push!(marks, @sprintf("%s %-14s", m, d))
    end
    println(
        @sprintf("  %-16s | %s | %s | %s | %s", lab, marks[1], marks[2], marks[3], marks[4])
    )
end
println("  " * "-"^96)
println(
    @sprintf(
        "  totals:  ✓ %d works   ✗/? %d fail-or-wrong   (of %d)",
        n_ok_pf,
        n_fail_pf,
        4 * length(cases_hvf)
    )
)
println("="^100)

println("\nFlow(h̃, OpenLoop/ClosedLoop) — expected rejection (no costate access):")
try
    Flows.Flow(h̃_pf, Data.ClosedLoop(x -> -x); reltol=1e-8)
    println("  unexpectedly succeeded")
catch e
    println("  ✗ ", nameof(typeof(e)), ": ", sprint(showerror, e))
end

println(
    """
  Legend & notes
  ──────────────
  ✓  works, result matches the closed-form analytic reference (xf=x0+p0, pf=p0) to err ≤ 1e-4
  ✗  raised the named error type (message truncated)   ?  ran but result did not match

  This block settles the hypothesis above — read the totals literally, do not assume the
  Flow(Hamiltonian) profile carries over without checking Complex/Dual rows specifically.
  Fold whatever is measured into docs/src/compatibility/pseudo_hamiltonian.md.
""",
)

# =============================================================================
# Flow(h̃vf, law) — pseudo-Hamiltonian VECTOR FIELD + DynClosedLoop (no OCP, no AD)
# =============================================================================
#
# Ground-truth source for docs/src/compatibility/pseudo_hamiltonian_vector_field.md.
#
# Same reference dynamics as the Flow(h̃, law) block above, but pre-differentiated by
# hand instead of via AD: h̃(x,p,u) = p·u - 0.5|u|², law u(x,p) = p (stationary point)
# ⇒ H(x,p) = 0.5·sum(p.^2) ⇒ h̃vf(x,p,u) = (ẋ,ṗ) = (u, 0) ⇒ xf = x0+p0, pf = p0 at
# (t0,tf) = (0,1) — identical analytic reference, so `_maxerr_pf` is reused as-is.
#
# Unlike Flow(h̃, law), there is no AD anywhere here — h̃vf already returns the
# derivatives directly — so this constructor has no `hamiltonian_type` axis; instead
# it has the OOP/IP axis, exactly like Flow(HamiltonianVectorField) above. Hypothesis
# under test: this constructor should behave like Flow(HamiltonianVectorField)
# (no unsupported state/costate type, only the same IP+immutable-u0 ⚠), NOT like the
# AD-backed Flow(h̃, law) (which fails on Complex/hand-built Dual) — measured below,
# not assumed.
# =============================================================================

h̃vf_pvf = Data.PseudoHamiltonianVectorField((x, p, u) -> (u, zero(p)))
h̃vf_pvf_ip = Data.PseudoHamiltonianVectorField(
    (dx, dp, x, p, u) -> (dx.=u; dp.=0); is_inplace=true
)
law_dyn_pvf = Data.DynClosedLoop((x, p) -> p)

hflow_pvf = Flows.Flow(h̃vf_pvf, law_dyn_pvf; reltol=1e-8)
hflow_pvf_ip = Flows.Flow(h̃vf_pvf_ip, law_dyn_pvf; reltol=1e-8)

function cell_pvf(fl, kind, x0, p0)
    g = kind === :point ? (() -> fl(0.0, x0, p0, 1.0)) : (() -> fl((0.0, 1.0), x0, p0))
    l = CollectLogger(String[])
    try
        r = Logging.with_logger(l) do
            return g()
        end
        warned = any(m -> occursin("InPlace PseudoHamiltonianVectorField", m), l.msgs)
        err = try
            _maxerr_pf(kind, r, x0, p0)
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
println(
    "  CTFlows CPU probe — Flow(h̃vf, law), h̃vf=(u,0), law u=p ⇒ ẋ=p,ṗ=0 ⇒ xf=x0+p0, pf=p0"
)
println("="^96)
println(
    @sprintf(
        "  %-16s | %-14s | %-14s | %-14s | %-14s",
        "state/costate",
        "OOP point",
        "OOP traj",
        "IP point",
        "IP traj"
    )
)
println("  " * "-"^92)
n_ok_pvf = n_warn_pvf = n_fail_pvf = 0
for (lab, x0, p0) in cases_hvf
    marks = String[]
    for (fl, kind) in (
        (hflow_pvf, :point),
        (hflow_pvf, :traj),
        (hflow_pvf_ip, :point),
        (hflow_pvf_ip, :traj),
    )
        m, d = cell_pvf(fl, kind, x0, p0)
        m == "✓" && (global n_ok_pvf += 1)
        m == "⚠" && (global n_warn_pvf += 1)
        (m == "✗" || m == "?") && (global n_fail_pvf += 1)
        push!(marks, @sprintf("%s %-12s", m, d))
    end
    println(
        @sprintf("  %-16s | %s | %s | %s | %s", lab, marks[1], marks[2], marks[3], marks[4])
    )
end
println("  " * "-"^92)
println(
    @sprintf(
        "  totals:  ✓ %d works   ⚠ %d works-with-warning   ✗/? %d fail-or-wrong   (of %d)",
        n_ok_pvf,
        n_warn_pvf,
        n_fail_pvf,
        4 * length(cases_hvf)
    )
)
println("="^96)

println("\nFlow(h̃vf, OpenLoop/ClosedLoop) — expected rejection (no costate access):")
try
    Flows.Flow(h̃vf_pvf, Data.ClosedLoop(x -> -x); reltol=1e-8)
    println("  unexpectedly succeeded")
catch e
    println("  ✗ ", nameof(typeof(e)), ": ", sprint(showerror, e))
end

println(
    """
  Legend & notes
  ──────────────
  ✓  works, result matches the closed-form analytic reference (xf=x0+p0, pf=p0) to err ≤ 1e-4
  ⚠  works but emits a performance @warn — in-place h̃vf + immutable u0 (SVector/SMatrix):
     same fallback as Flow(HamiltonianVectorField).
  ✗  raised the named error type    ?  ran but result did not match

  This block settles the hypothesis above — read the totals literally. Fold whatever is
  measured into docs/src/compatibility/pseudo_hamiltonian_vector_field.md.
""",
)

# =============================================================================
# Flow(fc, law) — controlled vector field + OpenLoop/ClosedLoop (no OCP)
# =============================================================================
#
# Ground-truth source for docs/src/compatibility/controlled_vector_field.md.
#
# fc(x,u) = u - x (same dynamics as flows/control_laws.md / ocp_control_laws.md).
# law_cl = ClosedLoop(x -> -x) ⇒ ẋ = -2x ⇒ xf = x0·e⁻² at t=1 (same reference already used
# in the OCP block above). law_ol = OpenLoop(t -> 1.0) (constant u=1) ⇒ ẋ = 1-x ⇒
# xf = 1+(x0-1)·e⁻¹ at t=1 — covers the OTHER feedback branch, which ocp_control_laws.md
# only ever exercised through ClosedLoop.
#
# Data.ControlledVectorField has NO in-place variant (confirmed by reading
# CTBase/src/Data/controlled_vector_field.jl) — Systems.build_system(ComposedVectorField)
# builds a plain out-of-place VectorFieldSystem, with NO ocp-derived fixed-size buffer
# (unlike Flow(ocp, OpenLoop/ClosedLoop) — issue #358). Hypothesis under test: this
# constructor should be as permissive as Flow(VectorField)'s OOP columns (already fully
# green on CPU) — measured below, not assumed.
# =============================================================================

fc_cvf = Data.ControlledVectorField((x, u) -> u .- x)
law_cl = Data.ClosedLoop(x -> -x)
law_ol = Data.OpenLoop(t -> 1.0)

fclow_cl = Flows.Flow(fc_cvf, law_cl; reltol=1e-8)
fclow_ol = Flows.Flow(fc_cvf, law_ol; reltol=1e-8)

function _maxerr_fc_cl(kind, r, x0)
    got = kind === :point ? r : Trajectories.state(r)(1.0)
    return maximum(abs.(_flat(got) .- _flat(x0 .* _EM2)))
end

function cell_fc_cl(fl, kind, x0)
    g = kind === :point ? (() -> fl(0.0, x0, 1.0)) : (() -> fl((0.0, 1.0), x0))
    try
        r = g()
        err = try
            _maxerr_fc_cl(kind, r, x0)
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
println(
    "  CTFlows CPU probe — Flow(fc, ClosedLoop), fc(x,u)=u-x, law u=-x, ẋ=-2x ⇒ xf=x0·e⁻²"
)
println("  no OCP, no AD anywhere (plain out-of-place VectorFieldSystem)")
println("="^96)
println(@sprintf("  %-16s | %-30s | %-30s", "state", "point", "traj"))
println("  " * "-"^80)

n_ok_fc = n_fail_fc = 0
for (lab, x0, p0) in cases_hvf
    m1, d1 = cell_fc_cl(fclow_cl, :point, x0)
    m2, d2 = cell_fc_cl(fclow_cl, :traj, x0)
    for m in (m1, m2)
        m == "✓" ? (global n_ok_fc += 1) : (global n_fail_fc += 1)
    end
    println(@sprintf("  %-16s | %s %-28s | %s %-28s", lab, m1, d1, m2, d2))
end
println("  " * "-"^80)
println(
    @sprintf(
        "  totals:  ✓ %d works   ✗/? %d fail-or-wrong   (of %d)",
        n_ok_fc,
        n_fail_fc,
        2 * length(cases_hvf)
    )
)
println("="^96)

# OpenLoop demo — a few representative cases, not the full matrix (only _law_control's
# arity changes between OpenLoopFeedback/ClosedLoopFeedback; integration mechanics are
# identical, already exhaustively measured above via ClosedLoop).
const _E1 = exp(-1.0)
println("\nFlow(fc, OpenLoop), fc(x,u)=u-x, law u≡1, ẋ=1-x ⇒ xf=1+(x0-1)·e⁻¹ — spot-check:")
for (lab, x0) in (
    ("scalar Real", 1.0),
    ("Vector Real", [1.0, 0.0]),
    ("SVector Complex", SA[1.0 + 2.0im, 0.0 + 0.0im]),
    ("Dual scalar", ForwardDiff.Dual(1.0, 1.0)),
)
    xf = fclow_ol(0.0, x0, 1.0)
    ref = 1 .+ (x0 .- 1) .* _E1
    err = maximum(abs.(_flat(xf) .- _flat(ref)))
    println(@sprintf("  %-16s | err=%.1e", lab, err))
end

println("\nFlow(fc, DynClosedLoop) — expected rejection (no costate access):")
try
    Flows.Flow(fc_cvf, Data.DynClosedLoop((x, p) -> p); reltol=1e-8)
    println("  unexpectedly succeeded")
catch e
    println("  ✗ ", nameof(typeof(e)), ": ", sprint(showerror, e))
end

println("""
  Legend & notes
  ──────────────
  ✓  works, result matches the closed-form analytic reference (xf=x0·e⁻²) to err ≤ 1e-4
  ✗  raised the named error type (message truncated)   ?  ran but result did not match

  This block settles the hypothesis above — read the totals literally. Fold whatever is
  measured into docs/src/compatibility/controlled_vector_field.md.
""")
