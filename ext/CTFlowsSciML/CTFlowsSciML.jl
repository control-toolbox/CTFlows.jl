"""
    CTFlowsSciML

Package extension providing the SciML implementation for `SciML`,
`SciMLFunctionSystem`, `SciMLProblemFlow`, and `ode_problem` for `VectorFieldSystem`.
Activated automatically when `DiffEqBase` and `SciMLBase` are loaded together with `CTFlows`.

This extension provides:
- `real_norm` overload for grid invariance with ForwardDiff
- `Strategies.metadata` for SciML integrator options
- `SciMLFunctionSystem` — wraps a `SciMLBase.AbstractODEFunction` as a CTFlows system
- `SciMLIntegrationResult` — wraps `SciMLBase.AbstractODESolution` for CTFlows
- `Integrators.build_problem` for SciML integrators
- `Integrators.solve_problem` for SciML integrators
- `SciMLProblemFlow` — wraps a `SciMLBase.AbstractODEProblem` as a CTFlows flow
- High-level `Flow(::AbstractODEFunction; ...)` and `Flow(::AbstractODEProblem; ...)` constructors
"""
module CTFlowsSciML

import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Exceptions
import CTSolvers.Strategies
import CTSolvers.Options

using CTFlows: CTFlows
using CTFlows.Common: Common
using CTFlows.Configs: Configs
using CTFlows.Traits: Traits
using CTFlows.Systems: Systems
using CTFlows.Integrators: Integrators, SciML, SciMLTag, Tsit5Tag
using CTFlows.Flows: Flows, AbstractFlow, build_flow
using DiffEqBase: DiffEqBase
using SciMLBase: SciMLBase, ODEProblem

# =============================================================================
# Include files in dependency order
# =============================================================================

include("real_norm.jl")
include("strategies.jl")
include("sciml_rhs_functors.jl")
include("sciml_function_system.jl")
include("integration_result.jl")
include("build_and_solve.jl")
include("problem_flow.jl")
include("flow_constructors.jl")

end # module CTFlowsSciML
