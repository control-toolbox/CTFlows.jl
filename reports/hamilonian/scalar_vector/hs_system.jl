# =============================================================================
# HamiltonianSystem (AD-based, scalar Hamiltonian + gradient via backend)
# =============================================================================
#
# Design rationale
# ────────────────
# Same split / coerce strategy as HamiltonianVectorFieldSystem.
# No InPlace/OutOfPlace distinction: the Hamiltonian h is always scalar-valued,
# gradients are computed by the AD backend and always returned as plain vectors.
#
# Non-augmented case  u = [x; p]
#   → build_rhs / build_oop_rhs, lazy in build_problem
#
# Augmented case  u = [x; p; pv]   (variable costate)
#   → build_rhs_augmented(sys, n_x, n_v), already lazy (called from build_problem)
#   → matrix batch mode (x0 :: AbstractMatrix) is NOT supported here because
#     the meaning of pv per column is undefined for the current AD backends.
#     An explicit error is raised in build_problem.
# =============================================================================

struct HamiltonianSystem{
        N,
        F       <: Function,
        TD      <: Traits.TimeDependence,
        VD      <: Traits.VariableDependence,
        BACKEND <: Differentiation.AbstractADBackend,
        RHS     <: Function,
        OOPROHS <: Function,
} <: AbstractHamiltonianSystem{TD, VD, Traits.WithAD}
    h       ::Data.Hamiltonian{F, TD, VD}
    backend ::BACKEND
    rhs     ::RHS       # kept for non-lazy callers that don't have x0/p0 handy
    rhs_oop ::OOPROHS
end

# N is kept as a type parameter for the non-lazy pre-built path (legacy).
# For the lazy path N is determined from x0 at build_problem time.

function HamiltonianSystem(h::Data.Hamiltonian{F,TD,VD},
                           backend::Differentiation.AbstractADBackend;
                           state_dimension::Union{Int,Nothing}=Common.__state_dimension()) where {F,TD,VD}
    rhs     = _build_ip_rhs_hs(h, backend, state_dimension)
    rhs_oop = _build_oop_rhs_hs(h, backend, state_dimension)
    return HamiltonianSystem{state_dimension, F, TD, VD, typeof(backend),
                             typeof(rhs), typeof(rhs_oop)}(h, backend, rhs, rhs_oop)
end

hamiltonian(sys::HamiltonianSystem) = sys.h
backend(sys::HamiltonianSystem)     = sys.backend
state_dimension(::HamiltonianSystem{N}) where N = N

# =============================================================================
# _ham_split / _ham_assign! and IC helpers
# (shared with HamiltonianVectorFieldSystem; defined in the same module)
# =============================================================================
# _state_dim, _make_coerce, _ham_split, _ham_assign! — see HamiltonianVectorFieldSystem file.

# Additional split for the augmented state u = [x; p; pv]
_aug_split(u::AbstractVector, nx::Int, nv::Int) = (
    @view(u[1:nx]),
    @view(u[nx+1:2nx]),
    @view(u[end-nv+1:end]),
)
_aug_split(u::AbstractMatrix, nx::Int, nv::Int) = (
    @view(u[1:nx, :]),
    @view(u[nx+1:2nx, :]),
    @view(u[end-nv+1:end, :]),
)

_aug_assign!(du::AbstractVector, dx, dp, dpv, nx::Int, nv::Int) = (
    du[1:nx] .= dx; du[nx+1:2nx] .= dp; du[end-nv+1:end] .= dpv
)
_aug_assign!(du::AbstractMatrix, dx, dp, dpv, nx::Int, nv::Int) = (
    du[1:nx,:] .= dx; du[nx+1:2nx,:] .= dp; du[end-nv+1:end,:] .= dpv
)

# =============================================================================
# Non-augmented RHS builders (legacy pre-built path, N may be Int or nothing)
# =============================================================================

function _build_ip_rhs_hs(h, backend, N)
    return function (du, u, λ, t)
        x, p   = _ham_split(u, N)
        ∂x, ∂p = Differentiation.hamiltonian_gradient(
                     backend, h, t, x, p, Common.variable(λ), Common.cache(λ))
        _ham_assign!(du, ∂p, -∂x, N)
        return nothing
    end
end

function _build_oop_rhs_hs(h, backend, N)
    return function (u, λ, t)
        x, p   = _ham_split(u, N)
        ∂x, ∂p = Differentiation.hamiltonian_gradient(
                     backend, h, t, x, p, Common.variable(λ), Common.cache(λ))
        return vcat(∂p, -∂x)
    end
end

# =============================================================================
# Lazy non-augmented RHS builders (called from build_problem with x0, p0)
# =============================================================================
#
# These supersede the pre-built closures when x0/p0 are available.
# Coerce is applied to inputs only; gradients are always plain vectors.

function build_rhs(sys::HamiltonianSystem, x0, p0)
    h, backend = sys.h, sys.backend
    N, cx, cp  = _state_dim(x0), _make_coerce(x0), _make_coerce(p0)
    return function (du, u, λ, t)
        xv, pv = _ham_split(u, N)
        ∂x, ∂p = Differentiation.hamiltonian_gradient(
                     backend, h, t, cx(xv), cp(pv), Common.variable(λ), Common.cache(λ))
        _ham_assign!(du, ∂p, -∂x, N)
        return nothing
    end
end

