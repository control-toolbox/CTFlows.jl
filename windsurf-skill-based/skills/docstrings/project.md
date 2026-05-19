# Project: CTFlows

> **Adaptation guide** — This file contains everything that changes between packages in the control-toolbox ecosystem.
> When copying this skill to another package, only edit this file (and the `description` field in `SKILL.md`).

---

## Package

- **Name**: `CTFlows`
- **Root module**: `CTFlows`

## Submodule Qualification

Public symbols are always accessed through their submodule, never through the root package:

```julia
CTFlows.Flows.build_flow(...)    # ✅ correct
CTFlows.build_flow(...)          # ❌ wrong — nothing exported at root level
```

## Exposed Submodules

| Submodule | Exported symbols (examples) |
| --- | --- |
| `CTFlows.Common` | `AbstractTag`, `AbstractTrait`, `Autonomous`, `Fixed` |
| `CTFlows.Data` | `VectorField`, `HamiltonianVectorField` |
| `CTFlows.Systems` | `AbstractSystem`, `AbstractStateSystem` |
| `CTFlows.Flows` | `AbstractFlow`, `Flow`, `MultiPhaseFlow` |
| `CTFlows.Integrators` | `AbstractIntegrator`, `AbstractIntegrationResult` |
| `CTFlows.Solutions` | `AbstractSolution` |

## Cross-Reference Style

```julia
# In docstrings, use the full qualified path:
# See also: [`CTFlows.Flows.build_flow`](@ref)
# See also: [`CTFlows.Flows.AbstractFlow`](@ref)
```

For inter-package cross-references (e.g., to CTBase):

```julia
# See also: [`CTBase.Exceptions.NotImplemented`](@extref)
```

## `@extref` Packages Registered in `docs/make.jl`

- `CTBase` — base types, exceptions, docstring extensions
- `CTSolvers` — strategy metadata, options

## Module Prefix in Docstrings

When a docstring is defined inside `src/Flows/flow.jl`, the public prefix shown in the docs is `CTFlows.Flows.`:

```julia
"""
$(TYPEDSIGNATURES)

Build a flow from a system and an integrator.

See also: [`CTFlows.Flows.AbstractFlow`](@ref), [`CTFlows.Systems.AbstractSystem`](@ref)
"""
function build_flow(sys::AbstractSystem, integrator::AbstractIntegrator)
```
