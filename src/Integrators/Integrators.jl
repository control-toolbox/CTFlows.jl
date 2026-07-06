"""
    Integrators

Domain↔solver glue and re-export layer for ODE integration in CTFlows.

The generic ODE-integrator strategy surface (the `AbstractIntegrator` type, the `SciML`
backend, the `AbstractIntegrationResult` interface, `CommonSolve.solve`, `merge`, and the
option accessors) lives in [`CTSolvers.Integrators`](@extref). This submodule re-exports the
part of that surface consumed inside CTFlows so that existing `Integrators.<symbol>` call
sites keep resolving, and it **owns** the two domain-specific glue functions that must stay in
CTFlows because they are typed on CTFlows' own `Systems`/`Configs`/`Traits`:

- [`CTFlows.Integrators.build_problem`](@ref) — build a SciML `ODEProblem` from a `Systems.AbstractSystem` and a
  `Configs.AbstractConfig`;
- [`CTFlows.Integrators.build_options`](@ref) — select the integrator's cached option bundle for a given config.

Their concrete methods are provided by the `CTFlowsSciMLIntegrator` package extension (loaded
with `SciMLBase`); the stubs here throw `CTBase.Exceptions.ExtensionError` until it is active.
"""
module Integrators

# ==============================================================================
# External package imports
# ==============================================================================

import DocStringExtensions: TYPEDSIGNATURES
import CTBase.Exceptions

# Re-home the CTSolvers integrator surface consumed inside CTFlows so that
# `Integrators.<symbol>` call sites resolve to CTSolvers.
using CTSolvers.Integrators:
    AbstractIntegrator,
    SciML,
    AbstractIntegrationResult,
    final_state,
    times,
    evaluate_at,
    merge,
    build_integrator,
    options_point,
    options_trajectory

# ==============================================================================
# Internal sibling-submodule imports (used by the glue-function signatures)
# ==============================================================================

import ..Configs: Configs
import ..Systems: Systems

# ==============================================================================
# CTFlows-owned glue generics (domain-specific; concrete methods in the ext)
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Build the ODE problem representation from a system and a configuration.

This is the CTFlows-side glue between the domain layer (`Systems`/`Configs`) and the generic
integrator strategy: it constructs the SciML `ODEProblem` that
`CommonSolve.solve` then integrates. The concrete methods are
provided by the `CTFlowsSciMLIntegrator` extension; this stub throws
`CTBase.Exceptions.ExtensionError` until it is loaded.

# Arguments
- `system::CTFlows.Systems.AbstractSystem`: The system providing the right-hand side.
- `config::CTFlows.Configs.AbstractConfig`: The integration configuration (time span, initial
  condition, dynamics kind).
- `integrator::CTSolvers.Integrators.AbstractIntegrator`: The integrator strategy.
- `variable`: The variable parameter value (required for `NonFixed` systems).

# Returns
- A SciML `ODEProblem` (type provided by the extension).

# Throws
- `CTBase.Exceptions.ExtensionError`: If the `CTFlowsSciMLIntegrator` extension is not loaded.

See also: [`build_options`](@ref), [`CTSolvers.Integrators.SciML`](@extref).
"""
function build_problem(
    system::Systems.AbstractSystem,
    config::Configs.AbstractConfig,
    integrator::AbstractIntegrator;
    kwargs...,
)
    return throw(
        Exceptions.ExtensionError(
            :SciMLBase;
            message="to build an ODE problem for a SciML integrator",
            feature="ODE problem building via SciML",
            context="Load SciMLBase (e.g. via OrdinaryDiffEqTsit5) to activate the CTFlowsSciMLIntegrator extension.",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Select the integrator's cached solver options for a given configuration.

This CTFlows-side glue dispatches on the `Configs` config type to return the appropriate
pre-computed option bundle held by the integrator (see
[`CTSolvers.Integrators.options_point`](@extref) /
[`CTSolvers.Integrators.options_trajectory`](@extref)). The concrete methods are provided by
the `CTFlowsSciMLIntegrator` extension; this stub throws `CTBase.Exceptions.ExtensionError`
until it is loaded.

# Arguments
- `integrator::CTSolvers.Integrators.AbstractIntegrator`: The integrator strategy.
- `config`: The integration configuration (a `CTFlows.Configs.AbstractConfig` or `nothing`).

# Returns
- `Dict{Symbol,Any}`: The resolved solver options for the configuration.

# Throws
- `CTBase.Exceptions.ExtensionError`: If the `CTFlowsSciMLIntegrator` extension is not loaded.

See also: [`build_problem`](@ref), [`CTSolvers.Integrators.options_trajectory`](@extref).
"""
function build_options(integrator::AbstractIntegrator, config)
    return throw(
        Exceptions.ExtensionError(
            :SciMLBase;
            message="to build integrator options",
            feature="SciML integrator options",
            context="Load SciMLBase (e.g. via OrdinaryDiffEqTsit5) to activate the CTFlowsSciMLIntegrator extension.",
        ),
    )
end

# ==============================================================================
# Module exports
# ==============================================================================

export AbstractIntegrator, SciML
export AbstractIntegrationResult, final_state, times, evaluate_at, merge
export build_integrator, options_point, options_trajectory
export build_problem, build_options

end # module Integrators