function build_oop_rhs(sys::HamiltonianSystem, x0, p0)
    h, backend = sys.h, sys.backend
    N, cx, cp  = _state_dim(x0), _make_coerce(x0), _make_coerce(p0)
    return function (u, λ, t)
        xv, pv = _ham_split(u, N)
        ∂x, ∂p = Differentiation.hamiltonian_gradient(
                     backend, h, t, cx(xv), cp(pv), Common.variable(λ), Common.cache(λ))
        return typeof(u)(vcat(∂p, -∂x))   # preserve type for immutable u (SVector)
    end
end

# =============================================================================
# Augmented RHS builder (variable-costate integration)
# =============================================================================
#
# u = [x; p; pv]
# du/dt = [∂H/∂p; -∂H/∂x; -∂H/∂v]
#
# ⚠ Matrix batch mode is NOT supported: if x0 is a matrix each column would
#   need its own pv, requiring a (nv, K) block in u. The current AD backends
#   (hamiltonian_gradient, variable_gradient) are not defined for this layout.
#   build_problem raises a NotImplemented error in that case.
#
# Batch-size consistency for the variable v (if it arrives as a matrix column)
# is checked at runtime via _check_aug_batch_compat.

function _check_aug_batch_compat(u::AbstractMatrix, v::AbstractMatrix)
    size(u, 2) == size(v, 2) && return nothing
    throw(Exceptions.PreconditionError(
        "batch size mismatch in augmented Hamiltonian RHS";
        reason     = "size(u,2)=$(size(u,2)) ≠ size(v,2)=$(size(v,2))",
        context    = "HamiltonianSystem.build_rhs_augmented — matrix batch mode",
        suggestion = "variable v must have the same number of columns as the state u",
    ))
end
_check_aug_batch_compat(::Any, ::Any) = nothing   # no-op for non-matrix cases

"""
    build_rhs_augmented(sys::HamiltonianSystem, n_x::Int, n_v::Int) -> f!(du,u,λ,t)

Build the in-place RHS for the augmented Hamiltonian system
`u = [x; p; pv]` where `pv` is the variable costate.

`n_x` and `n_v` are the dimensions of the state and variable respectively.
"""
function build_rhs_augmented(sys::HamiltonianSystem, n_x::Int, n_v::Int)
    h, backend = sys.h, sys.backend
    return function (du, u, λ, t)
        v = Common.variable(λ)
        _check_aug_batch_compat(u, v)
        x, p, _  = _aug_split(u, n_x, n_v)
        ∂x, ∂p   = Differentiation.hamiltonian_gradient(
                       backend, h, t, x, p, v, Common.cache(λ))
        ∂pv      = Differentiation.variable_gradient(
                       backend, h, t, x, p, v, Common.cache(λ))
        _aug_assign!(du, ∂p, -∂x, -∂pv, n_x, n_v)
        return nothing
    end
end

# =============================================================================
# Legacy accessors (pre-built closures, used when x0/p0 are not available)
# =============================================================================

rhs(sys::HamiltonianSystem)                          = sys.rhs
rhs_oop(sys::HamiltonianSystem, ::Bool = true)       = sys.rhs_oop

# =============================================================================
# build_problem  (SciML integrator side)
# =============================================================================

# ── Non-augmented ─────────────────────────────────────────────────────────────

function Integrators.build_problem(
        integ  ::SciML,
        sys    ::HamiltonianSystem,
        config ::Common.AbstractHamiltonianConfig;
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

# ── Augmented ─────────────────────────────────────────────────────────────────

function Integrators.build_problem(
        integ  ::SciML,
        sys    ::HamiltonianSystem,
        config ::Common.AbstractAugmentedHamiltonianConfig;
        variable,
        cache,
)
    x0  = Common.initial_state(config)
    u0  = Common.initial_condition(config)   # = vcat(x0, p0, pv0)
    λ   = Common.ODEParameters(variable, cache)

    # Matrix batch mode is not supported for the augmented system.
    if x0 isa AbstractMatrix
        throw(Exceptions.NotImplemented(
            "Augmented Hamiltonian flow with matrix initial condition";
            reason = "The variable costate pv layout in [x; p; pv] is ambiguous " *
                     "for batch (matrix) inputs: each column of x would need its " *
                     "own pv block, which is not supported by the current AD backends.",
            suggestion = "Use a vector x0 and loop over initial conditions, or " *
                         "contact the CTFlows maintainers to discuss batch support.",
        ))
    end

    n_x = _state_dim(x0)
    n_v = length(Common.initial_variable_costate(config))
    f!  = build_rhs_augmented(sys, n_x, n_v)
    return ODEProblem(f!, u0, Common.tspan(config), λ)
end

# =============================================================================
# Trait getter
# =============================================================================

function Traits.variable_costate_trait(
        ::HamiltonianSystem{N, F, TD, Traits.NonFixed, B, R, O}) where {N, F, TD, B, R, O}
    return Traits.SupportsVariableCostate
end

# =============================================================================
# Base.show
# =============================================================================

function Base.show(io::IO, sys::HamiltonianSystem{N, F, TD, VD, B}) where {N, F, TD, VD, B}
    println(io, "HamiltonianSystem")
    println(io, "  state_dimension: ", N === nothing ? "unknown" : N)
    println(io, "  wraps: Hamiltonian: ", Data._td_label(TD), ", ", Data._vd_label(VD))
    print(io,   "  backend: ", B)
end

Base.show(io::IO, ::MIME"text/plain", sys::HamiltonianSystem) = show(io, sys)
