"""
    CTFlowsSciMLIntegrator

Package extension providing the CTFlows-side glue between the domain layer
(`Systems`/`Configs`) and the generic ODE-integrator strategy in `CTSolvers.Integrators`.
Activated automatically when `SciMLBase` is loaded together with `CTFlows`.

This extension provides the two functions that must stay in CTFlows because they are typed on
CTFlows' own `Systems`/`Configs`/`Traits`:
- `Integrators.build_problem` — converts CTFlows systems + configs to a SciML `ODEProblem`;
- `Integrators.build_options` — selects the integrator's cached option bundle per config type.

The generic integrator machinery (the `SciML` type, metadata, `build_sciml_integrator`,
`CommonSolve.solve`, the integration-result type, `merge`, and `real_norm`/`deepvalue`) lives
in `CTSolvers.Integrators` and its `CTSolversSciMLIntegrator` extension. The user-facing
`Flow(::AbstractODEFunction)` and `Flow(::AbstractODEProblem)` constructors live in the
`CTFlowsSciMLFlows` extension.
"""
module CTFlowsSciMLIntegrator

using DocStringExtensions: TYPEDSIGNATURES
using CTBase: Exceptions

using CTFlows: CTFlows
using CTFlows: Configs
using CTFlows: Systems
using CTBase: Traits
using CTFlows: Integrators
using SciMLBase: SciMLBase, ODEProblem

# =============================================================================
# Include files in dependency order
# =============================================================================

include("build_options.jl")
include("build_problem.jl")

end # module CTFlowsSciMLIntegrator
