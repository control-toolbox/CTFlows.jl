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
julia> using CTFlows.Systems, CTBase.Data

julia> h = Hamiltonian((t, x, p, v) -> 0.5 * sum(x.^2) + sum(p.^2); autonomous=true, variable=false)
Hamiltonian{var"#1", Autonomous, Fixed}

julia> sys = HamiltonianSystem(h, AutoForwardDiff())
HamiltonianSystem
  time_dependence: Autonomous
  variable_dependence: Fixed
  hamiltonian: Hamiltonian{var"#1", Autonomous, Fixed}
  backend: AutoForwardDiff()
```

See also: [`CTBase.Data.Hamiltonian`](@ref), [`CTFlows.Systems.AbstractHamiltonianSystem`](@ref), [`CTBase.Traits.AbstractADTrait`](@ref), [`CTFlows.Systems.build_rhs`](@ref), [`CTFlows.Systems.build_oop_rhs`](@ref).
"""
struct HamiltonianSystem{
    F<:Function,
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    BACKEND<:Differentiation.AbstractADBackend,
} <: AbstractHamiltonianSystem{TD,VD}
    h::Data.Hamiltonian{F,TD,VD}
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

function HamiltonianSystem(
    h::Data.Hamiltonian{F,TD,VD}, backend::Differentiation.AbstractADBackend
) where {F,TD,VD}
    return HamiltonianSystem{F,TD,VD,typeof(backend)}(h, backend)
end

# =============================================================================
# Public lazy RHS builders
# =============================================================================

# =============================================================================
# New unified getters: get_ip_rhs / get_oop_rhs / get_ip_rhs_augmented
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the in-place right-hand side for a `HamiltonianSystem`.

Lazy implementation: reads `x0`/`p0` from the config to build type-specific closures.

# Arguments
- `sys::HamiltonianSystem`: The Hamiltonian system.
- `config::Configs.AbstractHamiltonianConfig`: The Hamiltonian configuration.

# Returns
- `HamIpRHS`: An in-place RHS functor with embedded AD cache.

See also: [`CTFlows.Systems.get_oop_rhs`](@ref).
"""
function get_ip_rhs(sys::HamiltonianSystem, config::Configs.AbstractHamiltonianConfig)
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    N = _state_dim(x0)
    cx = Core.make_coerce(x0)
    cp = Core.make_coerce(p0)
    h, backend = sys.h, sys.backend
    return HamIpRHS(h, backend, N, cx, cp)
end

"""
$(TYPEDSIGNATURES)

Return the out-of-place right-hand side for a `HamiltonianSystem`.

Lazy implementation: reads `x0`/`p0` from the config to build type-specific closures.

# Arguments
- `sys::HamiltonianSystem`: The Hamiltonian system.
- `config::Configs.AbstractHamiltonianConfig`: The Hamiltonian configuration.

# Returns
- `HamOoPRHS`: An out-of-place RHS functor with embedded AD cache.

See also: [`CTFlows.Systems.get_ip_rhs`](@ref).
"""
function get_oop_rhs(sys::HamiltonianSystem, config::Configs.AbstractHamiltonianConfig)
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    N = _state_dim(x0)
    cx = Core.make_coerce(x0)
    cp = Core.make_coerce(p0)
    h, backend = sys.h, sys.backend
    return HamOoPRHS(h, backend, N, cx, cp)
end

"""
$(TYPEDSIGNATURES)

Return the augmented in-place right-hand side for a `HamiltonianSystem`.

Lazy implementation: reads `x0`/`p0`/`pv0` from the config to build the augmented closure.

# Arguments
- `sys::HamiltonianSystem`: The Hamiltonian system.
- `config::Configs.AbstractAugmentedHamiltonianConfig`: The augmented Hamiltonian configuration.

# Returns
- `HamIpAugRHS`: An augmented in-place RHS functor with embedded AD cache.

See also: [`CTFlows.Systems.get_ip_rhs`](@ref), [`CTFlows.Systems.get_oop_rhs`](@ref).
"""
function get_ip_rhs_augmented(
    sys::HamiltonianSystem, config::Configs.AbstractAugmentedHamiltonianConfig
)
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    n_x = _state_dim(x0)
    pv0 = Configs.initial_variable_costate(config)
    n_v = _state_dim(pv0)
    cx = Core.make_coerce(x0)
    cp = Core.make_coerce(p0)
    h, backend = sys.h, sys.backend
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
    return println(io, "  backend: ", sys.backend)
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

See also: [`CTBase.Traits.AbstractVariableCostateCapability`](@ref), [`CTBase.Traits.SupportsVariableCostate`](@ref), [`CTBase.Traits.NoVariableCostate`](@ref).
"""
function Traits.variable_costate_trait(
    ::HamiltonianSystem{F,TD,Traits.NonFixed,B}
) where {F,TD,B}
    return Traits.SupportsVariableCostate
end
