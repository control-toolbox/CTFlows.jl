# =============================================================================
# VectorFieldSystem
# =============================================================================
#
# Design rationale
# ────────────────
# No split u → (x, p), no coerce: the RHS does not depend on the shape of x0.
# All three closures (in-place, oop, oop-finalize) are built once at construction.
# build_problem selects the single appropriate closure based on ismutable(u0).
#
# Shape consistency is natural:
#   x0 :: Number   → ismutable = false → oop path → vf(t,u,v) returns scalar  ✓
#   x0 :: SVector  → ismutable = false → finalize path → typeof(u)(dx)         ✓
#   x0 :: Vector   → ismutable = true  → in-place path                         ✓
#
# Unsupported combination: InPlace VF + Number x0  (similar(::Number) fails).
# Detected at construction with a clear ArgumentError.
# =============================================================================

struct VectorFieldSystem{
        F  <: Function,
        TD <: Traits.TimeDependence,
        VD <: Traits.VariableDependence,
        MD <: Traits.AbstractMutabilityTrait,
        RHS    <: Function,
        OOPROHS <: Function,
        FINRHS,                        # Function or Nothing
} <: AbstractStateSystem{TD, VD}
    vf             ::Data.VectorField{F, TD, VD, MD}
    rhs            ::RHS
    rhs_oop        ::OOPROHS
    rhs_oop_finalize::FINRHS
end

# =============================================================================
# Constructors
# =============================================================================

function VectorFieldSystem(vf::Data.VectorField{F, TD, VD, Traits.OutOfPlace}) where {F, TD, VD}
    rhs     = _build_ip_rhs_vf(Traits.OutOfPlace, vf)
    oop     = _build_oop_rhs_vf(Traits.OutOfPlace, vf)
    return VectorFieldSystem{F, TD, VD, Traits.OutOfPlace,
                             typeof(rhs), typeof(oop), Nothing}(vf, rhs, oop, nothing)
end

function VectorFieldSystem(vf::Data.VectorField{F, TD, VD, Traits.InPlace}) where {F, TD, VD}
    rhs     = _build_ip_rhs_vf(Traits.InPlace, vf)
    oop     = _build_oop_rhs_vf(Traits.InPlace, vf)
    fin     = _build_finalize_rhs_vf(Traits.InPlace, vf)
    return VectorFieldSystem{F, TD, VD, Traits.InPlace,
                             typeof(rhs), typeof(oop), typeof(fin)}(vf, rhs, oop, fin)
end

# =============================================================================
# Internal closure builders
# =============================================================================

# ── In-place closures (u0 mutable, e.g. Vector) ──────────────────────────────

# OOP VF: broadcast-assign the return value into du
function _build_ip_rhs_vf(::Type{Traits.OutOfPlace}, vf::Data.VectorField)
    return (du, u, λ, t) -> (du .= vf(t, u, Common.variable(λ)); nothing)
end

# IP VF: call vf directly with du as first argument
function _build_ip_rhs_vf(::Type{Traits.InPlace}, vf::Data.VectorField)
    return (du, u, λ, t) -> (vf(du, t, u, Common.variable(λ)); nothing)
end

# ── Out-of-place closures (u0 immutable, e.g. SVector or Number) ─────────────

# OOP VF: direct call, returns whatever vf returns (scalar, vector, …)
function _build_oop_rhs_vf(::Type{Traits.OutOfPlace}, vf::Data.VectorField)
    return (u, λ, t) -> vf(t, u, Common.variable(λ))
end

# IP VF + mutable buffer: allocate similar(u), fill it, return it.
# Only reached when u0 is an AbstractArray (not a Number); see guard below.
function _build_oop_rhs_vf(::Type{Traits.InPlace}, vf::Data.VectorField)
    return function (u, λ, t)
        dx = similar(u)
        vf(dx, t, u, Common.variable(λ))
        return dx
    end
end

# ── Finalize closure (IP VF + immutable AbstractArray u0, e.g. SVector) ──────
#
# similar(u) returns a mutable counterpart (e.g. MVector for SVector).
# typeof(u)(dx) converts back to the original immutable type.
# Not defined for OutOfPlace VFs (rhs_oop_finalize = nothing).
function _build_finalize_rhs_vf(::Type{Traits.InPlace}, vf::Data.VectorField)
    return function (u, λ, t)
        dx = similar(u)
        vf(dx, t, u, Common.variable(λ))
        return typeof(u)(dx)
    end
