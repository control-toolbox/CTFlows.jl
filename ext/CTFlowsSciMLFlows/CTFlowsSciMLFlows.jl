"""
    CTFlowsSciMLFlows

Package extension providing user-facing `Flow` constructors from SciML objects.
Activated automatically when `SciMLBase` is loaded together with `CTFlows`.

This extension provides:
- `SciMLFunctionSystem` — wraps a `SciMLBase.AbstractODEFunction` as a CTFlows system
- `SciMLProblemFlow` — wraps a `SciMLBase.AbstractODEProblem` as a CTFlows flow
- High-level `Flow(::AbstractODEFunction; ...)` and `Flow(::AbstractODEProblem; ...)` constructors

The `build_problem`/`build_options` glue lives in the `CTFlowsSciMLIntegrator` extension; the
integration itself is `CommonSolve.solve(prob, integrator)`, implemented by the
`CTSolversSciMLIntegrator` extension of `CTSolvers`.
"""
module CTFlowsSciMLFlows

import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Exceptions
import CTBase.Core
import CommonSolve: CommonSolve

using CTFlows: CTFlows
using CTFlows.Common: Common
using CTFlows.Configs: Configs
using CTBase.Traits: Traits
using CTFlows.Systems: Systems
using CTFlows.Integrators: Integrators
using CTFlows.Flows: Flows, AbstractFlow, build_flow
using SciMLBase: SciMLBase, ODEProblem

# =============================================================================
# Include files in dependency order
# =============================================================================

include("sciml_rhs_functors.jl")
include("sciml_function_system.jl")
include("problem_flow.jl")
include("flow_constructors.jl")

end # module CTFlowsSciMLFlows
