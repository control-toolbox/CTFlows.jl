"""
$(TYPEDEF)

Concrete `AbstractHamiltonianSystem` wrapping a `HamiltonianVectorField`.

The system does not store pre-computed RHS closures. Instead, closures are built
lazily by `build_rhs` and `build_oop_rhs` based on the actual initial condition
types, ensuring correct handling of scalar, vector (including length-1), and matrix
inputs with consistent output shapes.

# Type Parameters
- `F`: concrete type of the wrapped HamiltonianVectorField function.
- `TD <: TimeDependence`: `Autonomous` or `NonAutonomous`.
- `VD <: VariableDependence`: `Fixed` or `NonFixed`.
- `MD <: AbstractMutabilityTrait`: `InPlace` or `OutOfPlace`.

# Fields
- `hvf::HamiltonianVectorField{F, TD, VD, MD}`: the underlying Hamiltonian vector field.

# Example
```julia-repl
julia> using CTFlows.Systems, CTFlows.Common

julia> hvf = HamiltonianVectorField((x, p) -> (x, -p); autonomous=true, variable=false)
HamiltonianVectorField
  time_dependence: Autonomous
  variable_dependence: Fixed
  mutability: OutOfPlace
  function: var"#1"

julia> sys = HamiltonianVectorFieldSystem(hvf)
HamiltonianVectorFieldSystem
  time_dependence: Autonomous
  variable_dependence: Fixed
  mutability: OutOfPlace
  hamiltonian_vector_field: HamiltonianVectorField{var"#1", Autonomous, Fixed, OutOfPlace}
```

See also: [`CTBase.Data.HamiltonianVectorField`](@ref), [`CTFlows.Systems.AbstractHamiltonianSystem`](@ref), `TimeDependence`, [`CTBase.Traits.VariableDependence`](@ref), [`CTFlows.Systems.build_rhs`](@ref), [`CTFlows.Systems.build_oop_rhs`](@ref).
"""
struct HamiltonianVectorFieldSystem{
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    MD<:Traits.AbstractMutabilityTrait,
} <: AbstractHamiltonianSystem{TD,VD}
    hvf::Data.HamiltonianVectorField{F,TD,VD,MD}
end

Traits.ad_trait(::HamiltonianVectorFieldSystem) = Traits.WithoutAD

# =============================================================================
# Constructors
# =============================================================================

function HamiltonianVectorFieldSystem(
    hvf::Data.HamiltonianVectorField{F,TD,VD,MD}
) where {F,TD,VD,MD}
    return HamiltonianVectorFieldSystem{F,TD,VD,MD}(hvf)
end

# =============================================================================
# Internal helpers for shape inference and coercion
# =============================================================================

"""
    _state_dim(x0::Number) = 1
    _state_dim(x0::AbstractVector) = length(x0)
    _state_dim(x0::AbstractMatrix) = size(x0, 1)

Infer the state dimension from the initial condition shape.
"""
_state_dim(::Number) = 1
_state_dim(x::AbstractVector) = length(x)
_state_dim(x::AbstractMatrix) = size(x, 1)

# =============================================================================
# Internal helpers for split/assign (dispatch on array type)
# =============================================================================

"""
$(TYPEDSIGNATURES)

Split a combined state `u` into state `x` and costate `p` views for Hamiltonian systems.

Dispatches on the array type (`AbstractVector` or `AbstractMatrix`) and the known dimension `N` (or `nothing` for runtime inference).

# Arguments
- `u::AbstractVector` or `AbstractMatrix`: Combined state vector/matrix `[x; p]`.
- `N::Int` or `nothing`: State dimension. If `nothing`, infers as `size(u, 1) ÷ 2`.

# Returns
- `Tuple`: Tuple of views `(x_view, p_view)` where:
  - For vectors: `x_view = @view(u[1:N])`, `p_view = @view(u[N+1:2N])`
  - For matrices: `x_view = @view(u[1:N, :])`, `p_view = @view(u[N+1:2N, :])`

# Notes
- Internal helper used by RHS builders for Hamiltonian systems.
- The `CTFlowsStaticArrays` extension provides a type-stable method for `StaticVector`.
"""
_ham_split(u::AbstractVector, N::Int) = (@view(u[1:N]), @view(u[(N + 1):2N]))
_ham_split(u::AbstractMatrix, N::Int) = (@view(u[1:N, :]), @view(u[(N + 1):2N, :]))

