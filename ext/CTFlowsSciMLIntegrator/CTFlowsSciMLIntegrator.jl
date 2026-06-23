"""
    CTFlowsSciMLIntegrator

Package extension providing the SciML integration backend for CTFlows.
Activated automatically when `DiffEqBase` and `SciMLBase` are loaded together with `CTFlows`.

This extension provides:
- `real_norm` overload for grid invariance with ForwardDiff
- `Strategies.metadata` for SciML integrator options
- `build_sciml_integrator` — constructs a `SciML` integrator with pre-computed option caches
- `Integrators.build_options` — resolves solver options per configuration type
- `SciMLIntegrationResult` — wraps `SciMLBase.AbstractODESolution` for CTFlows
- `Integrators.build_problem` — converts CTFlows systems to `ODEProblem`
- `Integrators.solve_problem` — solves an `ODEProblem` and returns a `SciMLIntegrationResult`

This is the backend layer intended to eventually migrate to CTBase.Strategies.
The user-facing `Flow(::AbstractODEFunction)` and `Flow(::AbstractODEProblem)` constructors
live in the `CTFlowsSciMLFlows` extension.
"""
module CTFlowsSciMLIntegrator

import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Exceptions
import CTBase.Strategies
import CTBase.Options

using CTFlows: CTFlows
using CTFlows.Common: Common
using CTFlows.Configs: Configs
using CTFlows.Systems: Systems
using CTFlows.Traits: Traits
using CTFlows.Integrators: Integrators, SciML, SciMLTag, Tsit5Tag
using DiffEqBase: DiffEqBase
using SciMLBase: SciMLBase, ODEProblem

# =============================================================================
# Include files in dependency order
# =============================================================================

include("real_norm.jl")
include("strategies.jl")
include("integration_result.jl")
include("build_and_solve.jl")

end # module CTFlowsSciMLIntegrator
