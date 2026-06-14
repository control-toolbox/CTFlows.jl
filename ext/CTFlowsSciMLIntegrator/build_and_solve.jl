# =============================================================================
# _check_retcode — private helper
# =============================================================================

"""
    _check_retcode(sol, unsafe)

Check the return code of a SciML ODE solution and throw `SolverFailure` if integration failed.

# Arguments
- `sol`: A SciML ODE solution with a `retcode` field.
- `unsafe::Bool`: If `true`, bypass retcode checking; if `false`, throw on failure.

# Throws
- `CTBase.Exceptions.SolverFailure`: If `!unsafe` and the retcode indicates failure.
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
# SciML problem building — actual implementation (generic)
# =============================================================================

"""
$(TYPEDSIGNATURES)

Build an `ODEProblem` from a system and configuration.

Dispatches between in-place and out-of-place RHS based on the mutability of the initial condition:
- If `ismutable(u0)` is true, uses the in-place `rhs(system)` with signature `(du, u, p, t) -> nothing`.
- If `ismutable(u0)` is false (e.g., `StaticArrays.SVector`), uses the out-of-place `rhs_oop(system)` with signature `(u, p, t) -> du`.

This allows zero-allocation integration with immutable array types like `StaticArrays.SVector`.

# Arguments
- `integ::SciML`: The SciML integrator strategy.
- `system::Systems.AbstractSystem`: The system to build an ODE problem for.
- `config::Configs.AbstractConfig`: The configuration containing initial condition and time span.
- `variable`: Optional variable parameter for non-fixed systems.

# Returns
- `SciMLBase.ODEProblem`: The ODE problem ready for integration.

# Notes
- The variable parameter is wrapped in `Common.ODEParameters` for uniform access.
- For Hamiltonian systems, the initial condition concatenates `x0` and `p0`.
- Checks for unsupported combinations (e.g., InPlace VectorField with scalar u0).

See also: [`CTFlows.Systems.rhs`](@ref), [`CTFlows.Common.ODEParameters`](@ref).
"""
function Integrators.build_problem(
    integ::SciML, 
    system::Systems.AbstractSystem, 
    config::Configs.AbstractConfig; 
    variable,
    )
    u0 = Configs.initial_condition(config)
    Systems._check_vf_scalar_inplace(system, u0)  # guard for InPlace VF + scalar
    p = Common.ODEParameters(variable)
    if ismutable(u0)
        f! = Systems.rhs(system)
        prob = ODEProblem(f!, u0, Configs.tspan(config), p)
    else
        f = Systems.rhs_oop(system, false)  # false = is_u0_mutable
        prob = ODEProblem(f, u0, Configs.tspan(config), p)
    end
    return prob
end

"""
$(TYPEDSIGNATURES)

Build an `ODEProblem` for HamiltonianVectorFieldSystem with Hamiltonian configurations.

Constructs lazy RHS closures based on the actual initial condition shapes.

# Arguments
- `integ::SciML`: The SciML integrator strategy.
- `system::Systems.HamiltonianVectorFieldSystem`: The Hamiltonian vector field system.
- `config::Configs.AbstractHamiltonianConfig`: The Hamiltonian configuration (non-augmented).
- `variable`: Variable parameter for the system.
- `cache`: Cache for automatic differentiation.

# Returns
- `SciMLBase.ODEProblem`: The ODE problem with lazy-built RHS.

See also: [`CTFlows.Systems.build_rhs`](@ref), [`CTFlows.Systems.build_oop_rhs`](@ref).
"""
function Integrators.build_problem(
    integ::SciML,
    system::Systems.HamiltonianVectorFieldSystem,
    config::Configs.AbstractHamiltonianConfig;
    variable,
)
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    u0 = Configs.initial_condition(config)
    λ = Common.ODEParameters(variable)
    if ismutable(u0)
        f! = Systems.build_rhs(system, x0, p0)
        prob = ODEProblem(f!, u0, Configs.tspan(config), λ)
    else
        f = Systems.build_oop_rhs(system, x0, p0)
        prob = ODEProblem(f, u0, Configs.tspan(config), λ)
    end
    return prob
end

"""
$(TYPEDSIGNATURES)

