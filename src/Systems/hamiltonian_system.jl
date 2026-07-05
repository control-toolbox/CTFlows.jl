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
- `TD <: TimeDependence`: `Autonomous` or `NonAutonomous`.
- `VD <: VariableDependence`: `Fixed` or `NonFixed`.
- `H <: AbstractHamiltonian{TD, VD}`: concrete Hamiltonian type. Any
  `CTBase.Data.AbstractHamiltonian` is accepted, including a
  `CTBase.Data.ComposedHamiltonian` (a pseudo-Hamiltonian composed with a control law),
  so the AD path differentiates *through* the control law.
- `BACKEND <: AbstractADBackend`: concrete AD backend type.

# Fields
- `h::H`: the underlying scalar Hamiltonian function.
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

See also: [`CTBase.Data.Hamiltonian`](@extref), [`CTFlows.Systems.AbstractHamiltonianSystem`](@ref), [`CTBase.Traits.AbstractADTrait`](@extref), `build_rhs`, `build_oop_rhs`.
"""
struct HamiltonianSystem{
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    H<:Data.AbstractHamiltonian{TD,VD},
    BACKEND<:Differentiation.AbstractADBackend,
} <: AbstractHamiltonianSystem{TD,VD}
    h::H
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
    h::Data.AbstractHamiltonian{TD,VD},
    backend::Differentiation.AbstractADBackend,
) where {TD,VD}
    return HamiltonianSystem{TD,VD,typeof(h),typeof(backend)}(h, backend)
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
    cx = _coerce_state(x0)
    cp = _coerce_state(p0)
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
    cx = _coerce_state(x0)
    cp = _coerce_state(p0)
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
    sys::HamiltonianSystem,
    config::Configs.AbstractAugmentedHamiltonianConfig,
)
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    n_x = _state_dim(x0)
    pv0 = Configs.initial_variable_costate(config)
    n_v = _state_dim(pv0)
    cx = _coerce_state(x0)
    cp = _coerce_state(p0)
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
    fmt = Display.format_codes(io)
    Display.print_header(io, "HamiltonianSystem"; fmt = fmt)
    Display.print_field(
        io,
        "time_dependence",
        nameof(Traits.time_dependence(sys));
        fmt = fmt,
        value_style = fmt.type,
    )
    Display.print_field(
        io,
        "variable_dependence",
        nameof(Traits.variable_dependence(sys));
        fmt = fmt,
        value_style = fmt.type,
    )
    Display.print_field(io, "", sys.h; fmt = fmt, value_style = "")
    return Display.print_field(
        io,
        "backend",
        sys.backend;
        last = true,
        fmt = fmt,
        value_style = "",
    )
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

See also: [`CTBase.Traits.AbstractVariableCostateCapability`](@extref), [`CTBase.Traits.SupportsVariableCostate`](@extref), [`CTBase.Traits.NoVariableCostate`](@extref).
"""
function Traits.variable_costate_trait(
    ::HamiltonianSystem{TD,Traits.NonFixed,H,B},
) where {TD,H,B}
    return Traits.SupportsVariableCostate
end
