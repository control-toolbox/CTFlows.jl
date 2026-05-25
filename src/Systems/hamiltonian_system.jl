# =============================================================================
# HamiltonianSystem — AD-based Hamiltonian system with scalar Hamiltonian function
# =============================================================================

"""
$(TYPEDEF)

Concrete `AbstractHamiltonianSystem` wrapping a scalar `Hamiltonian` function with an AD backend.
The state dimension `N` is stored as a type parameter for compile-time validation and performance.
If `N=nothing`, the dimension is inferred at runtime.

# Type Parameters
- `N`: State dimension (`Int` if known, `nothing` if unknown).
- `F`: concrete type of the wrapped Hamiltonian function.
- `TD <: TimeDependence`: `Autonomous` or `NonAutonomous`.
- `VD <: VariableDependence`: `Fixed` or `NonFixed`.
- `BACKEND <: AbstractADBackend`: concrete AD backend type.
- `RHS`: type of the pre-computed in-place right-hand side function.
- `OOPROHS`: type of the pre-computed out-of-place right-hand side function.

# Fields
- `h::Hamiltonian{F, TD, VD}`: the underlying scalar Hamiltonian function.
- `backend::BACKEND`: the AD backend for gradient computation.
- `rhs::RHS`: the pre-computed in-place right-hand side closure with signature `(du, u, p, t) -> nothing`.
- `rhs_oop::OOPROHS`: the pre-computed out-of-place right-hand side closure with signature `(u, p, t) -> du`.

# Example
```julia-repl
julia> using CTFlows.Systems, CTFlows.Common, CTFlows.Data

julia> h = Hamiltonian((t, x, p, v) -> 0.5 * sum(x.^2) + sum(p.^2); autonomous=true, variable=false)
Hamiltonian{var"#1", Autonomous, Fixed}

julia> sys = HamiltonianSystem(h, AutoForwardDiff(); state_dimension=3)
HamiltonianSystem
  time_dependence: Autonomous
  variable_dependence: Fixed
  state_dimension: 3
  hamiltonian: Hamiltonian{var"#1", Autonomous, Fixed}
  backend: AutoForwardDiff()
```

See also: [`CTFlows.Data.Hamiltonian`](@ref), [`CTFlows.Systems.AbstractHamiltonianSystem`](@ref), [`CTFlows.Traits.AbstractADTrait`](@ref).
"""
struct HamiltonianSystem{
    N,
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    BACKEND<:Differentiation.AbstractADBackend,
    RHS<:Function,
    OOPROHS<:Function,
} <: AbstractHamiltonianSystem{TD, VD, Traits.WithAD}
    h::Data.Hamiltonian{F, TD, VD}
    backend::BACKEND
    rhs::RHS
    rhs_oop::OOPROHS
end

function hamiltonian(sys::HamiltonianSystem)
    return sys.h
end

function backend(sys::HamiltonianSystem)
    return sys.backend
end

# =============================================================================
# Constructors
# =============================================================================

function HamiltonianSystem(h::Data.Hamiltonian{F,TD,VD}, backend::Differentiation.AbstractADBackend;
                           state_dimension::Union{Int,Nothing}=Common.__state_dimension()) where {F,TD,VD}
    rhs     = _build_rhs_hs(h, backend, Val(state_dimension))
    rhs_oop = _build_oop_rhs_hs(h, backend, Val(state_dimension))
    return HamiltonianSystem{state_dimension, F, TD, VD, typeof(backend),
                             typeof(rhs), typeof(rhs_oop)}(h, backend, rhs, rhs_oop)
end

# =============================================================================
# Internal helpers for augmented split/assign (Vector + Matrix, concrete integers)
# =============================================================================

_aug_split(u::AbstractVector, n_x::Int, n_v::Int) =
    (@view(u[1:n_x]), @view(u[n_x+1:2*n_x]), @view(u[end-n_v+1:end]))
_aug_split(u::AbstractMatrix, n_x::Int, n_v::Int) =
    (@view(u[1:n_x,:]), @view(u[n_x+1:2*n_x,:]), @view(u[end-n_v+1:end,:]))

_aug_assign!(du::AbstractVector, dx, dp, dpv, n_x::Int, n_v::Int) =
    (du[1:n_x] .= dx; du[n_x+1:2*n_x] .= dp; du[end-n_v+1:end] .= dpv)
_aug_assign!(du::AbstractMatrix, dx, dp, dpv, n_x::Int, n_v::Int) =
    (du[1:n_x,:] .= dx; du[n_x+1:2*n_x,:] .= dp; du[end-n_v+1:end,:] .= dpv)

# =============================================================================
# Internal helpers for building RHS (in-place)
# =============================================================================