end

# =============================================================================
# Guard: InPlace VF + scalar x0 is unsupported
#
# Called from build_problem before constructing the ODEProblem.
# A Number is immutable, so we would reach rhs_oop_finalize which calls
# similar(::Number) — that errors. Better to fail early with a clear message.
# =============================================================================

function _check_vf_scalar_inplace(
        sys::VectorFieldSystem{F, TD, VD, Traits.InPlace}, u0::Number) where {F, TD, VD}
    throw(ArgumentError(
        "An in-place VectorField cannot be used with a scalar initial condition " *
        "(u0 :: $(typeof(u0))). Either use an out-of-place VectorField, or wrap " *
        "the initial condition in a 1-element Vector: u0 = [$(u0)]."
    ))
end
_check_vf_scalar_inplace(::VectorFieldSystem, ::Any) = nothing   # no-op otherwise

# =============================================================================
# Public accessors
# =============================================================================

"""Return the pre-built in-place RHS `(du, u, λ, t) -> nothing`."""
rhs(sys::VectorFieldSystem) = sys.rhs

"""
    rhs_oop(sys::VectorFieldSystem{…,OutOfPlace,…}, [::Bool]) -> Function

Return the pre-built OOP RHS `(u, λ, t) -> du`.
The Bool argument is accepted for API uniformity but ignored.
"""
function rhs_oop(sys::VectorFieldSystem{F, TD, VD, Traits.OutOfPlace, RHS, OOPROHS, Nothing},
                 ::Bool = true) where {F, TD, VD, RHS, OOPROHS}
    return sys.rhs_oop
end

"""
    rhs_oop(sys::VectorFieldSystem{…,InPlace,…}, is_u0_mutable::Bool) -> Function

- `is_u0_mutable = true`  → `rhs_oop`  (allocates mutable buffer, returns it)
- `is_u0_mutable = false` → `rhs_oop_finalize`  (allocates, converts back to `typeof(u)`)

A warning is emitted for the immutable case to encourage switching to an OOP VF.
"""
function rhs_oop(sys::VectorFieldSystem{F, TD, VD, Traits.InPlace, RHS, OOPROHS, FINRHS},
                 is_u0_mutable::Bool = true) where {F, TD, VD, RHS, OOPROHS, FINRHS}
    is_u0_mutable && return sys.rhs_oop
    @warn "InPlace VectorField with immutable u0 (e.g. SVector): " *
          "prefer an out-of-place VectorField for better performance."
    return sys.rhs_oop_finalize
end

# =============================================================================
# build_problem  (SciML integrator side)
# =============================================================================
#
# Decision:
#   u0 mutable  →  f!(du,u,λ,t)  via rhs(sys)
#   u0 immutable →  f(u,λ,t)     via rhs_oop(sys, false)
#
# The VF mutability (InPlace/OutOfPlace) is transparent to the caller here;
# it was baked into the closures at construction time.

function Integrators.build_problem(
        integ  ::SciML,
        sys    ::VectorFieldSystem,
        config ::Common.AbstractConfig;
        variable,
        cache,
)
    u0 = Common.initial_condition(config)
    _check_vf_scalar_inplace(sys, u0)           # guard: IP VF + Number → error
    λ  = Common.ODEParameters(variable, cache)

    if ismutable(u0)
        return ODEProblem(rhs(sys), u0, Common.tspan(config), λ)
    else
        return ODEProblem(rhs_oop(sys, false), u0, Common.tspan(config), λ)
    end
end

# =============================================================================
# Base.show
# =============================================================================

function Base.show(io::IO, sys::VectorFieldSystem{F, TD, VD, MD}) where {F, TD, VD, MD}
    println(io, "VectorFieldSystem")
    print(io,   "  wraps: VectorField: ",
          Data._td_label(TD), ", ", Data._vd_label(VD), ", ", Data._md_label(MD))
end

Base.show(io::IO, ::MIME"text/plain", sys::VectorFieldSystem) = show(io, sys)
