# =============================================================================
# _check_dyn_config — compatibility guard between system dynamics and config type
# =============================================================================

_check_dyn_config(::Type{Traits.StateDynamics}, ::Configs.AbstractConfig) = nothing
_check_dyn_config(::Type{Traits.HamiltonianDynamics}, ::Configs.AbstractHamiltonianConfig) = nothing
_check_dyn_config(::Type{Traits.HamiltonianDynamics}, ::Configs.AbstractAugmentedHamiltonianConfig) = nothing
function _check_dyn_config(D, C)
    throw(Exceptions.PreconditionError(
        "incompatible system dynamics and config types";
        reason    = "dynamics trait = $D, config type = $(typeof(C))",
        context   = "Integrators.build_problem",
        suggestion = "Use a Hamiltonian config with a Hamiltonian system, or a state config with a state system.",
    ))
end

# =============================================================================
# SciML problem building — CTFlows glue (Systems/Configs → SciML ODEProblem)
# =============================================================================

"""
$(TYPEDSIGNATURES)

Build an `ODEProblem` from a system and a non-augmented configuration.

Dispatches between in-place and out-of-place RHS based on the mutability of the initial condition:
- If `ismutable(u0)` is true, uses `Systems.get_ip_rhs(system, config)` with signature `(du, u, p, t) -> nothing`.
- If `ismutable(u0)` is false (e.g., `StaticArrays.SVector`), uses `Systems.get_oop_rhs(system, config)` with signature `(u, p, t) -> du`.

Covers both state systems (`AbstractStateSystem`) and non-augmented Hamiltonian systems
(`AbstractHamiltonianSystem` with `AbstractHamiltonianConfig`).

# Arguments
- `system::Systems.AbstractSystem`: The system to build an ODE problem for.
- `config::Configs.AbstractConfig`: The configuration containing initial condition and time span.
- `::Integrators.SciML`: The SciML integrator strategy.
- `variable`: Variable parameter for non-fixed systems.

# Returns
- `SciMLBase.ODEProblem`: The ODE problem ready for integration.

# Throws
- `CTBase.Exceptions.PreconditionError`: If the system dynamics trait is incompatible with the config type.

See also: [`CTFlows.Systems.get_ip_rhs`](@ref), [`CTFlows.Systems.get_oop_rhs`](@ref), [`CTFlows.Common.ODEParameters`](@ref).
"""
function Integrators.build_problem(
    system::Systems.AbstractSystem,
    config::Configs.AbstractConfig,
    ::Integrators.SciML;
    variable,
)
    _check_dyn_config(Traits.dynamics_trait(system), config)
    u0 = Configs.initial_condition(config)
    Systems._check_vf_scalar_inplace(system, u0)
    λ = Common.ODEParameters(variable)
    if ismutable(u0)
        f! = Systems.get_ip_rhs(system, config)
        return ODEProblem(f!, u0, Configs.tspan(config), λ)
    else
        f = Systems.get_oop_rhs(system, config)
        return ODEProblem(f, u0, Configs.tspan(config), λ)
    end
end

"""
$(TYPEDSIGNATURES)

Build an `ODEProblem` for augmented Hamiltonian systems.

Uses the augmented RHS that computes state, costate, and variable costate derivatives.
Always uses the in-place path since `pv0 = zeros(...)` guarantees mutability.

# Arguments
- `system::Systems.AbstractSystem`: The Hamiltonian system.
- `config::Configs.AbstractAugmentedHamiltonianConfig`: The augmented Hamiltonian configuration.
- `::Integrators.SciML`: The SciML integrator strategy.
- `variable`: Variable parameter for the augmented system.

# Returns
- `SciMLBase.ODEProblem`: The ODE problem with augmented RHS.

# Throws
- `CTBase.Exceptions.PreconditionError`: If the system dynamics trait is incompatible with the config type.

# Notes
- Only in-place path is implemented; `pv0 = zeros(...)` guarantees mutability by construction.
- TODO: Add out-of-place path for SVector support in the future.

See also: [`CTFlows.Systems.get_ip_rhs_augmented`](@ref), [`CTFlows.Configs.AbstractAugmentedHamiltonianConfig`](@ref).
"""
function Integrators.build_problem(
    system::Systems.AbstractSystem,
    config::Configs.AbstractAugmentedHamiltonianConfig,
    ::Integrators.SciML;
    variable,
)
    _check_dyn_config(Traits.dynamics_trait(system), config)
    u0 = Configs.initial_condition(config)
    λ  = Common.ODEParameters(variable)
    f! = Systems.get_ip_rhs_augmented(system, config)
    return ODEProblem(f!, u0, Configs.tspan(config), λ)
end
