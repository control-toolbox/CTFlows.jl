# =============================================================================
# HamiltonianVectorFieldSystem
# =============================================================================
#
# Design rationale
# ────────────────
# u = [x; p] requires a split whose shape depends on x0/p0.
# → RHS closures are built lazily in build_problem, not at construction.
# → Exactly ONE closure is created per flow call.
# → N is always an Int (never nothing); determined from x0 at call time.
#
# Shape coercion applies to the HVF *inputs* (x, p) only:
#   Number         → only(view)    (1-element SubArray → scalar)
#   AbstractVector → identity
#   AbstractMatrix → identity
#
# HVF *outputs* (dx, dp):
#   OOP HVF → returned as-is by hvf; assigned into du or vcat'd
#   IP HVF  → always mutable vector views (or allocated buffers), never coerced
# =============================================================================

struct HamiltonianVectorFieldSystem{
        F  <: Function,
        TD <: Traits.TimeDependence,
        VD <: Traits.VariableDependence,
        MD <: Traits.AbstractMutabilityTrait,
} <: AbstractHamiltonianSystem{TD, VD, Traits.WithoutAD}
    hvf::Data.HamiltonianVectorField{F, TD, VD, MD}
end

# =============================================================================
# IC-shape helpers
# =============================================================================

"""State dimension N inferred from the initial condition (always Int)."""
_state_dim(::Number)          = 1
_state_dim(x::AbstractVector) = length(x)
_state_dim(x::AbstractMatrix) = size(x, 1)

"""
Closure that maps a vector view from `_ham_split` to the shape the HVF expects.
Applied to *inputs* (x, p) only — never to output buffers.
"""
_make_coerce(::Number)          = only      # 1-element SubArray → scalar
_make_coerce(::AbstractVector)  = identity
_make_coerce(::AbstractMatrix)  = identity

# =============================================================================
# _ham_split / _ham_assign!
# N is always an Int here.
# =============================================================================

_ham_split(u::AbstractVector, N::Int) = (@view(u[1:N]),    @view(u[N+1:2N]))
_ham_split(u::AbstractMatrix, N::Int) = (@view(u[1:N, :]), @view(u[N+1:2N, :]))

_ham_assign!(du::AbstractVector, dx, dp, N::Int) = (du[1:N] .= dx; du[N+1:2N] .= dp)
_ham_assign!(du::AbstractMatrix, dx, dp, N::Int) = (du[1:N,:] .= dx; du[N+1:2N,:] .= dp)

# =============================================================================
# Internal closure builders
# =============================================================================

# ── In-place closures (u0 mutable, e.g. Vector) ──────────────────────────────

# OOP HVF: split → coerce inputs → call → assign back
function _build_ip_rhs_hvf(::Type{Traits.OutOfPlace}, hvf, N, cx, cp)
    return function (du, u, λ, t)
        xv, pv = _ham_split(u, N)
        dx, dp = hvf(t, cx(xv), cp(pv), Common.variable(λ))
        _ham_assign!(du, dx, dp, N)
        return nothing
    end
end

# IP HVF: split src and dst → coerce inputs → HVF writes into dst views
# dx_view / dp_view are NEVER coerced: they must remain mutable 1-D containers.
function _build_ip_rhs_hvf(::Type{Traits.InPlace}, hvf, N, cx, cp)
    return function (du, u, λ, t)
        xv,  pv  = _ham_split(u,  N)
        dxv, dpv = _ham_split(du, N)   # mutable views → HVF writes into them
        hvf(dxv, dpv, t, cx(xv), cp(pv), Common.variable(λ))
        return nothing
    end
end

# ── Out-of-place closures (u0 immutable, e.g. SVector) ───────────────────────

# OOP HVF: split → coerce inputs → call → vcat, convert back to typeof(u)
function _build_oop_rhs_hvf(::Type{Traits.OutOfPlace}, hvf, N, cx, cp)
    return function (u, λ, t)
        xv, pv = _ham_split(u, N)
        dx, dp = hvf(t, cx(xv), cp(pv), Common.variable(λ))
        return typeof(u)(vcat(dx, dp))
    end
end

