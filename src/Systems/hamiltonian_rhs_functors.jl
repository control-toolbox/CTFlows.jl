# =============================================================================
# RHS Functors for HamiltonianSystem
# =============================================================================

# =============================================================================
# Abstract hierarchy
# =============================================================================

abstract type AbstractHamRHS{T<:Traits.AbstractMutabilityTrait} <: AbstractRHS{T} end

abstract type AbstractIPHamRHS <: AbstractHamRHS{Traits.InPlace} end

abstract type AbstractOoPHamRHS <: AbstractHamRHS{Traits.OutOfPlace} end

# =============================================================================
# Standard functors (constructed at build_rhs/build_oop_rhs time)
# =============================================================================

"""
$(TYPEDEF)

In-place RHS functor for Hamiltonian systems with automatic differentiation.

This functor wraps a Hamiltonian and AD backend to compute the Hamiltonian
gradient in-place, following the canonical Hamiltonian equations:

```
ẋ =  ∂H/∂p
ṗ = -∂H/∂x
```

# Fields
- `h::Data.Hamiltonian{F,TD,VD}`: The Hamiltonian function.
- `backend::B`: The AD backend for gradient computation.
- `N::Int`: State dimension (number of state variables).
- `cx::CX`: State conversion function.
- `cp::CP`: Costate conversion function.
- `cache::C`: Pre-allocated AD cache (or `nothing` for systems without AD).

# Call Signature
```julia
(f::HamIpRHS)(du, u, λ, t)
```

- `du`: Output vector (mutated in-place).
- `u`: State vector `[x; p]` (concatenated state and costate).
- `λ`: ODE parameters containing the variable value.
- `t`: Time (for non-autonomous systems).

# Notes
- The AD cache is embedded in the functor for better composability.
- This functor is created by [`CTFlows.Systems.build_rhs`](@ref) for Hamiltonian systems.

See also: [`CTFlows.Systems.HamOoPRHS`](@ref), [`CTFlows.Systems.HamIpAugRHS`](@ref).
"""
struct HamIpRHS{F,TD,VD,B,CX,CP,C} <: AbstractIPHamRHS
    h::Data.Hamiltonian{F,TD,VD}
    backend::B
    N::Int
    cx::CX
    cp::CP
    cache::C
end

function (f::HamIpRHS{F,TD,VD,B,CX,CP,C})(du, u, λ, t) where {F,TD,VD,B,CX,CP,C}
    x, p = _ham_split(u, f.N)
    ∂x, ∂p = Differentiation.hamiltonian_gradient(
        f.backend, f.h, t, f.cx(x), f.cp(p), Common.variable(λ), f.cache)
    _ham_assign!(du, ∂p, -∂x, f.N)
    return nothing
end

"""
$(TYPEDEF)

Out-of-place RHS functor for Hamiltonian systems with automatic differentiation.

This functor wraps a Hamiltonian and AD backend to compute the Hamiltonian
gradient out-of-place, following the canonical Hamiltonian equations:

```
ẋ =  ∂H/∂p
ṗ = -∂H/∂x
```

# Fields
- `h::Data.Hamiltonian{F,TD,VD}`: The Hamiltonian function.
- `backend::B`: The AD backend for gradient computation.
- `N::Int`: State dimension (number of state variables).
- `cx::CX`: State conversion function.
- `cp::CP`: Costate conversion function.
- `cache::C`: Pre-allocated AD cache (or `nothing` for systems without AD).

# Call Signature
```julia
(f::HamOoPRHS)(u, λ, t) -> du
```

- `u`: State vector `[x; p]` (concatenated state and costate).
- `λ`: ODE parameters containing the variable value.
- `t`: Time (for non-autonomous systems).
- Returns: Output vector `du = [∂p; -∂x]`.

# Notes
- The AD cache is embedded in the functor for better composability.
- This functor is created by [`CTFlows.Systems.build_oop_rhs`](@ref) for Hamiltonian systems.

See also: [`CTFlows.Systems.HamIpRHS`](@ref), [`CTFlows.Systems.HamIpAugRHS`](@ref).
"""
struct HamOoPRHS{F,TD,VD,B,CX,CP,C} <: AbstractOoPHamRHS
    h::Data.Hamiltonian{F,TD,VD}
    backend::B
    N::Int
    cx::CX
    cp::CP
    cache::C
