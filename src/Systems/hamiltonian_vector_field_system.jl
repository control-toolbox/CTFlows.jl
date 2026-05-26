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

See also: [`CTFlows.Data.HamiltonianVectorField`](@ref), [`CTFlows.Systems.AbstractHamiltonianSystem`](@ref), [`CTFlows.Traits.TimeDependence`](@ref), [`CTFlows.Traits.VariableDependence`](@ref), [`CTFlows.Systems.build_rhs`](@ref), [`CTFlows.Systems.build_oop_rhs`](@ref).
"""
struct HamiltonianVectorFieldSystem{F<:Function, TD<:Traits.TimeDependence, VD<:Traits.VariableDependence, MD<:Traits.AbstractMutabilityTrait} <: AbstractHamiltonianSystem{TD, VD, Traits.WithoutAD}
    hvf::Data.HamiltonianVectorField{F, TD, VD, MD}
end

# =============================================================================
# Constructors
# =============================================================================

function HamiltonianVectorFieldSystem(hvf::Data.HamiltonianVectorField{F, TD, VD, MD}) where {F, TD, VD, MD}
    return HamiltonianVectorFieldSystem{F, TD, VD, MD}(hvf)
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

"""
    _make_coerce(::Number) = only
    _make_coerce(::AbstractVector) = identity
    _make_coerce(::AbstractMatrix) = identity

Return a coercion function for the given shape. For scalars, `only` extracts
a single element from a 1-element vector. For arrays, `identity` is a no-op.
"""
_make_coerce(::Number) = only
_make_coerce(::AbstractVector) = identity
_make_coerce(::AbstractMatrix) = identity

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
_ham_split(u::AbstractVector, N::Int) = (@view(u[1:N]), @view(u[N+1:2N]))
_ham_split(u::AbstractMatrix, N::Int) = (@view(u[1:N, :]), @view(u[N+1:2N, :]))

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
_ham_assign!(du::AbstractVector, dx, dp, N::Int) = (du[1:N] .= dx; du[N+1:2N] .= dp)
_ham_assign!(du::AbstractMatrix, dx, dp, N::Int) = (du[1:N, :] .= dx; du[N+1:2N, :] .= dp)

# =============================================================================
# Public lazy RHS builders
# =============================================================================

"""
    build_rhs(sys::HamiltonianVectorFieldSystem, x0, p0) -> f!(du, u, λ, t)

Build an in-place RHS closure for the given initial conditions.

The closure is constructed lazily based on the shapes of `x0` and `p0`,
ensuring correct handling of scalar, vector, and matrix inputs.

# Arguments
- `sys::HamiltonianVectorFieldSystem`: The Hamiltonian system.
- `x0`: Initial state (scalar, vector, or matrix).
- `p0`: Initial costate (same shape as `x0`).

# Returns
- `Function`: A closure with signature `(du, u, λ, t) -> nothing`.
"""
function build_rhs(sys::HamiltonianVectorFieldSystem{F, TD, VD, Traits.OutOfPlace}, x0, p0) where {F, TD, VD}
    N = _state_dim(x0)
    cx = _make_coerce(x0)
    cp = _make_coerce(p0)
    hvf = sys.hvf
    return function (du, u, λ, t)
        x, p = _ham_split(u, N)
        dx, dp = hvf(t, cx(x), cp(p), Common.variable(λ))
        _ham_assign!(du, dx, dp, N)
        return nothing
    end
end

function build_rhs(sys::HamiltonianVectorFieldSystem{F, TD, VD, Traits.InPlace}, x0, p0) where {F, TD, VD}
    N = _state_dim(x0)
    cx = _make_coerce(x0)
    cp = _make_coerce(p0)
    hvf = sys.hvf
    return function (du, u, λ, t)
        x, p   = _ham_split(u,  N)
        dx, dp = _ham_split(du, N)
        hvf(dx, dp, t, cx(x), cp(p), Common.variable(λ))
        return nothing
    end
end

"""
    build_oop_rhs(sys::HamiltonianVectorFieldSystem, x0, p0) -> f(u, λ, t)

Build an out-of-place RHS closure for the given initial conditions.

The closure is constructed lazily based on the shapes of `x0` and `p0`,
ensuring correct handling of scalar, vector, and matrix inputs.

# Arguments
- `sys::HamiltonianVectorFieldSystem`: The Hamiltonian system.
- `x0`: Initial state (scalar, vector, or matrix).
- `p0`: Initial costate (same shape as `x0`).

# Returns
- `Function`: A closure with signature `(u, λ, t) -> du`.
"""
function build_oop_rhs(sys::HamiltonianVectorFieldSystem{F, TD, VD, Traits.OutOfPlace}, x0, p0) where {F, TD, VD}
    N = _state_dim(x0)
    cx = _make_coerce(x0)
    cp = _make_coerce(p0)
    hvf = sys.hvf
    return function (u, λ, t)
        x, p = _ham_split(u, N)
        dx, dp = hvf(t, cx(x), cp(p), Common.variable(λ))
        return vcat(dx, dp)
    end
end

function build_oop_rhs(sys::HamiltonianVectorFieldSystem{F, TD, VD, Traits.InPlace}, x0, p0) where {F, TD, VD}
    N = _state_dim(x0)
    cx = _make_coerce(x0)
    cp = _make_coerce(p0)
    hvf = sys.hvf
    is_u0_mutable = ismutable(x0)
    # TODO: Re-enable warning when needed for user guidance
    # if !is_u0_mutable
    #     @warn "InPlace HamiltonianVectorField with immutable u0 (e.g. SVector): consider using an out-of-place function for better performance."
    # end
    return function (u, λ, t)
        x, p   = _ham_split(u, N)
        dx, dp = similar(x), similar(p)
        hvf(dx, dp, t, cx(x), cp(p), Common.variable(λ))
        result = vcat(dx, dp)
        if !is_u0_mutable
            return typeof(u)(result)
        end
        return result
    end
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
function Base.show(io::IO, sys::HamiltonianVectorFieldSystem{F, TD, VD, MD}) where {F, TD, VD, MD}
    println(io, "HamiltonianVectorFieldSystem")
    wraps = "HamiltonianVectorField: $(Data._td_label(TD)), $(Data._vd_label(VD)), $(Data._md_label(MD))"
    print(io, "  wraps: ", wraps)
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
    show(io, sys)
end
