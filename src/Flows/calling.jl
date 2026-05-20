"""
$(TYPEDSIGNATURES)

Solve an ODE problem using a flow.

This performs the integration and builds the solution.

# Arguments
- `flow::CTFlows.Flows.AbstractFlow`: The flow to solve.
- `config::CTFlows.Common.AbstractConfig`: The integration configuration (e.g., `StatePointConfig`, `StateTrajectoryConfig`).
- `variable`: The variable parameter value (required for NonFixed systems, optional for Fixed systems).
- `unsafe`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The packaged solution (type varies by config type).

# Example
\`\`\`julia
# Conceptual usage pattern
flow = Flow(system, integrator)
config = CTFlows.Common.StateTrajectoryConfig((0.0, 1.0), [1.0, 0.0])
sol = call(flow, config; variable=nothing, unsafe=false)
\`\`\`

See also: [`CTFlows.Flows.AbstractFlow`](@ref), [`CTFlows.Integrators.build_problem`](@ref), [`CTFlows.Integrators.solve_problem`](@ref), [`CTFlows.Solutions.build_solution`](@ref).
"""
function call(flow::Flows.AbstractFlow, config::Common.AbstractConfig; variable, unsafe)

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
    flow_sol = Solutions.build_solution(result, sys, config)

    return flow_sol
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
    return prepare_cache(Systems.ad_trait(sys), sys, config; variable=variable)
end

"""
$(TYPEDSIGNATURES)

Cache preparation for systems without AD (`WithoutAD` trait).

Returns `nothing` since these systems carry a pre-computed Hamiltonian vector field
and do not require automatic differentiation.

# Arguments
- `::Type{Common.WithoutAD}`: The `WithoutAD` trait (dispatch tag).
- `sys::Systems.AbstractHamiltonianSystem`: The Hamiltonian system.
- `config::Common.AbstractConfig`: The integration configuration (unused).
- `variable`: The variable parameter value (unused).

# Returns
- `nothing`

# See also
- [`CTFlows.Flows.prepare_cache`](@ref)
"""
function prepare_cache(
    ::Type{Common.WithoutAD},
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
- `::Type{Common.WithAD}`: The `WithAD` trait (dispatch tag).
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
    ::Type{Common.WithAD},
    sys::Systems.HamiltonianSystem,
    config::Common.AbstractConfig; variable
)
    t0 = Common.initial_time(config)
    x0 = Common.initial_state(config)
    p0 = Common.initial_costate(config)
    return Differentiation.prepare_cache(sys.backend, sys.h, t0, x0, p0, variable)
end