"""
$(TYPEDSIGNATURES)

Assign derivatives `dx` and `dp` to the combined derivative `du` for Hamiltonian systems.

Dispatches on the array type (`AbstractVector` or `AbstractMatrix`) and the known dimension `N` (or `nothing` for runtime inference).

# Arguments
- `du::AbstractVector` or `AbstractMatrix`: Combined derivative to fill `[dx; dp]`.
- `dx`: State derivative (same shape as state part of `du`).
- `dp`: Costate derivative (same shape as costate part of `du`).
- `N::Int` or `nothing`: State dimension. If `nothing`, infers as `size(du, 1) ÷ 2`.

# Returns
- `nothing`

# Notes
- Internal helper used by RHS builders for Hamiltonian systems.
- Performs in-place assignment using broadcasting.
"""
_ham_assign!(du::AbstractVector, dx, dp, N::Int) = (du[1:N].=dx; du[(N + 1):2N].=dp)
_ham_assign!(du::AbstractMatrix, dx, dp, N::Int) = (du[1:N, :].=dx; du[(N + 1):2N, :].=dp)

# =============================================================================
# Internal helpers for augmented split/assign (Vector + Matrix, concrete integers)
# =============================================================================

"""
$(TYPEDSIGNATURES)

Split an augmented state vector into state, costate, and variable costate components.

The augmented state vector has the form `[x; p; pv]` where:
- `x` is the state (first `n_x` elements)
- `p` is the costate (next `n_x` elements)
- `pv` is the variable costate (last `n_v` elements)

# Arguments
- `u::AbstractVector`: Augmented state vector `[x; p; pv]`.
- `n_x::Int`: State dimension.
- `n_v::Int`: Variable dimension.

# Returns
- `Tuple`: `(x, p, pv)` where each component is a `@view` slice.

# Notes
- Always returns views (never scalars), consistent with `_ham_split`.
- For matrix inputs, returns column views.
- Used internally by [`CTFlows.Systems.HamIpAugRHS`](@ref).

See also: [`CTFlows.Systems._aug_assign!`](@ref), [`CTFlows.Systems.HamIpAugRHS`](@ref).
"""
function _aug_split(u::AbstractVector, n_x::Int, n_v::Int)
    x = @view(u[1:n_x])
    p = @view(u[(n_x + 1):(2 * n_x)])
    pv = @view(u[(end - n_v + 1):end])
    return (x, p, pv)
end
function _aug_split(u::AbstractMatrix, n_x::Int, n_v::Int)
    return (
        @view(u[1:n_x, :]),
        @view(u[(n_x + 1):(2 * n_x), :]),
        @view(u[(end - n_v + 1):end, :])
    )
end

"""
$(TYPEDSIGNATURES)

Assign derivatives to the augmented derivative vector for Hamiltonian systems with variable costate.

The augmented derivative vector has the form `[dx; dp; dpv]` where:
- `dx` is the state derivative (first `n_x` elements)
- `dp` is the costate derivative (next `n_x` elements)
- `dpv` is the variable costate derivative (last `n_v` elements)

# Arguments
- `du::AbstractVector`: Augmented derivative vector to fill `[dx; dp; dpv]`.
- `dx`: State derivative.
- `dp`: Costate derivative.
- `dpv`: Variable costate derivative.
- `n_x::Int`: State dimension.
- `n_v::Int`: Variable dimension.

# Returns
- `nothing`.

# Notes
- Performs in-place assignment using broadcasting.
- For matrix inputs, broadcasts over columns.
- Used internally by [`CTFlows.Systems.HamIpAugRHS`](@ref).

See also: [`CTFlows.Systems._aug_split`](@ref), [`CTFlows.Systems.HamIpAugRHS`](@ref).
"""
function _aug_assign!(du::AbstractVector, dx, dp, dpv, n_x::Int, n_v::Int)
    return (du[1:n_x].=dx; du[(n_x + 1):(2 * n_x)].=dp; du[(end - n_v + 1):end].=dpv)
end
function _aug_assign!(du::AbstractMatrix, dx, dp, dpv, n_x::Int, n_v::Int)
    return (
        du[1:n_x, :].=dx; du[(n_x + 1):(2 * n_x), :].=dp; du[(end - n_v + 1):end, :].=dpv
    )
