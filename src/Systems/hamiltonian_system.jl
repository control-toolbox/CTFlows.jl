# =============================================================================
# HamiltonianSystem — AD-based Hamiltonian system with scalar Hamiltonian function
# =============================================================================

"""
$(TYPEDEF)

Concrete `AbstractHamiltonianSystem` wrapping a scalar `Hamiltonian` function with an AD backend.

The system does not store pre-computed RHS closures. Instead, closures are built
lazily by `build_rhs` and `build_oop_rhs` based on the actual initial condition
types, ensuring correct handling of scalar, vector (including length-1), and matrix
inputs with consistent output shapes.

# Type Parameters
- `F`: concrete type of the wrapped Hamiltonian function.
- `TD <: TimeDependence`: `Autonomous` or `NonAutonomous`.
- `VD <: VariableDependence`: `Fixed` or `NonFixed`.
- `BACKEND <: AbstractADBackend`: concrete AD backend type.

# Fields
- `h::Hamiltonian{F, TD, VD}`: the underlying scalar Hamiltonian function.
- `backend::BACKEND`: the AD backend for gradient computation.

# Example
```julia-repl
julia> using CTFlows.Systems, CTFlows.Common, CTFlows.Data

julia> h = Hamiltonian((t, x, p, v) -> 0.5 * sum(x.^2) + sum(p.^2); autonomous=true, variable=false)
Hamiltonian{var"#1", Autonomous, Fixed}

julia> sys = HamiltonianSystem(h, AutoForwardDiff())
HamiltonianSystem
  time_dependence: Autonomous
  variable_dependence: Fixed
  hamiltonian: Hamiltonian{var"#1", Autonomous, Fixed}
  backend: AutoForwardDiff()
```

See also: [`CTFlows.Data.Hamiltonian`](@ref), [`CTFlows.Systems.AbstractHamiltonianSystem`](@ref), [`CTFlows.Traits.AbstractADTrait`](@ref), [`CTFlows.Systems.build_rhs`](@ref), [`CTFlows.Systems.build_oop_rhs`](@ref).
"""
struct HamiltonianSystem{
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    BACKEND<:Differentiation.AbstractADBackend,
} <: AbstractHamiltonianSystem{TD, VD, Traits.WithAD}
    h::Data.Hamiltonian{F, TD, VD}
    backend::BACKEND
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

function HamiltonianSystem(h::Data.Hamiltonian{F,TD,VD}, backend::Differentiation.AbstractADBackend) where {F,TD,VD}
    return HamiltonianSystem{F, TD, VD, typeof(backend)}(h, backend)
end

# =============================================================================
# Public lazy RHS builders
# =============================================================================

"""
    build_rhs(sys::HamiltonianSystem, x0, p0) -> f!(du, u, λ, t)

Build an in-place RHS closure for the given initial conditions.

The closure is constructed lazily based on the shapes of `x0` and `p0`,
ensuring correct handling of scalar, vector, and matrix inputs.

# Arguments
- `sys::HamiltonianSystem`: The Hamiltonian system.
- `x0`: Initial state (scalar, vector, or matrix).
- `p0`: Initial costate (same shape as `x0`).

# Returns
- `Function`: A closure with signature `(du, u, λ, t) -> nothing`.
"""
function build_rhs(sys::HamiltonianSystem, x0, p0)
    N = _state_dim(x0)
    cx = Common.make_coerce(x0)
    cp = Common.make_coerce(p0)
    h, backend = sys.h, sys.backend
    return function (du, u, λ, t)
        x, p   = _ham_split(u, N)
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, t, cx(x), cp(p), Common.variable(λ), Common.cache(λ))
        _ham_assign!(du, ∂p, -∂x, N)
        return nothing
    end
end

"""
    build_oop_rhs(sys::HamiltonianSystem, x0, p0) -> f(u, λ, t)

Build an out-of-place RHS closure for the given initial conditions.

The closure is constructed lazily based on the shapes of `x0` and `p0`,
ensuring correct handling of scalar, vector, and matrix inputs.

# Arguments
- `sys::HamiltonianSystem`: The Hamiltonian system.
- `x0`: Initial state (scalar, vector, or matrix).
- `p0`: Initial costate (same shape as `x0`).

# Returns
- `Function`: A closure with signature `(u, λ, t) -> du`.
"""
function build_oop_rhs(sys::HamiltonianSystem, x0, p0)
    N = _state_dim(x0)
    cx = Common.make_coerce(x0)
    cp = Common.make_coerce(p0)
    h, backend = sys.h, sys.backend
    return function (u, λ, t)
        x, p   = _ham_split(u, N)
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, t, cx(x), cp(p), Common.variable(λ), Common.cache(λ))
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
# Base.show
# =============================================================================

function Base.show(io::IO, sys::HamiltonianSystem)
    println(io, "HamiltonianSystem")
    println(io, "  time_dependence: ", Traits.time_dependence(sys))
    println(io, "  variable_dependence: ", Traits.variable_dependence(sys))
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
    ::HamiltonianSystem{F, TD, Traits.NonFixed, B}
) where {F, TD, B}
    return Traits.SupportsVariableCostate
end