Build an `ODEProblem` for HamiltonianSystem with Hamiltonian configurations.

Constructs lazy RHS closures based on the actual initial condition shapes.

# Arguments
- `integ::SciML`: The SciML integrator strategy.
- `system::Systems.HamiltonianSystem`: The Hamiltonian system (AD-based).
- `config::Configs.AbstractHamiltonianConfig`: The Hamiltonian configuration (non-augmented).
- `variable`: Variable parameter for the system.
- `cache`: Cache for automatic differentiation.

# Returns
- `SciMLBase.ODEProblem`: The ODE problem with lazy-built RHS.

See also: [`CTFlows.Systems.build_rhs`](@ref), [`CTFlows.Systems.build_oop_rhs`](@ref).
"""
function Integrators.build_problem(
    integ::SciML,
    system::Systems.HamiltonianSystem,
    config::Configs.AbstractHamiltonianConfig;
    variable,
)
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    t0 = Configs.initial_time(config)
    u0 = Configs.initial_condition(config)
    λ = Common.ODEParameters(variable)
    if ismutable(u0)
        f! = Systems.build_rhs(system, x0, p0, t0, variable)
        prob = ODEProblem(f!, u0, Configs.tspan(config), λ)
    else
        f = Systems.build_oop_rhs(system, x0, p0, t0, variable)
        prob = ODEProblem(f, u0, Configs.tspan(config), λ)
    end
    return prob
end

"""
$(TYPEDSIGNATURES)

Build an `ODEProblem` for augmented Hamiltonian systems.

Specialized overload for `HamiltonianSystem` with `AbstractAugmentedHamiltonianConfig`.
Uses the augmented RHS that computes state, costate, and variable costate derivatives.

# Arguments
- `integ::SciML`: The SciML integrator strategy.
- `system::Systems.HamiltonianSystem`: The Hamiltonian system.
- `config::Configs.AbstractAugmentedHamiltonianConfig`: The augmented Hamiltonian configuration.
- `variable`: Variable parameter for the augmented system.
- `cache`: Cache for automatic differentiation.

# Returns
- `SciMLBase.ODEProblem`: The ODE problem with augmented RHS.

# Notes
- Only in-place implementation (mutable arrays) since `pv0 = zeros(...)` guarantees mutability.
- TODO: Add out-of-place path for SVector support in the future.
- Uses `Systems.build_rhs_augmented` to construct the augmented RHS function.

See also: [`CTFlows.Systems.build_rhs_augmented`](@ref), [`CTFlows.Configs.AbstractAugmentedHamiltonianConfig`](@ref).
"""
function Integrators.build_problem(
    integ::SciML,
    system::Systems.HamiltonianSystem,
    config::Configs.AbstractAugmentedHamiltonianConfig;
    variable,
)
    x0  = Configs.initial_state(config)
    p0  = Configs.initial_costate(config)
    t0  = Configs.initial_time(config)
    u0  = Configs.initial_condition(config)          # vcat(x0, p0, pv0)
    λ   = Common.ODEParameters(variable)
    n_x = length(x0)
    n_v = length(Configs.initial_variable_costate(config))
    f!  = Systems.build_rhs_augmented(system, n_x, n_v, x0, p0, t0, variable)
    return ODEProblem(f!, u0, Configs.tspan(config), λ)
end

# TODO: docstring
function Integrators.build_problem(
    integ::SciML,
    system::Systems.HamiltonianVectorFieldSystem,
    config::Configs.AbstractAugmentedHamiltonianConfig;
    variable,
)
    u0  = Configs.initial_condition(config)          # vcat(x0, p0, pv0)
    λ   = Common.ODEParameters(variable)
    n_x = length(Configs.initial_state(config))
    n_v = length(Configs.initial_variable_costate(config))
    f!  = Systems.build_rhs_augmented(system, n_x, n_v)
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
