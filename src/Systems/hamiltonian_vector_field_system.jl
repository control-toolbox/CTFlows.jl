"""
$(TYPEDEF)

Concrete `AbstractHamiltonianSystem` wrapping a `HamiltonianVectorField`. The state
dimension `N` is stored as a type parameter for compile-time validation and
performance. If `N=nothing`, the dimension is inferred at runtime.

# Type Parameters
- `N`: State dimension (`Int` if known, `nothing` if unknown).
- `F`: concrete type of the wrapped HamiltonianVectorField function.
- `TD <: TimeDependence`: `Autonomous` or `NonAutonomous`.
- `VD <: VariableDependence`: `Fixed` or `NonFixed`.
- `MD <: AbstractMutabilityTrait`: `InPlace` or `OutOfPlace`.
- `RHS`: type of the pre-computed in-place right-hand side function.
- `OOPROHS`: type of the pre-computed out-of-place right-hand side function.
- `FINRHS`: type of the finalize closure for in-place vector fields, or `Nothing`.

# Fields
- `hvf::HamiltonianVectorField{F, TD, VD, MD}`: the underlying Hamiltonian vector field.
- `rhs::RHS`: the pre-computed in-place right-hand side closure with signature `(du, u, p, t) -> nothing`.
- `rhs_oop::OOPROHS`: the pre-computed out-of-place right-hand side closure with signature `(u, p, t) -> du`.
- `rhs_oop_finalize::FINRHS`: the finalize closure for in-place vector fields with immutable initial conditions, or `nothing` for out-of-place vector fields.

# Example
```julia-repl
julia> using CTFlows.Systems, CTFlows.Common

julia> hvf = HamiltonianVectorField((x, p) -> (x, -p); autonomous=true, variable=false)
HamiltonianVectorField
  time_dependence: Autonomous
  variable_dependence: Fixed
  mutability: OutOfPlace
  function: var"#1"

julia> sys = HamiltonianVectorFieldSystem(hvf, 3)  # with known dimension
HamiltonianVectorFieldSystem
  time_dependence: Autonomous
  variable_dependence: Fixed
  mutability: OutOfPlace
  n_state: 3
  hamiltonian_vector_field: HamiltonianVectorField{var"#1", Autonomous, Fixed, OutOfPlace}

julia> sys = HamiltonianVectorFieldSystem(hvf)  # without dimension
HamiltonianVectorFieldSystem
  time_dependence: Autonomous
  variable_dependence: Fixed
  mutability: OutOfPlace
  n_state: unknown
  hamiltonian_vector_field: HamiltonianVectorField{var"#1", Autonomous, Fixed, OutOfPlace}
```

See also: [`CTFlows.Data.HamiltonianVectorField`](@ref), [`CTFlows.Systems.AbstractHamiltonianSystem`](@ref), [`CTFlows.Common.TimeDependence`](@ref), [`CTFlows.Common.VariableDependence`](@ref).
"""
struct HamiltonianVectorFieldSystem{N, F<:Function, TD<:Common.TimeDependence, VD<:Common.VariableDependence, MD<:Common.AbstractMutabilityTrait, RHS<:Function, OOPROHS<:Function, FINRHS} <: AbstractHamiltonianSystem{TD, VD}
    hvf::Data.HamiltonianVectorField{F, TD, VD, MD}
    rhs::RHS
    rhs_oop::OOPROHS
    rhs_oop_finalize::FINRHS
end

# =============================================================================
# Constructors
# =============================================================================

# OutOfPlace, with known dimension N
function HamiltonianVectorFieldSystem(hvf::Data.HamiltonianVectorField{F, TD, VD, OutOfPlace}, n_state::Int) where {F, TD, VD}
    rhs              = _build_rhs(hvf, Val(n_state))
    rhs_oop          = _build_oop_rhs(hvf, Val(n_state))
    rhs_oop_finalize = nothing
    return HamiltonianVectorFieldSystem{n_state, F, TD, VD, OutOfPlace, typeof(rhs), typeof(rhs_oop), Nothing}(hvf, rhs, rhs_oop, rhs_oop_finalize)
