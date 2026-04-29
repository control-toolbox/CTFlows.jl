"""
    CTFlows

Flow-based integration and optimal control for CTFlows.

CTFlows provides a modular architecture for building and integrating systems
using flow-based approaches. The package is organised into specialised submodules;
all public symbols are accessed via qualified paths (e.g., `CTFlows.Systems.AbstractSystem`).

# Architecture Overview

CTFlows is organised into specialised submodules:

- **Core**: Shared utilities and types
- **Systems**: System types (`AbstractSystem`, `VectorField`, `VectorFieldSystem`) with traits
- **Flows**: Flow types (`AbstractFlow`, `Flow`) combining systems with integrators
- **Integrators**: ODE integrator strategies (`AbstractODEIntegrator`, `SciMLIntegrator`)
- **Pipelines**: High-level pipeline functions (`build_system`, `build_flow`, `integrate`, `solve`, `Flow`)

All submodules export their public API. The package-level module exports nothing;
access symbols via qualified paths like `CTFlows.Systems.AbstractSystem`.
"""
module CTFlows

# ==============================================================================
# Include submodules in topological order
# ==============================================================================

include(joinpath(@__DIR__, "Common", "Common.jl"))
using .Common

include(joinpath(@__DIR__, "Systems", "Systems.jl"))
using .Systems

include(joinpath(@__DIR__, "Integrators", "Integrators.jl"))
using .Integrators

include(joinpath(@__DIR__, "Flows", "Flows.jl"))
using .Flows

include(joinpath(@__DIR__, "Pipelines", "Pipelines.jl"))
using .Pipelines

# ==============================================================================
# No exports at package level
# ==============================================================================

# Users access symbols via qualified paths: CTFlows.Systems.AbstractSystem, etc.

end # module CTFlows