function _build_rhs_hs(h, backend, ::Val{N}) where N
    return function (du, u, λ, t)
        x, p   = _ham_split(u, N)
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, t, x, p, Common.variable(λ), Common.cache(λ))
        _ham_assign!(du, ∂p, -∂x, N)
        return nothing
    end
end

# =============================================================================
# Internal helpers for building RHS (out-of-place)
# =============================================================================

function _build_oop_rhs_hs(h, backend, ::Val{N}) where N
    return function (u, λ, t)
        x, p   = _ham_split(u, N)
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, t, x, p, Common.variable(λ), Common.cache(λ))
        return vcat(∂p, -∂x)
    end
end

# =============================================================================
# Batch compatibility check for augmented RHS
# =============================================================================

function _check_aug_batch_compat(u::AbstractMatrix, v::AbstractMatrix)
    if size(u, 2) != size(v, 2)
        throw(Exceptions.PreconditionError(
            "batch size mismatch in augmented Hamiltonian RHS";
            reason    = "size(u, 2) = $(size(u, 2)) ≠ size(v, 2) = $(size(v, 2))",
            context   = "build_rhs_augmented — matrix batch mode",
            suggestion = "variable v must have the same number of columns as the state u",
        ))
    end
    return nothing
end
_check_aug_batch_compat(u, v) = nothing   # no-op for non-matrix cases

# =============================================================================
# build_rhs_augmented — lazy, closes over concrete n_x and n_v
# =============================================================================

function build_rhs_augmented(sys::HamiltonianSystem, n_x::Int, n_v::Int)
    h, backend = sys.h, sys.backend
    return function (du, u, λ, t)
        v = Common.variable(λ)
        _check_aug_batch_compat(u, v)             # no-op if not matrix or matrix compatible
        x, p, _ = _aug_split(u, n_x, n_v)
        ∂x, ∂p   = Differentiation.hamiltonian_gradient(backend, h, t, x, p, v, Common.cache(λ))
        ∂pv      = Differentiation.variable_gradient(backend, h, t, x, p, v, Common.cache(λ))
        _aug_assign!(du, ∂p, -∂x, -∂pv, n_x, n_v)
        return nothing
    end
end

# =============================================================================
# rhs accessor (in-place)
# =============================================================================

function rhs(sys::HamiltonianSystem)
    return sys.rhs
end

# =============================================================================
# rhs_oop accessor (out-of-place)
# =============================================================================

function rhs_oop(sys::HamiltonianSystem, is_u0_mutable::Bool=true)
    return sys.rhs_oop
end

# =============================================================================
# state_dimension accessor
# =============================================================================

function state_dimension(sys::HamiltonianSystem{N}) where N
    return N
end

# =============================================================================
# Validation
# =============================================================================

function _check_state_dimension(sys::HamiltonianSystem{N}, x0) where N
    if N !== nothing && length(x0) != N
        throw(Exceptions.PreconditionError(
            "state dimension mismatch";
            reason    = "length(x0) = $(length(x0)) ≠ N = $N",
            context   = "HamiltonianSystem construction with known dimension",
            suggestion = "either omit state_dimension or ensure length(x0) matches the specified dimension",
        ))
    end
    return nothing
end

# =============================================================================
# Base.show
# =============================================================================

function Base.show(io::IO, sys::HamiltonianSystem)
    println(io, "HamiltonianSystem")
    println(io, "  time_dependence: ", Traits.time_dependence(sys))
    println(io, "  variable_dependence: ", Traits.variable_dependence(sys))
    println(io, "  state_dimension: ", sys.N === nothing ? "unknown" : sys.N)
    println(io, "  hamiltonian: ", sys.h)
    println(io, "  backend: ", sys.backend)
end

# =============================================================================
# Trait getters
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the variable costate capability trait of a variable-dependent Hamiltonian system.

# Arguments
- `sys::HamiltonianSystem`: A Hamiltonian system with variable dependence.

# Returns
- `SupportsVariableCostate` if the system has `NonFixed` variable dependence.
- `NoVariableCostate` if the system has `Fixed` variable dependence.

# Notes
- Only `HamiltonianSystem` with `NonFixed` variable dependence supports variable costate integration
- This is because only variable-dependent systems have a variable `v` to differentiate against
- This trait enables the `variable_costate=true` kwarg in Hamiltonian flow calls

See also: [`CTFlows.Traits.AbstractVariableCostateCapability`](@ref), [`CTFlows.Traits.SupportsVariableCostate`](@ref), [`CTFlows.Traits.NoVariableCostate`](@ref).
"""
function Traits.variable_costate_trait(
    ::HamiltonianSystem{N, F, TD, Traits.NonFixed, B, R, O}
) where {N, F, TD, B, R, O}
    return Traits.SupportsVariableCostate
end
