# =============================================================================
# RHS Functors for HamiltonianSystem
# =============================================================================

# =============================================================================
# Abstract hierarchy
# =============================================================================

"""
$(TYPEDEF)

Abstract supertype for Hamiltonian right-hand side (RHS) functors.

RHS functors compute the derivatives for Hamiltonian systems according to
Hamilton's equations. The type parameter encodes the mutability trait
(in-place vs out-of-place) for compile-time dispatch.

# Type Parameters
- `T <: AbstractMutabilityTrait`: Mutability trait (`InPlace` or `OutOfPlace`).

# Interface Requirements

All subtypes must implement a callable interface:
- In-place: `(f::SubType)(du, u, λ, t)` for mutating output
- Out-of-place: `(f::SubType)(u, λ, t) -> du` for allocating output

# Notes
- Subtypes include [`CTFlows.Systems.AbstractIPHamRHS`](@ref) and [`CTFlows.Systems.AbstractOoPHamRHS`](@ref).
- These functors are created by `build_rhs` and related functions.

See also: [`CTFlows.Systems.AbstractRHS`](@ref), [`CTFlows.Systems.HamIpRHS`](@ref), [`CTFlows.Systems.HamOoPRHS`](@ref).
"""
abstract type AbstractHamRHS{T<:Traits.AbstractMutabilityTrait} <: AbstractRHS{T} end

"""
$(TYPEDEF)

Abstract supertype for in-place Hamiltonian RHS functors.

Subtypes of this abstract type implement in-place computation of Hamiltonian
derivatives, mutating the output vector `du` rather than allocating a new one.

# Notes
- All subtypes must implement `(f::SubType)(du, u, λ, t)`.
- Concrete subtypes include [`CTFlows.Systems.HamIpRHS`](@ref) and [`CTFlows.Systems.HamIpAugRHS`](@ref).

See also: [`CTFlows.Systems.AbstractHamRHS`](@ref), [`CTFlows.Systems.AbstractOoPHamRHS`](@ref).
"""
abstract type AbstractIPHamRHS <: AbstractHamRHS{Traits.InPlace} end

"""
$(TYPEDEF)

Abstract supertype for out-of-place Hamiltonian RHS functors.

Subtypes of this abstract type implement out-of-place computation of Hamiltonian
derivatives, allocating and returning a new output vector.

# Notes
- All subtypes must implement `(f::SubType)(u, λ, t) -> du`.
- Concrete subtypes include [`CTFlows.Systems.HamOoPRHS`](@ref).

See also: [`CTFlows.Systems.AbstractHamRHS`](@ref), [`CTFlows.Systems.AbstractIPHamRHS`](@ref).
"""
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
- This functor is created by `build_rhs` for Hamiltonian systems.

See also: [`CTFlows.Systems.HamOoPRHS`](@ref), [`CTFlows.Systems.HamIpAugRHS`](@ref).
"""
struct HamIpRHS{F,TD,VD,B,CX,CP} <: AbstractIPHamRHS
    h::Data.Hamiltonian{F,TD,VD}
    backend::B
    N::Int
    cx::CX
    cp::CP
end

function (f::HamIpRHS{F,TD,VD,B,CX,CP})(du, u, λ, t) where {F,TD,VD,B,CX,CP}
    x, p = _ham_split(u, f.N)
    ∂x, ∂p = Differentiation.hamiltonian_gradient(
        f.backend, f.h, t, f.cx(x), f.cp(p), variable(λ)
    )
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
- This functor is created by `build_oop_rhs` for Hamiltonian systems.

See also: [`CTFlows.Systems.HamIpRHS`](@ref), [`CTFlows.Systems.HamIpAugRHS`](@ref).
"""
struct HamOoPRHS{F,TD,VD,B,CX,CP} <: AbstractOoPHamRHS
    h::Data.Hamiltonian{F,TD,VD}
    backend::B
    N::Int
    cx::CX
    cp::CP
end

function (f::HamOoPRHS{F,TD,VD,B,CX,CP})(u, λ, t) where {F,TD,VD,B,CX,CP}
    x, p = _ham_split(u, f.N)
    ∂x, ∂p = Differentiation.hamiltonian_gradient(
        f.backend, f.h, t, f.cx(x), f.cp(p), variable(λ)
    )
    return vcat(∂p, -∂x)
end

# =============================================================================
# Augmented functor (for variable costate integration)
# =============================================================================