end

# InPlace, with known dimension N
function HamiltonianVectorFieldSystem(hvf::Data.HamiltonianVectorField{F, TD, VD, InPlace}, n_state::Int) where {F, TD, VD}
    rhs              = _build_rhs(hvf, Val(n_state))
    rhs_oop          = _build_oop_rhs(hvf, Val(n_state))
    rhs_oop_finalize = _build_finalize_rhs_hvf_ip(hvf, Val(n_state))
    return HamiltonianVectorFieldSystem{n_state, F, TD, VD, InPlace, typeof(rhs), typeof(rhs_oop), typeof(rhs_oop_finalize)}(hvf, rhs, rhs_oop, rhs_oop_finalize)
end

# OutOfPlace, without dimension (N=nothing)
function HamiltonianVectorFieldSystem(hvf::Data.HamiltonianVectorField{F, TD, VD, OutOfPlace}) where {F, TD, VD}
    rhs              = _build_rhs(hvf, Val(nothing))
    rhs_oop          = _build_oop_rhs(hvf, Val(nothing))
    rhs_oop_finalize = nothing
    return HamiltonianVectorFieldSystem{nothing, F, TD, VD, OutOfPlace, typeof(rhs), typeof(rhs_oop), Nothing}(hvf, rhs, rhs_oop, rhs_oop_finalize)
end

# InPlace, without dimension (N=nothing)
function HamiltonianVectorFieldSystem(hvf::Data.HamiltonianVectorField{F, TD, VD, InPlace}) where {F, TD, VD}
    rhs              = _build_rhs(hvf, Val(nothing))
    rhs_oop          = _build_oop_rhs(hvf, Val(nothing))
    rhs_oop_finalize = _build_finalize_rhs_hvf_ip(hvf, Val(nothing))
    return HamiltonianVectorFieldSystem{nothing, F, TD, VD, InPlace, typeof(rhs), typeof(rhs_oop), typeof(rhs_oop_finalize)}(hvf, rhs, rhs_oop, rhs_oop_finalize)
end

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
_ham_split(u::AbstractVector, ::Nothing) = let n = length(u) ÷ 2
    (@view(u[1:n]), @view(u[n+1:2n]))
end
_ham_split(u::AbstractMatrix, N::Int) = (@view(u[1:N, :]), @view(u[N+1:2N, :]))
_ham_split(u::AbstractMatrix, ::Nothing) = let n = size(u, 1) ÷ 2
    (@view(u[1:n, :]), @view(u[n+1:2n, :]))
end

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
_ham_assign!(du::AbstractVector, dx, dp, ::Nothing) = let n = length(du) ÷ 2
    du[1:n] .= dx; du[n+1:2n] .= dp
end
_ham_assign!(du::AbstractMatrix, dx, dp, N::Int) = (du[1:N, :] .= dx; du[N+1:2N, :] .= dp)
_ham_assign!(du::AbstractMatrix, dx, dp, ::Nothing) = let n = size(du, 1) ÷ 2
    du[1:n, :] .= dx; du[n+1:2n, :] .= dp
end

# =============================================================================
# Internal helpers for building RHS (in-place)
# =============================================================================

function _build_rhs(hvf::Data.HamiltonianVectorField{F, TD, VD, OutOfPlace}, ::Val{N}) where {F, TD, VD, N}
    return function (du, u, λ, t)
        x, p = _ham_split(u, N)
        dx, dp = hvf(t, x, p, λ.variable)
        _ham_assign!(du, dx, dp, N)
        return nothing
    end
end

function _build_rhs(hvf::Data.HamiltonianVectorField{F, TD, VD, InPlace}, ::Val{N}) where {F, TD, VD, N}
    return function (du, u, λ, t)
        x, p   = _ham_split(u,  N)
        dx, dp = _ham_split(du, N)  # mutable views into du — hvf writes directly into du, no _ham_assign! needed
        hvf(dx, dp, t, x, p, λ.variable)
        return nothing
    end
end

