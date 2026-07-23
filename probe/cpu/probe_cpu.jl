#!/usr/bin/env julia
# =============================================================================
# CPU capability probe for CTFlows  —  Flow(VectorField) state-type matrix
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
# Scope: `Flow(VectorField)` today. Other constructors (HamiltonianVectorField,
# Hamiltonian, ODEFunction/ODEProblem, ocp) become additional blocks as their
# compatibility pages land.
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