"""
Check batch size compatibility for augmented Hamiltonian RHS with matrix inputs.

When using batch mode with matrix inputs, ensures that the state matrix `u`
and variable matrix `v` have compatible batch sizes (same number of columns).

# Arguments
- `u::AbstractMatrix`: State matrix with shape `(n, batch_size)`.
- `v::AbstractMatrix`: Variable matrix with shape `(m, batch_size)`.

# Returns
- `nothing` if batch sizes match.

# Throws
- `Exceptions.PreconditionError`: If `size(u, 2) ≠ size(v, 2)`.

# Notes
- No-op for non-matrix inputs (vectors or scalars).
- Used internally by [`CTFlows.Systems.HamIpAugRHS`](@ref) to validate batch mode.

See also: [`CTFlows.Systems.HamIpAugRHS`](@ref), [`CTFlows.Systems._aug_split`](@ref).
"""
function _check_aug_batch_compat(u::AbstractMatrix, v::AbstractMatrix)
    if size(u, 2) != size(v, 2)
        throw(
            Exceptions.PreconditionError(
                "batch size mismatch in augmented Hamiltonian RHS";
                reason="size(u, 2) = $(size(u, 2)) ≠ size(v, 2) = $(size(v, 2))",
                context="HamIpAugRHS — matrix batch mode",
                suggestion="variable v must have the same number of columns as the state u",
            ),
        )
    end
    return nothing
end
"""
No-op version of batch compatibility check for non-matrix inputs.

# Arguments
- `u`: State input (vector or scalar).
- `v`: Variable input (vector or scalar).

# Returns
- `nothing`.

# Notes
- Used as fallback when inputs are not matrices.
- See [`CTFlows.Systems._check_aug_batch_compat(::AbstractMatrix, ::AbstractMatrix)`](@ref) for the matrix version.
"""
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
- This functor is created by `build_rhs_augmented` for Hamiltonian systems.

See also: [`CTFlows.Systems.HamIpRHS`](@ref), [`CTFlows.Systems.HamOoPRHS`](@ref).
"""
struct HamIpAugRHS{F,TD,VD,B,CX,CP} <: AbstractIPHamRHS
    h::Data.Hamiltonian{F,TD,VD}
    backend::B
    n_x::Int
    n_v::Int
    cx::CX
    cp::CP
end

function (f::HamIpAugRHS{F,TD,VD,B,CX,CP})(du, u, λ, t) where {F,TD,VD,B,CX,CP}
    v = variable(λ)
    _check_aug_batch_compat(u, v)
    x, p, _ = _aug_split(u, f.n_x, f.n_v)
    ∂x, ∂p = Differentiation.hamiltonian_gradient(f.backend, f.h, t, f.cx(x), f.cp(p), v)
    ∂pv = Differentiation.variable_gradient(f.backend, f.h, t, f.cx(x), f.cp(p), v)
    _aug_assign!(du, ∂p, -∂x, -∂pv, f.n_x, f.n_v)
    return nothing
end

# =============================================================================
# Display helpers
# =============================================================================

"""
Return a descriptive label for the RHS conversion performed by a Hamiltonian functor.

# Arguments
- `f::AbstractHamRHS`: The Hamiltonian RHS functor.

# Returns
- `String`: Description of the conversion (e.g., "Hamiltonian AD → in-place interface").

# Notes
- Used internally by `Base.show` for display.
- Different functors have different conversion labels.

See also: [`CTFlows.Systems.AbstractHamRHS`](@ref), [`CTFlows.Systems.HamIpRHS`](@ref), [`CTFlows.Systems.HamOoPRHS`](@ref).
"""
_rhs_conversion_label(::HamIpRHS) = "Hamiltonian AD → in-place interface"
_rhs_conversion_label(::HamOoPRHS) = "Hamiltonian AD → out-of-place interface"
_rhs_conversion_label(::HamIpAugRHS) = "Hamiltonian AD → in-place augmented interface"

function Base.show(io::IO, f::AbstractHamRHS)
    fmt = Display.format_codes(io)
    td = Traits.time_dependence(f.h)
    vd = Traits.variable_dependence(f.h)
    wraps = "Hamiltonian: $(Data._td_label(td)), $(Data._vd_label(vd))"
    Display.print_header(io, nameof(typeof(f)); fmt=fmt)
    Display.print_field(io, "wraps", wraps; fmt=fmt, value_style="")
    return Display.print_field(
        io, "converts", _rhs_conversion_label(f); last=true, fmt=fmt, value_style=""
    )
end

function Base.show(io::IO, ::MIME"text/plain", f::AbstractHamRHS)
    return show(io, f)
end