# =============================================================================
# Internal helpers for building RHS (out-of-place for SVector)
# =============================================================================

function _build_oop_rhs(hvf::Data.HamiltonianVectorField{F, TD, VD, OutOfPlace}, ::Val{N}) where {F, TD, VD, N}
    return function (u, λ, t)
        x, p = _ham_split(u, N)
        dx, dp = hvf(t, x, p, λ.variable)
        return vcat(dx, dp)
    end
end

function _build_oop_rhs(hvf::Data.HamiltonianVectorField{F, TD, VD, InPlace}, ::Val{N}) where {F, TD, VD, N}
    return function (u, λ, t)
        x, p   = _ham_split(u, N)
        dx, dp = similar(x), similar(p)
        hvf(dx, dp, t, x, p, λ.variable)
        return vcat(dx, dp)
    end
end

# =============================================================================
# Internal helpers for building finalize RHS (in-place with immutable u0)
# =============================================================================

function _build_finalize_rhs_hvf_ip(hvf::Data.HamiltonianVectorField{F, TD, VD, InPlace}, ::Val{N}) where {F, TD, VD, N}
    return function (u, λ, t)
        x, p   = _ham_split(u, N)
        dx, dp = similar(x), similar(p)
        hvf(dx, dp, t, x, p, λ.variable)
        return typeof(u)(vcat(dx, dp))
    end
end

# =============================================================================
# rhs accessor (in-place)
# =============================================================================

"""
$(TYPEDSIGNATURES)

In-place right-hand side for a `HamiltonianVectorFieldSystem`. Returns the pre-computed
closure stored in the system, which has signature `(du, u, p, t) -> nothing` and
splits the combined state `u` into `(x, p)` halves, calls the underlying Hamiltonian
vector field, and concatenates `(dx, dp)` into `du`.

# Arguments
- `sys::HamiltonianVectorFieldSystem`: The system for which to return the RHS function.

# Returns
- `Function`: The pre-computed closure with signature `(du, u, p, t) -> nothing`.

# Notes
- The RHS splits `u` into state `x` and costate `p` halves: `x = u[1:N]`, `p = u[N+1:2N]`.
- If `N=nothing`, the split uses `n = length(u) ÷ 2` at runtime.
- The closure is computed once at construction time for performance.

See also: [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref), [`CTFlows.Systems.rhs_oop`](@ref).
"""
function rhs(sys::HamiltonianVectorFieldSystem)
    return sys.rhs
end

# =============================================================================
# rhs_oop accessor (out-of-place for SVector)
# =============================================================================

"""
$(TYPEDSIGNATURES)

Out-of-place right-hand side for an `OutOfPlace` `HamiltonianVectorFieldSystem`.

Returns the pre-computed closure with signature `(u, p, t) -> du`. The optional
`is_u0_mutable` argument is accepted but ignored: for out-of-place Hamiltonian vector
fields `rhs_oop` is always the correct callable regardless of u0 mutability.

# Arguments
- `sys::HamiltonianVectorFieldSystem{..., OutOfPlace, ...}`: The out-of-place system.
- `::Bool`: Ignored. Accepted for API uniformity with the `InPlace` method.

# Returns
- `Function`: The pre-computed closure with signature `(u, p, t) -> du`.

See also: [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref), [`CTFlows.Systems.rhs`](@ref).
"""
function rhs_oop(sys::HamiltonianVectorFieldSystem{N, F, TD, VD, OutOfPlace, RHS, OOPROHS, Nothing}, ::Bool = true) where {N, F, TD, VD, RHS, OOPROHS}
    return sys.rhs_oop
end

