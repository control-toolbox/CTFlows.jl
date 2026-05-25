"""
$(TYPEDSIGNATURES)

Convenience call for `StateFlow` with point configuration.

Builds a `StatePointConfig` internally and calls the flow with it.

# Arguments
- `f::StateFlow`: The state flow to integrate.
- `t0::Real`: Initial time.
- `x0`: Initial state vector.
- `tf::Real`: Final time.
- `variable`: The variable parameter value (required for NonFixed systems, optional for Fixed systems).
- `unsafe`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The integrated solution (type varies by system).

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows

julia> flow = StateFlow(system, integrator)

julia> sol = flow(0.0, [1.0, 0.0], 1.0)
\`\`\`

See also: [`CTFlows.Common.StatePointConfig`](@ref), [`CTFlows.Flows.call`](@ref).
"""
function (f::AbstractStateFlow)(
    t0::Real,
    x0,
    tf::Real;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
)
    return call(f, Common.StatePointConfig(t0, x0, tf); variable=variable, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Convenience call for `HamiltonianFlow` with point configuration.

Builds a `HamiltonianPointConfig` internally and calls the flow with it.

# Arguments
- `f::HamiltonianFlow`: The Hamiltonian flow to integrate.
- `t0::Real`: Initial time.
- `x0`: Initial state vector.
- `p0`: Initial costate vector.
- `tf::Real`: Final time.
- `variable`: The variable parameter value (required for NonFixed systems, optional for Fixed systems).
- `unsafe`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The integrated solution (type varies by system).

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows

julia> flow = HamiltonianFlow(system, integrator)

julia> sol = flow(0.0, [1.0, 0.0], [0.5, 0.3], 1.0)
\`\`\`

See also: [`CTFlows.Common.HamiltonianPointConfig`](@ref), [`CTFlows.Flows.call`](@ref).
"""
function (f::AbstractHamiltonianFlow)(
    t0::Real,
    x0,
    p0,
    tf::Real;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
    variable_costate::Bool=Common._variable_costate(),
)
    config = Common.HamiltonianPointConfig(t0, x0, p0, tf)
    variable_costate && return call_variable_costate(f, config; variable=variable, unsafe=unsafe)
    return call(f, config; variable=variable, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Convenience call for `StateFlow` with trajectory configuration.

Builds a `StateTrajectoryConfig` internally and calls the flow with it.

# Arguments
- `f::StateFlow`: The state flow to integrate.
- `tspan::Tuple{Real, Real}`: Time span as a tuple (t0, tf).
- `x0`: Initial state vector.
- `variable`: The variable parameter value (required for NonFixed systems, optional for Fixed systems).
- `unsafe`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The integrated solution (type varies by system).

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows

julia> flow = StateFlow(system, integrator)

julia> sol = flow((0.0, 1.0), [1.0, 0.0])
\`\`\`

See also: [`CTFlows.Common.StateTrajectoryConfig`](@ref), [`CTFlows.Flows.call`](@ref).
"""
function (f::AbstractStateFlow)(
    tspan::Tuple{Real, Real},
    x0;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
)
    return call(f, Common.StateTrajectoryConfig(tspan, x0); variable=variable, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Convenience call for `HamiltonianFlow` with trajectory configuration.

Builds a `HamiltonianTrajectoryConfig` internally and calls the flow with it.

# Arguments
- `f::HamiltonianFlow`: The Hamiltonian flow to integrate.
- `tspan::Tuple{Real, Real}`: Time span as a tuple (t0, tf).
- `x0`: Initial state vector.
- `p0`: Initial costate vector.
- `variable`: The variable parameter value (required for NonFixed systems, optional for Fixed systems).
- `unsafe`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The integrated solution (type varies by system).

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows

julia> flow = HamiltonianFlow(system, integrator)

julia> sol = flow((0.0, 1.0), [1.0, 0.0], [0.5, 0.3])
\`\`\`

See also: [`CTFlows.Common.HamiltonianTrajectoryConfig`](@ref), [`CTFlows.Flows.call`](@ref).
"""
function (f::AbstractHamiltonianFlow)(
    tspan::Tuple{Real, Real},
    x0,
    p0;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
    variable_costate::Bool=Common._variable_costate(),
)
    config = Common.HamiltonianTrajectoryConfig(tspan, x0, p0)
    variable_costate && return call_variable_costate(f, config; variable=variable, unsafe=unsafe)
    return call(f, config; variable=variable, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Solve an ODE problem using a flow with trait-based dispatch on the variable parameter.

This function dispatches to one of four specialized implementations based on:
1. The flow's `VariableDependence` trait (`Fixed` or `NonFixed`)
2. Whether the `variable` parameter was provided (`NotProvided` vs any other type)

# Dispatch Rules
- **`Fixed` + `NotProvided`**: Variable not required, proceeds with `variable=nothing`.
- **`Fixed` + provided**: Throws `PreconditionError` (Fixed systems must not receive a variable).
- **`NonFixed` + provided**: Variable required, proceeds with the provided value.
- **`NonFixed` + `NotProvided`**: Throws `PreconditionError` (NonFixed systems require a variable).

# Arguments
- `flow::CTFlows.Flows.AbstractFlow`: The flow to solve.
- `config::CTFlows.Common.AbstractConfig`: The integration configuration (e.g., `StatePointConfig`, `StateTrajectoryConfig`).
- `variable`: The variable parameter value (required for NonFixed systems, must be omitted for Fixed systems).
- `unsafe`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The packaged solution (type varies by config type).

# Throws
- `CTBase.Exceptions.PreconditionError`: If the variable parameter violates the flow's trait contract.

# Example
\`\`\`julia
# Fixed flow: no variable parameter allowed
flow_fixed = Flow(system_fixed, integrator)
config = CTFlows.Common.StateTrajectoryConfig((0.0, 1.0), [1.0, 0.0])
sol = call(flow_fixed, config; unsafe=false)  # OK, no variable

# NonFixed flow: variable parameter required
flow_nonfixed = Flow(system_nonfixed, integrator)
sol = call(flow_nonfixed, config; variable=0.5, unsafe=false)  # OK, variable provided
\`\`\`

See also: [`CTFlows.Flows.AbstractFlow`](@ref), [`CTFlows.Common.VariableDependence`](@ref), [`CTFlows.Common.NotProvided`](@ref), [`CTFlows.Integrators.build_problem`](@ref), [`CTFlows.Integrators.solve_problem`](@ref), [`CTFlows.Solutions.build_solution`](@ref).
"""
function call(flow::Flows.AbstractFlow, config::Common.AbstractConfig; variable, unsafe)
    VD = Traits.variable_dependence(flow)
    return call(VD, typeof(variable), flow, config; variable=variable, unsafe=unsafe)
end

# =============================================================================
# core_call — implementation body (renamed from call)
# =============================================================================

"""
$(TYPEDSIGNATURES)

Internal implementation body for flow integration.

This function performs the actual ODE integration workflow after trait-based
dispatch has validated the variable parameter. It extracts the system and
integrator from the flow, prepares cache, builds the ODE problem, solves it,
and constructs the solution.

# Arguments
- `flow::CTFlows.Flows.AbstractFlow`: The flow to solve.
- `config::CTFlows.Common.AbstractConfig`: The integration configuration.
- `variable`: The variable parameter value (may be `nothing` for Fixed systems).
- `unsafe`: If `true`, bypass ODE solver retcode checking.

# Returns
- The packaged solution (type varies by config type).

# Notes
This is an internal function called by the trait-dispatch overloads of `call`.
Users should call the public `call` function instead.

See also: [`call`](@ref), [`CTFlows.Integrators.build_problem`](@ref), [`CTFlows.Integrators.solve_problem`](@ref), [`CTFlows.Solutions.build_solution`](@ref).
"""
function core_call(flow::Flows.AbstractFlow, config::Common.AbstractConfig; variable, unsafe)

    # get system and integrator
    sys = system(flow)
    int = integrator(flow)

    # prepare cache for Hamiltonian systems (returns nothing for WithoutAD)
    cache = prepare_cache(sys, config; variable=variable)

    # build ode problem
    prob = Integrators.build_problem(int, sys, config; variable=variable, cache=cache)

    # build config-specific options
    opts = Integrators.build_options(int, config)

    # integrate ode problem
    result = Integrators.solve_problem(int, prob, opts; unsafe=unsafe)

    # build flow solution
    flow_sol = Solutions.build_solution(
        Common.mode_trait(config),
        Common.content_trait(config),
        config,
        result,
    )

    return flow_sol
end

# =============================================================================
# call trait-dispatch overloads
# =============================================================================

"""
$(TYPEDSIGNATURES)

Dispatch for `NonFixed` flows when the variable parameter was not provided.

This overload is selected when a `NonFixed` flow (which requires a variable) is called
without providing the `variable` argument. It throws a `PreconditionError` to enforce
the contract that NonFixed systems must receive a variable parameter.

# Throws
- `CTBase.Exceptions.PreconditionError`: Always, with message explaining that a variable is required.

# See also
[`call`](@ref), [`Common.NonFixed`](@ref), [`Common.NotProvided`](@ref).
"""
function call(::Type{Traits.NonFixed}, ::Type{Common.NotProvided}, flow, config; unsafe, variable)
    throw(Exceptions.PreconditionError(
        "variable not provided for a NonFixed flow";
        reason    = "flow depends on an extra variable parameter but none was given",
        suggestion = "Pass `variable=v` when calling the flow",
        context   = "call — NonFixed flow with missing variable",
    ))
end

"""
$(TYPEDSIGNATURES)

Dispatch for `Fixed` flows when the variable parameter was not provided.

This overload is selected when a `Fixed` flow (which does not require a variable) is called
without providing the `variable` argument. This is the expected and valid case, so it
forwards to `core_call` with `variable=nothing`.

# Returns
- The result of `core_call`.

# See also
[`call`](@ref), [`Common.Fixed`](@ref), [`Common.NotProvided`](@ref), [`core_call`](@ref).
"""
function call(::Type{Traits.Fixed}, ::Type{Common.NotProvided}, flow, config; unsafe, variable)
    return core_call(flow, config; variable=nothing, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Dispatch for `NonFixed` flows when a variable parameter is provided.

This overload is selected when a `NonFixed` flow (which requires a variable) is called
with a provided variable parameter. This is the expected and valid case, so it forwards
to `core_call` with the provided variable value.

# Returns
- The result of `core_call`.

# See also
[`call`](@ref), [`Common.NonFixed`](@ref), [`core_call`](@ref).
"""
function call(::Type{Traits.NonFixed}, ::Type{VT}, flow, config; unsafe, variable) where {VT}
    return core_call(flow, config; variable=variable, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Dispatch for `Fixed` flows when a variable parameter is provided.

This overload is selected when a `Fixed` flow (which does not require a variable) is called
with a provided variable parameter. This violates the contract that Fixed systems must not
receive a variable parameter, so it throws a `PreconditionError`.

# Throws
- `CTBase.Exceptions.PreconditionError`: Always, with message explaining that variables must not be provided to Fixed flows.

# See also
[`call`](@ref), [`Common.Fixed`](@ref).
"""
function call(::Type{Traits.Fixed}, ::Type{VT}, flow, config; unsafe, variable) where {VT}
    throw(Exceptions.PreconditionError(
        "variable provided for a Fixed flow";
        reason    = "flow does not depend on any variable parameter",
        suggestion = "Remove the `variable` keyword argument when calling this flow",
        context   = "call — Fixed flow with unexpected variable",
    ))
end

# ==============================================================================
# prepare_cache — cache preparation for Hamiltonian systems
# ==============================================================================

function prepare_cache(
    sys::Systems.AbstractSystem,
    config::Common.AbstractConfig; variable
)
    return nothing
end

"""
$(TYPEDSIGNATURES)

Prepare an AD cache for a Hamiltonian system based on its AD trait.

This is the front-end entry point that delegates to trait-specific implementations.

# Arguments
- `sys::Systems.AbstractHamiltonianSystem`: The Hamiltonian system.
- `config::Common.AbstractConfig`: The integration configuration (provides typical x0, p0).
- `variable`: The variable parameter value (for type inference in cache preparation).

# Returns
- `nothing` for `WithoutAD` systems (no cache needed).
- The backend-specific cache for `WithAD` systems (e.g., `DifferentiationInterfaceCache`).

# Trait Dispatch
- `WithoutAD` → returns `nothing` (system carries HVF directly).
- `WithAD` → delegates to backend's `prepare_cache` with typical x0, p0.

# Config Type
The `config` argument is typed as `AbstractConfig` (not restricted to `HamiltonianConfig`)
to support augmented configs like `AugmentedHamiltonianPointConfig`, which define
`initial_state` and `initial_costate` via their own getters.

# See also
- [`CTFlows.Differentiation.prepare_cache`](@ref)
- [`CTFlows.Flows.call`](@ref)
"""
function prepare_cache(
    sys::Systems.AbstractHamiltonianSystem,
    config::Common.AbstractConfig; variable
)
    return prepare_cache(Traits.ad_trait(sys), sys, config; variable=variable)
end

"""
$(TYPEDSIGNATURES)

Cache preparation for systems without AD (`WithoutAD` trait).

Returns `nothing` since these systems carry a pre-computed Hamiltonian vector field
and do not require automatic differentiation.

# Arguments
- `::Type{Traits.WithoutAD}`: The `WithoutAD` trait (dispatch tag).
- `sys::Systems.AbstractHamiltonianSystem`: The Hamiltonian system.
- `config::Common.AbstractConfig`: The integration configuration (unused).
- `variable`: The variable parameter value (unused).

# Returns
- `nothing`

# See also
- [`CTFlows.Flows.prepare_cache`](@ref)
"""
function prepare_cache(
    ::Type{Traits.WithoutAD},
    sys::Systems.AbstractHamiltonianSystem,
    config::Common.AbstractConfig; variable
)
    return nothing
end

"""
$(TYPEDSIGNATURES)

Cache preparation for systems with AD (`WithAD` trait).

Extracts typical initial state and costate from the config and delegates to the
backend's `prepare_cache` method to prepare gradient plans.

# Arguments
- `::Type{Traits.WithAD}`: The `WithAD` trait (dispatch tag).
- `sys::Systems.HamiltonianSystem`: The Hamiltonian system (carries `backend` and `h`).
- `config::Common.AbstractConfig`: The integration configuration (provides x0, p0).
- `variable`: The variable parameter value (passed to backend for type inference).

# Returns
- Backend-specific cache (e.g., `DifferentiationInterfaceCache` from the extension).

# See also
- [`CTFlows.Differentiation.prepare_cache`](@ref)
- [`CTFlows.Flows.prepare_cache`](@ref)
"""
function prepare_cache(
    ::Type{Traits.WithAD},
    sys::Systems.AbstractHamiltonianSystem,
    config::Common.AbstractConfig; variable
)
    t0 = Common.initial_time(config)
    x0 = Common.initial_state(config)
    p0 = Common.initial_costate(config)
    return Differentiation.prepare_cache(Systems.backend(sys), Systems.hamiltonian(sys), t0, x0, p0, variable)
end

# =============================================================================
# call_variable_costate — augmented Hamiltonian integration
# =============================================================================

"""
$(TYPEDSIGNATURES)

Call a Hamiltonian flow with variable costate integration.

Dispatches on the flow's `variable_costate_trait` to determine if augmented
integration is supported.

# Arguments
- `flow::AbstractHamiltonianFlow`: The Hamiltonian flow.
- `config::Common.AbstractHamiltonianConfig`: The Hamiltonian point configuration.
- `variable`: The variable parameter value.
- `unsafe`: If `true`, bypass ODE solver retcode checking.

# Returns
- The augmented solution `(xf, pf, pvf)` if supported, or throws an error.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: If the flow does not support variable costate.

See also: [`CTFlows.Traits.variable_costate_trait`](@ref), [`CTFlows.Traits.SupportsVariableCostate`](@ref), [`CTFlows.Traits.NoVariableCostate`](@ref).
"""
function call_variable_costate(
    flow::AbstractHamiltonianFlow,
    config::Common.AbstractHamiltonianConfig; variable, unsafe
)
    return call_variable_costate(
        Traits.variable_costate_trait(flow),
        typeof(variable),
        flow, config; variable=variable, unsafe=unsafe
    )
end

"""
$(TYPEDSIGNATURES)

Variable costate call for flows that do not support it.

This method handles the error case where a flow does not support variable costate computation
(typically because the Hamiltonian is not variable-dependent).

# Throws
- `CTBase.Exceptions.PreconditionError`: Always, with a descriptive message indicating that the flow does not support variable costate.

See also: [`CTFlows.Traits.NoVariableCostate`](@ref).
"""
function call_variable_costate(
    ::Type{Traits.NoVariableCostate},
    ::Type{VT},
    flow::AbstractHamiltonianFlow,
    config::Common.HamiltonianPointConfig; variable, unsafe
) where {VT}
    throw(Exceptions.PreconditionError(
        "variable_costate=true is not supported on this flow";
        reason     = "Only flows built from a variable-dependent scalar Hamiltonian support it",
        suggestion = "Use a Hamiltonian with is_variable=true and an AD backend",
        context    = "HamiltonianFlow call with variable_costate=true",
    ))
end

"""
$(TYPEDSIGNATURES)

Variable costate call for flows that support it.

Constructs an `AugmentedHamiltonianPointConfig` with zero initial variable costate
and calls the flow with it.

# Arguments
- `::Type{Traits.SupportsVariableCostate}`: The capability trait.
- `flow::AbstractHamiltonianFlow`: The Hamiltonian flow.
- `config::Common.HamiltonianPointConfig`: The base Hamiltonian point configuration.
- `variable`: The variable parameter value.
- `unsafe`: If `true`, bypass ODE solver retcode checking.

# Returns
- `Tuple{AbstractVector, AbstractVector, AbstractVector}`: The augmented solution `(xf, pf, pvf)`.

See also: [`CTFlows.Traits.SupportsVariableCostate`](@ref), [`CTFlows.Common.AugmentedHamiltonianPointConfig`](@ref).
"""
function call_variable_costate(
    ::Type{Traits.SupportsVariableCostate},
    ::Type{VT},
    flow::AbstractHamiltonianFlow,
    config::Common.HamiltonianPointConfig; variable, unsafe
) where {VT}
    t0  = Common.initial_time(config) 
    x0  = Common.initial_state(config)
    p0  = Common.initial_costate(config)
    pv0 = Common.scalarize(zeros(eltype(x0), length(variable)), variable)
    tf  = Common.final_time(config)
    config_aug = Common.AugmentedHamiltonianPointConfig(t0, x0, p0, pv0, tf)
    return call(flow, config_aug; variable=variable, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Variable costate call when the variable parameter is not provided.

This method handles the error case where a flow supports variable costate computation
but the user did not provide the required variable parameter.

# Throws
- `CTBase.Exceptions.PreconditionError`: Always, with a descriptive message indicating that the variable parameter must be provided.

See also: [`CTFlows.Traits.SupportsVariableCostate`](@ref), [`CTFlows.Common.NotProvided`](@ref).
"""
function call_variable_costate(
    ::Type{Traits.SupportsVariableCostate},
    ::Type{Common.NotProvided},
    flow::AbstractHamiltonianFlow,
    config::Common.HamiltonianPointConfig; variable, unsafe
)
    throw(Exceptions.PreconditionError(
        "variable must be provided when variable_costate=true";
        reason     = "The system supports variable costate computation, which requires the variable parameter",
        suggestion = "Provide the variable parameter, e.g., flow(t0, x0, p0, tf; variable=v, variable_costate=true)",
        context    = "HamiltonianFlow call with variable_costate=true but no variable provided",
    ))
end

"""
$(TYPEDSIGNATURES)

Variable costate call for trajectory configurations.

Variable costate computation is only supported for point configurations, not trajectory
configurations. This method throws an error when attempting to use variable_costate=true
with a trajectory configuration.

# Throws
- `CTBase.Exceptions.PreconditionError`: Always, with a descriptive message indicating that variable_costate is only supported for point configurations.

See also: [`CTFlows.Traits.SupportsVariableCostate`](@ref), [`CTFlows.Common.HamiltonianTrajectoryConfig`](@ref).
"""
function call_variable_costate(
    ::Type{Traits.SupportsVariableCostate},
    ::Type{VT},
    flow::AbstractHamiltonianFlow,
    config::Common.HamiltonianTrajectoryConfig; variable, unsafe
) where {VT}
    throw(Exceptions.PreconditionError(
        "variable_costate=true is not supported for trajectory configurations";
        reason     = "Variable costate computation is only implemented for point configurations, not full trajectories",
        suggestion = "Use variable_costate=true with a point configuration (t0, x0, p0, tf) instead of a trajectory configuration (tspan, x0, p0)",
        context    = "HamiltonianFlow call with variable_costate=true and HamiltonianTrajectoryConfig",
    ))
end