# IP HVF + immutable u0 ("finalize" case):
#   allocate mutable buffers → HVF writes → convert back to typeof(u).
#   collect(view) ensures we get a plain Vector even if view is a SubArray.
function _build_oop_rhs_hvf(::Type{Traits.InPlace}, hvf, N, cx, cp)
    return function (u, λ, t)
        xv, pv   = _ham_split(u, N)
        dx, dp   = similar(collect(xv)), similar(collect(pv))
        hvf(dx, dp, t, cx(xv), cp(pv), Common.variable(λ))
        return typeof(u)(vcat(dx, dp))
    end
end

# =============================================================================
# Public entry-points called by build_problem
# =============================================================================

"""
    build_rhs(sys::HamiltonianVectorFieldSystem, x0, p0) -> f!(du,u,λ,t)

Build the **in-place** RHS for `sys` specialised on the shapes of `x0` and `p0`.
Use when `u0 = vcat(x0, p0)` is mutable (e.g. `Vector`).

Compiled once per `(typeof(x0), typeof(p0))` combination by Julia's dispatch.
"""
function build_rhs(sys::HamiltonianVectorFieldSystem{F,TD,VD,MD}, x0, p0) where {F,TD,VD,MD}
    N  = _state_dim(x0)
    cx = _make_coerce(x0)
    cp = _make_coerce(p0)
    return _build_ip_rhs_hvf(MD, sys.hvf, N, cx, cp)
end

"""
    build_oop_rhs(sys::HamiltonianVectorFieldSystem, x0, p0) -> f(u,λ,t)

Build the **out-of-place** RHS for `sys` specialised on the shapes of `x0` and `p0`.
Use when `u0 = vcat(x0, p0)` is immutable (e.g. `SVector`).

For an IP HVF + immutable u0, mutable buffers are allocated internally and the
result is converted back to `typeof(u)`. A warning is emitted to encourage
switching to an OOP HVF in that case.
"""
function build_oop_rhs(sys::HamiltonianVectorFieldSystem{F,TD,VD,MD}, x0, p0) where {F,TD,VD,MD}
    if MD === Traits.InPlace
        @warn "InPlace HamiltonianVectorField with immutable u0 (e.g. SVector): " *
              "prefer an out-of-place HVF for better performance."
    end
    N  = _state_dim(x0)
    cx = _make_coerce(x0)
    cp = _make_coerce(p0)
    return _build_oop_rhs_hvf(MD, sys.hvf, N, cx, cp)
end

# =============================================================================
# build_problem  (SciML integrator side)
# =============================================================================
#
# Decision tree:
#   u0 mutable   →  build_rhs(sys, x0, p0)     →  ODEProblem(f!, u0, tspan, λ)
#   u0 immutable →  build_oop_rhs(sys, x0, p0)  →  ODEProblem(f,  u0, tspan, λ)
#
# The HVF mutability (InPlace/OutOfPlace) is an implementation detail handled
# inside the builders; build_problem only sees the u0 mutability.

function Integrators.build_problem(
        integ  ::SciML,
        sys    ::HamiltonianVectorFieldSystem,
        config ::Common.AbstractConfig;
        variable,
        cache,
)
    x0 = Common.initial_state(config)
    p0 = Common.initial_costate(config)
    u0 = Common.initial_condition(config)   # = vcat(x0, p0)
    λ  = Common.ODEParameters(variable, cache)

    if ismutable(u0)
        return ODEProblem(build_rhs(sys, x0, p0),     u0, Common.tspan(config), λ)
    else
        return ODEProblem(build_oop_rhs(sys, x0, p0), u0, Common.tspan(config), λ)
    end
end

# =============================================================================
# Base.show
# =============================================================================

function Base.show(io::IO, sys::HamiltonianVectorFieldSystem{F,TD,VD,MD}) where {F,TD,VD,MD}
    println(io, "HamiltonianVectorFieldSystem")
    print(io,   "  wraps: HamiltonianVectorField: ",
          Data._td_label(TD), ", ", Data._vd_label(VD), ", ", Data._md_label(MD))
end

Base.show(io::IO, ::MIME"text/plain", sys::HamiltonianVectorFieldSystem) = show(io, sys)