end

# =============================================================================
# New unified getters: get_ip_rhs / get_oop_rhs / get_ip_rhs_augmented
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the in-place right-hand side for a `HamiltonianVectorFieldSystem`.

Lazy implementation: reads `x0`/`p0` from the config to build type-specific closures.

# Arguments
- `sys::HamiltonianVectorFieldSystem{..., OutOfPlace, ...}`: The out-of-place system.
- `config::Configs.AbstractHamiltonianConfig`: The Hamiltonian configuration.

# Returns
- `IPHVFOoPRHS`: An in-place RHS functor.

See also: [`CTFlows.Systems.get_oop_rhs`](@ref).
"""
function get_ip_rhs(
    sys::HamiltonianVectorFieldSystem{F,TD,VD,Traits.OutOfPlace},
    config::Configs.AbstractHamiltonianConfig,
) where {F,TD,VD}
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    return IPHVFOoPRHS(sys.hvf, _state_dim(x0), Core.make_coerce(x0), Core.make_coerce(p0))
end

"""
$(TYPEDSIGNATURES)

Return the in-place right-hand side for a `HamiltonianVectorFieldSystem`.

Lazy implementation: reads `x0`/`p0` from the config to build type-specific closures.

# Arguments
- `sys::HamiltonianVectorFieldSystem{..., InPlace, ...}`: The in-place system.
- `config::Configs.AbstractHamiltonianConfig`: The Hamiltonian configuration.

# Returns
- `IPHVFIpRHS`: An in-place RHS functor.

See also: [`CTFlows.Systems.get_oop_rhs`](@ref).
"""
function get_ip_rhs(
    sys::HamiltonianVectorFieldSystem{F,TD,VD,Traits.InPlace},
    config::Configs.AbstractHamiltonianConfig,
) where {F,TD,VD}
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    return IPHVFIpRHS(sys.hvf, _state_dim(x0), Core.make_coerce(x0), Core.make_coerce(p0))
end

"""
$(TYPEDSIGNATURES)

Return the out-of-place right-hand side for a `HamiltonianVectorFieldSystem`.

Lazy implementation: reads `x0`/`p0` from the config to build type-specific closures.

# Arguments
- `sys::HamiltonianVectorFieldSystem{..., OutOfPlace, ...}`: The out-of-place system.
- `config::Configs.AbstractHamiltonianConfig`: The Hamiltonian configuration.

# Returns
- `OoPHVFOoPRHS`: An out-of-place RHS functor.

See also: [`CTFlows.Systems.get_ip_rhs`](@ref).
"""
function get_oop_rhs(
    sys::HamiltonianVectorFieldSystem{F,TD,VD,Traits.OutOfPlace},
    config::Configs.AbstractHamiltonianConfig,
) where {F,TD,VD}
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    return OoPHVFOoPRHS(sys.hvf, _state_dim(x0), Core.make_coerce(x0), Core.make_coerce(p0))
end

"""
$(TYPEDSIGNATURES)

Return the out-of-place right-hand side for a `HamiltonianVectorFieldSystem`.

Lazy implementation: reads `x0`/`p0` from the config to build type-specific closures.
For immutable initial conditions, returns the finalize closure.

# Arguments
- `sys::HamiltonianVectorFieldSystem{..., InPlace, ...}`: The in-place system.
- `config::Configs.AbstractHamiltonianConfig`: The Hamiltonian configuration.

# Returns
- `OoPHVFIpRHS` or `OoPHVFIpFinalizeRHS`: An out-of-place RHS functor.

# Notes
- Emits a performance warning when called with immutable initial conditions.

See also: [`CTFlows.Systems.get_ip_rhs`](@ref).
"""
function get_oop_rhs(
    sys::HamiltonianVectorFieldSystem{F,TD,VD,Traits.InPlace},
    config::Configs.AbstractHamiltonianConfig,
) where {F,TD,VD}
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    if !ismutable(x0)
        @warn "InPlace HamiltonianVectorField with immutable u0 (e.g. SVector): consider using an out-of-place function for better performance."
        return OoPHVFIpFinalizeRHS(
            sys.hvf, _state_dim(x0), Core.make_coerce(x0), Core.make_coerce(p0)
        )
    end
    return OoPHVFIpRHS(sys.hvf, _state_dim(x0), Core.make_coerce(x0), Core.make_coerce(p0))
end

"""
$(TYPEDSIGNATURES)

