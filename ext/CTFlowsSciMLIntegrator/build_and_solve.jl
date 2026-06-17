# =============================================================================
# _check_retcode — private helper
# =============================================================================

"""
$(TYPEDSIGNATURES)

Check the return code of a SciML ODE solution and throw `SolverFailure` if integration failed.

# Arguments
- `sol`: A SciML ODE solution with a `retcode` field.
- `unsafe::Bool`: If `true`, bypass retcode checking; if `false`, throw on failure.

# Throws
- `CTBase.Exceptions.SolverFailure`: If `!unsafe` and the retcode indicates failure.

See also: [`CTFlows.Integrators.solve_problem`](@ref).
"""
function _check_retcode(sol, unsafe)
    if !unsafe && !SciMLBase.successful_retcode(sol.retcode)
        throw(Exceptions.SolverFailure(
            "ODE integration failed";
            retcode = string(sol.retcode),
            suggestion = "Try tightening tolerances (reltol, abstol) or changing the solver algorithm.",
            context = "SciML solve_problem",
        ))
    end
end

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
# SciML problem building — unified implementation
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
- `integ::SciML`: The SciML integrator strategy.
- `system::Systems.AbstractSystem`: The system to build an ODE problem for.
- `config::Configs.AbstractConfig`: The configuration containing initial condition and time span.
- `variable`: Variable parameter for non-fixed systems.

# Returns
- `SciMLBase.ODEProblem`: The ODE problem ready for integration.

# Throws
- `CTBase.Exceptions.PreconditionError`: If the system dynamics trait is incompatible with the config type.

See also: [`CTFlows.Systems.get_ip_rhs`](@ref), [`CTFlows.Systems.get_oop_rhs`](@ref), [`CTFlows.Common.ODEParameters`](@ref).
"""
function Integrators.build_problem(
    integ::SciML,
    system::Systems.AbstractSystem,
    config::Configs.AbstractConfig;
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
- `integ::SciML`: The SciML integrator strategy.
- `system::Systems.AbstractSystem`: The Hamiltonian system.
- `config::Configs.AbstractAugmentedHamiltonianConfig`: The augmented Hamiltonian configuration.
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
    integ::SciML,
    system::Systems.AbstractSystem,
    config::Configs.AbstractAugmentedHamiltonianConfig;
    variable,
)
    _check_dyn_config(Traits.dynamics_trait(system), config)
    u0 = Configs.initial_condition(config)
    λ  = Common.ODEParameters(variable)
    f! = Systems.get_ip_rhs_augmented(system, config)
    return ODEProblem(f!, u0, Configs.tspan(config), λ)
end

# =============================================================================
# SciML solve — actual implementation (generic)
# =============================================================================

"""
$(TYPEDSIGNATURES)

Solve an `ODEProblem` using resolved options.
Returns a `SciMLIntegrationResult` wrapping the raw `ODESolution`.

# Arguments
- `integ::SciML`: The SciML integrator strategy.
- `prob::SciMLBase.AbstractODEProblem`: The ODE problem to solve.
- `options::Dict{Symbol,Any}`: Resolved solver options (typically from `build_options`).
- `unsafe=Common.__unsafe()`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- `SciMLIntegrationResult`: The integration result wrapping the SciML ODE solution.

# Throws
- `CTBase.Exceptions.SolverFailure`: If the ODE solver returns an unsuccessful retcode and `unsafe=false`.
"""
function Integrators.solve_problem(integ::SciML, prob::SciMLBase.AbstractODEProblem, options::Dict{Symbol,<:Any}; unsafe=Common.__unsafe())
    ode_sol = SciMLBase.solve(prob; options...)
    _check_retcode(ode_sol, unsafe)
    return SciMLIntegrationResult(ode_sol)
end