"""
$(TYPEDSIGNATURES)

Out-of-place right-hand side for an `InPlace` `HamiltonianVectorFieldSystem`, dispatching on u0 mutability.

For in-place Hamiltonian vector fields the appropriate callable depends on whether the
initial condition `u0` is mutable:
- **`is_u0_mutable = true`** (default): returns `rhs_oop`, which allocates mutable buffers
  for `dx` and `dp` and returns `vcat(dx, dp)`. Correct when `u0` is a `Vector`.
- **`is_u0_mutable = false`**: returns `rhs_oop_finalize`, which fills mutable buffers then
  converts back via `typeof(u)(vcat(dx, dp))`. Correct when `u0` is immutable (e.g. `SVector`).
  A one-time performance warning is emitted.

# Arguments
- `sys::HamiltonianVectorFieldSystem{..., InPlace, ...}`: The in-place system.
- `is_u0_mutable::Bool`: `true` if u0 is mutable, `false` if immutable. Defaults to `true`.

# Returns
- `Function`: The appropriate closure with signature `(u, p, t) -> du`.

# Notes
- Prefer out-of-place Hamiltonian vector fields when u0 is a `StaticArrays.SVector`.

See also: [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref), [`CTFlows.Systems.rhs`](@ref).
"""
function rhs_oop(sys::HamiltonianVectorFieldSystem{N, F, TD, VD, InPlace, RHS, OOPROHS, FINRHS}, is_u0_mutable::Bool = true) where {N, F, TD, VD, RHS, OOPROHS, FINRHS}
    is_u0_mutable && return sys.rhs_oop
    @warn "InPlace HamiltonianVectorField with immutable u0 (e.g. SVector): consider using an out-of-place function for better performance."
    return sys.rhs_oop_finalize
end

# =============================================================================
# state_dimension accessor
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the state dimension `N` for a `HamiltonianVectorFieldSystem`.

If the system was constructed with a known dimension, returns `N::Int`.
If the dimension was not specified at construction time, returns `nothing`.

# Arguments
- `sys::HamiltonianVectorFieldSystem`: The Hamiltonian system.

# Returns
- `Union{Int, Nothing}`: The state dimension, or `nothing` if unknown.

# Example
```julia
using CTFlows.Systems

hvf = HamiltonianVectorField((x, p) -> (x, -p); autonomous=true, variable=false)
sys_with_n = HamiltonianVectorFieldSystem(hvf, 3)
state_dimension(sys_with_n)  # Returns 3

sys_without_n = HamiltonianVectorFieldSystem(hvf)
state_dimension(sys_without_n)  # Returns nothing
```

See also: [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref).
"""
function state_dimension(sys::HamiltonianVectorFieldSystem{N}) where N
    return N
end

# =============================================================================
# Validation helper
# =============================================================================

function _check_state_dimension(sys::HamiltonianVectorFieldSystem{N}, x0) where N
    if size(x0, 1) != N
        throw(
            Exceptions.IncorrectArgument(
                "State dimension mismatch";
                got = "size(x0, 1)=$(size(x0, 1))",
                expected = "size(x0, 1)=$N",
                context = "HamiltonianVectorFieldSystem._check_state_dimension",
            ),
        )
    end
    return true
end

function _check_state_dimension(sys::HamiltonianVectorFieldSystem{nothing}, x0)
    return true
end

# =============================================================================
# Base.show
# =============================================================================

"""
$(TYPEDSIGNATURES)

Display a compact representation of a HamiltonianVectorFieldSystem.

Shows the type name, state dimension, and the wrapped HamiltonianVectorField with its traits.

# Arguments
- `io::IO`: The IO stream to write to.
- `sys::HamiltonianVectorFieldSystem`: The HamiltonianVectorFieldSystem to display.

See also: [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref).
"""
function Base.show(io::IO, sys::HamiltonianVectorFieldSystem{N, F, TD, VD, MD, RHS, OOPROHS, FINRHS}) where {N, F, TD, VD, MD, RHS, OOPROHS, FINRHS}
    println(io, "HamiltonianVectorFieldSystem")
    state_dim = N === nothing ? "unknown" : string(N)
    println(io, "  state dimension: ", state_dim)
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
function Base.show(io::IO, ::MIME"text/plain", sys::HamiltonianVectorFieldSystem{N, F, TD, VD, MD, RHS, OOPROHS, FINRHS}) where {N, F, TD, VD, MD, RHS, OOPROHS, FINRHS}
    show(io, sys)
end