Return the augmented in-place right-hand side for a `HamiltonianVectorFieldSystem`.

Lazy implementation: reads `x0`/`p0`/`pv0` from the config to build the augmented closure.

# Arguments
- `sys::HamiltonianVectorFieldSystem{..., OutOfPlace, ...}`: The out-of-place system.
- `config::Configs.AbstractAugmentedHamiltonianConfig`: The augmented Hamiltonian configuration.

# Returns
- `IPHVFOoPAugRHS`: An augmented in-place RHS functor.

See also: [`CTFlows.Systems.get_ip_rhs`](@ref), [`CTFlows.Systems.get_oop_rhs`](@ref).
"""
function get_ip_rhs_augmented(
    sys::HamiltonianVectorFieldSystem{F,TD,VD,Traits.OutOfPlace},
    config::Configs.AbstractAugmentedHamiltonianConfig,
) where {F,TD,VD}
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    n_x = _state_dim(x0)
    pv0 = Configs.initial_variable_costate(config)
    n_v = _state_dim(pv0)
    return IPHVFOoPAugRHS(sys.hvf, n_x, n_v, Core.make_coerce(x0), Core.make_coerce(p0))
end

"""
$(TYPEDSIGNATURES)

Return the augmented in-place right-hand side for a `HamiltonianVectorFieldSystem`.

Lazy implementation: reads `x0`/`p0`/`pv0` from the config to build the augmented closure.

# Arguments
- `sys::HamiltonianVectorFieldSystem{..., InPlace, ...}`: The in-place system.
- `config::Configs.AbstractAugmentedHamiltonianConfig`: The augmented Hamiltonian configuration.

# Returns
- `IPHVFIpAugRHS`: An augmented in-place RHS functor.

See also: [`CTFlows.Systems.get_ip_rhs`](@ref), [`CTFlows.Systems.get_oop_rhs`](@ref).
"""
function get_ip_rhs_augmented(
    sys::HamiltonianVectorFieldSystem{F,TD,VD,Traits.InPlace},
    config::Configs.AbstractAugmentedHamiltonianConfig,
) where {F,TD,VD}
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    n_x = _state_dim(x0)
    pv0 = Configs.initial_variable_costate(config)
    n_v = _state_dim(pv0)
    return IPHVFIpAugRHS(sys.hvf, n_x, n_v, Core.make_coerce(x0), Core.make_coerce(p0))
end

# =============================================================================
# Trait: variable_costate
# =============================================================================

# TODO: docstring
function Traits.variable_costate_trait(
    ::HamiltonianVectorFieldSystem{F,TD,Traits.NonFixed,MD}
) where {F,TD,MD}
    return Traits.SupportsVariableCostate
end

# =============================================================================
# Base.show
# =============================================================================

"""
$(TYPEDSIGNATURES)

Display a compact representation of a HamiltonianVectorFieldSystem.

Shows the type name and the wrapped HamiltonianVectorField with its traits.

# Arguments
- `io::IO`: The IO stream to write to.
- `sys::HamiltonianVectorFieldSystem`: The HamiltonianVectorFieldSystem to display.

See also: [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref).
"""
function Base.show(io::IO, sys::HamiltonianVectorFieldSystem{F,TD,VD,MD}) where {F,TD,VD,MD}
    println(io, "HamiltonianVectorFieldSystem")
    wraps = "HamiltonianVectorField: $(Data._td_label(TD)), $(Data._vd_label(VD)), $(Data._md_label(MD))"
    return print(io, "  wraps: ", wraps)
end

"""
$(TYPEDSIGNATURES)

Display a HamiltonianVectorFieldSystem in the REPL with text/plain MIME type.

Delegates to the compact show method.

# Arguments
- `io::IO`: The IO stream to write to.
- `::MIME"text/plain"`: The MIME type for REPL display.
- `sys::HamiltonianVectorFieldSystem`: The HamiltonianVectorFieldSystem to display.

See also: [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref).
"""
function Base.show(io::IO, ::MIME"text/plain", sys::HamiltonianVectorFieldSystem)
    return show(io, sys)
end
