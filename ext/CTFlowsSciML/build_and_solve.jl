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
- `config::Common.AbstractConfig`: The configuration containing initial condition and time span.
- `variable`: Optional variable parameter for non-fixed systems.

# Returns
- `SciMLBase.ODEProblem`: The ODE problem ready for integration.

# Notes
- The variable parameter is wrapped in `Common.ODEParameters` for uniform access.
- For Hamiltonian systems, the initial condition concatenates `x0` and `p0`.
- `SciMLFunctionSystem` now passes through this generic build_problem via cross-adapters.

See also: [`CTFlows.Systems.rhs`](@ref), [`CTFlows.Systems.rhs_oop`](@ref), [`CTFlows.Common.ODEParameters`](@ref).
"""
function Integrators.build_problem(
    integ::SciML, 
    system::Systems.AbstractSystem, 
    config::Common.AbstractConfig; 
    variable,
    cache=nothing,
    )
    u0 = Common.initial_condition(config)
    p = Common.ODEParameters(variable, cache)
    if ismutable(u0)
        f! = Systems.rhs(system)
        prob = ODEProblem(f!, u0, Common.tspan(config), p)
    else
        f = Systems.rhs_oop(system, false)  # false = is_u0_mutable
        prob = ODEProblem(f, u0, Common.tspan(config), p)
    end
    return prob
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
