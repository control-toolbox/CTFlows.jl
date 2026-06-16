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
} <: AbstractHamiltonianSystem{TD, VD}
    h::Data.Hamiltonian{F, TD, VD}
    backend::BACKEND
end

Traits.ad_trait(::HamiltonianSystem) = Traits.WithAD

"""
$(TYPEDSIGNATURES)

Return the Hamiltonian function from a HamiltonianSystem.

# Arguments
- `sys::HamiltonianSystem`: The Hamiltonian system.

# Returns
- `Data.Hamiltonian`: The Hamiltonian function wrapped by the system.

See also: [`CTFlows.Systems.HamiltonianSystem`](@ref), [`CTFlows.Systems.backend`](@ref).
"""
function hamiltonian(sys::HamiltonianSystem)
    return sys.h
end

"""
$(TYPEDSIGNATURES)

Return the automatic differentiation backend from a HamiltonianSystem.

# Arguments
- `sys::HamiltonianSystem`: The Hamiltonian system.

# Returns
- `Differentiation.AbstractADBackend`: The AD backend used for gradient computation.

See also: [`CTFlows.Systems.HamiltonianSystem`](@ref), [`CTFlows.Systems.hamiltonian`](@ref).
"""
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
$(TYPEDSIGNATURES)

Build an in-place RHS functor for a Hamiltonian system.

This function creates a `HamIpRHS` functor that computes the Hamiltonian gradient
in-place, following the canonical Hamiltonian equations. The functor is lazily
constructed based on the initial condition types to ensure correct handling of
scalar, vector, and matrix inputs.

# Arguments
- `sys::HamiltonianSystem`: The Hamiltonian system.
- `x0`: Initial state (used to infer state dimension and conversion).
- `p0`: Initial costate (used to infer conversion).
- `t0`: Initial time (for cache preparation in non-autonomous systems).
- `variable`: Variable value (for cache preparation in non-fixed systems).

# Returns
- `HamIpRHS`: An in-place RHS functor with embedded AD cache.

# Notes
- The AD cache is prepared using the backend's `prepare_cache` method.
- The cache is embedded in the functor for better composability.
- This function is called by the SciML extension when building ODE problems.

See also: [`CTFlows.Systems.HamIpRHS`](@ref), [`CTFlows.Systems.build_oop_rhs`](@ref).
"""
function build_rhs(sys::HamiltonianSystem, x0, p0, _, _)
    N = _state_dim(x0)
    cx = Common.make_coerce(x0)
    cp = Common.make_coerce(p0)
    h, backend = sys.h, sys.backend
    return HamIpRHS(h, backend, N, cx, cp)
end

"""
$(TYPEDSIGNATURES)

Build an out-of-place RHS functor for a Hamiltonian system.

This function creates a `HamOoPRHS` functor that computes the Hamiltonian gradient
out-of-place, following the canonical Hamiltonian equations. The functor is lazily
constructed based on the initial condition types to ensure correct handling of
scalar, vector, and matrix inputs.

# Arguments
- `sys::HamiltonianSystem`: The Hamiltonian system.
- `x0`: Initial state (used to infer state dimension and conversion).
- `p0`: Initial costate (used to infer conversion).
- `t0`: Initial time (for cache preparation in non-autonomous systems).
- `variable`: Variable value (for cache preparation in non-fixed systems).

# Returns
- `HamOoPRHS`: An out-of-place RHS functor with embedded AD cache.

# Notes
- The AD cache is prepared using the backend's `prepare_cache` method.
- The cache is embedded in the functor for better composability.
- This function is called by the SciML extension when building ODE problems.

See also: [`CTFlows.Systems.HamOoPRHS`](@ref), [`CTFlows.Systems.build_rhs`](@ref).
"""
function build_oop_rhs(sys::HamiltonianSystem, x0, p0, _, _)
    N = _state_dim(x0)
    cx = Common.make_coerce(x0)
    cp = Common.make_coerce(p0)
    h, backend = sys.h, sys.backend
    return HamOoPRHS(h, backend, N, cx, cp)
end

# =============================================================================
# build_rhs_augmented — lazy, closes over concrete n_x and n_v
# =============================================================================

"""
$(TYPEDSIGNATURES)

Build an augmented in-place RHS functor for a Hamiltonian system.

This function creates a `HamIpAugRHS` functor that computes the augmented Hamiltonian
equations including variable costate evolution, used in sensitivity analysis and
optimal control. The state vector is augmented as `[x; p; v]` where `v` is the
variable costate.

# Arguments
- `sys::HamiltonianSystem`: The Hamiltonian system.
- `n_x::Int`: State dimension (number of state variables).
- `n_v::Int`: Variable dimension.
- `x0`: Initial state (for cache preparation).
- `p0`: Initial costate (for cache preparation).
- `t0`: Initial time (for cache preparation in non-autonomous systems).
- `variable`: Variable value (for cache preparation in non-fixed systems).

# Returns
- `HamIpAugRHS`: An augmented in-place RHS functor with embedded AD cache.

# Notes
- The AD cache is prepared using the backend's `prepare_cache` method.
- The cache is embedded in the functor for better composability.
- Supports batch mode with matrix inputs (checks batch size compatibility).
- This function is used for variable costate integration in sensitivity analysis.

See also: [`CTFlows.Systems.HamIpAugRHS`](@ref), [`CTFlows.Systems.build_rhs`](@ref).
"""
function build_rhs_augmented(sys::HamiltonianSystem, n_x::Int, n_v::Int, x0, p0, _, _)
    h, backend = sys.h, sys.backend
    cx = Common.make_coerce(x0)
    cp = Common.make_coerce(p0)
    return HamIpAugRHS(h, backend, n_x, n_v, cx, cp)
end

# =============================================================================
# Base.show
# =============================================================================

"""
$(TYPEDSIGNATURES)

Display a Hamiltonian system in a human-readable format.

# Arguments
- `io::IO`: IO stream.
- `sys::HamiltonianSystem`: The Hamiltonian system to display.

# Notes
- Shows the time dependence, variable dependence, Hamiltonian function, and AD backend.
- Used by the REPL for interactive display.
"""
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