end

function (f::HamOoPRHS{F,TD,VD,B,CX,CP,C})(u, λ, t) where {F,TD,VD,B,CX,CP,C}
    x, p = _ham_split(u, f.N)
    ∂x, ∂p = Differentiation.hamiltonian_gradient(
        f.backend, f.h, t, f.cx(x), f.cp(p), Common.variable(λ), f.cache)
    return vcat(∂p, -∂x)
end

# =============================================================================
# Augmented functor (for variable costate integration)
# =============================================================================

function _check_aug_batch_compat(u::AbstractMatrix, v::AbstractMatrix)
    if size(u, 2) != size(v, 2)
        throw(Exceptions.PreconditionError(
            "batch size mismatch in augmented Hamiltonian RHS";
            reason    = "size(u, 2) = $(size(u, 2)) ≠ size(v, 2) = $(size(v, 2))",
            context   = "HamIpAugRHS — matrix batch mode",
            suggestion = "variable v must have the same number of columns as the state u",
        ))
    end
    return nothing
end
_check_aug_batch_compat(u, v) = nothing   # no-op for non-matrix cases

"""
$(TYPEDEF)

In-place augmented RHS functor for Hamiltonian systems with variable costate.

This functor extends the standard Hamiltonian equations to include the variable
costate evolution, used in sensitivity analysis and optimal control:

```
ẋ =  ∂H/∂p
ṗ = -∂H/∂x
ṽ = -∂H/∂v
```

The state vector is augmented as `[x; p; v]` where `v` is the variable costate.

# Fields
- `h::Data.Hamiltonian{F,TD,VD}`: The Hamiltonian function.
- `backend::B`: The AD backend for gradient computation.
- `n_x::Int`: State dimension (number of state variables).
- `n_v::Int`: Variable dimension.
- `cache::C`: Pre-allocated AD cache (or `nothing` for systems without AD).

# Call Signature
```julia
(f::HamIpAugRHS)(du, u, λ, t)
```

- `du`: Output vector (mutated in-place).
- `u`: Augmented state vector `[x; p; v]`.
- `λ`: ODE parameters containing the variable value.
- `t`: Time (for non-autonomous systems).

# Notes
- Supports batch mode with matrix inputs (checks batch size compatibility).
- The AD cache is embedded in the functor for better composability.
- This functor is created by [`CTFlows.Systems.build_rhs_augmented`](@ref) for Hamiltonian systems.

See also: [`CTFlows.Systems.HamIpRHS`](@ref), [`CTFlows.Systems.HamOoPRHS`](@ref).
"""
struct HamIpAugRHS{F,TD,VD,B,C} <: AbstractIPHamRHS
    h::Data.Hamiltonian{F,TD,VD}
    backend::B
    n_x::Int
    n_v::Int
    cache::C
end

function (f::HamIpAugRHS{F,TD,VD,B,C})(du, u, λ, t) where {F,TD,VD,B,C}
    v = Common.variable(λ)
    _check_aug_batch_compat(u, v)
    x, p, _ = _aug_split(u, f.n_x, f.n_v)
    ∂x, ∂p = Differentiation.hamiltonian_gradient(f.backend, f.h, t, x, p, v, f.cache)
    ∂pv = Differentiation.variable_gradient(f.backend, f.h, t, x, p, v, f.cache)
    _aug_assign!(du, ∂p, -∂x, -∂pv, f.n_x, f.n_v)
    return nothing
end

# =============================================================================
# Display helpers
# =============================================================================

_rhs_conversion_label(::HamIpRHS) = "Hamiltonian AD → in-place interface"
_rhs_conversion_label(::HamOoPRHS) = "Hamiltonian AD → out-of-place interface"
_rhs_conversion_label(::HamIpAugRHS) = "Hamiltonian AD → in-place augmented interface"

function Base.show(io::IO, f::AbstractHamRHS)
    println(io, nameof(typeof(f)))
    td = Traits.time_dependence(f.h)
    vd = Traits.variable_dependence(f.h)
    println(io, "  wraps: Hamiltonian: $(Data._td_label(td)), $(Data._vd_label(vd))")
    print(io,   "  converts: ", _rhs_conversion_label(f))
end

function Base.show(io::IO, ::MIME"text/plain", f::AbstractHamRHS)
    show(io, f)
end
