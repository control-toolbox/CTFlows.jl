# Project: CTFlows

> **Adaptation guide** — This file contains everything that changes between packages in the control-toolbox ecosystem.
> When copying this skill to another package, only edit this file (and the `description` field in `SKILL.md`).

---

## Package

- **Name**: `CTFlows`
- **Base branch**: `develop`
- **Test entry point**: `test/runtests.jl`
- **Test subdirectory**: `test/suite/<subdir>/test_<name>.jl`
- **Extension directory**: `ext/`

## Module Dependency DAG

```text
Common
  ↓
Data
  ↓
Systems
  ↓
Integrators
  ↓
Flows
  ↓
Solutions
```

Extensions (`ext/`) always come after the core modules they extend.

## Submodule List

| Submodule | Source file | Purpose |
| --- | --- | --- |
| `Common` | `src/Common/Common.jl` | AbstractTag, AbstractTrait, traits, ODE params |
| `Data` | `src/Data/Data.jl` | VectorField, HamiltonianVectorField |
| `Systems` | `src/Systems/Systems.jl` | AbstractSystem subtypes |
| `Integrators` | `src/Integrators/Integrators.jl` | AbstractIntegrator, result types |
| `Flows` | `src/Flows/Flows.jl` | AbstractFlow, Flow, MultiPhaseFlow |
| `Solutions` | `src/Solutions/Solutions.jl` | Solution building and accessors |

## Test Subdirectory Map

| Module(s) under test | Test subdirectory |
| --- | --- |
| Common | `suite/common/` |
| Data | `suite/data/` |
| Systems | `suite/systems/` |
| Integrators | `suite/integrators/` |
| Flows | `suite/flows/` |
| MultiPhaseFlow | `suite/multiphase/` |
| Solutions | `suite/solutions/` |
| Extensions | `suite/extensions/` |
| Aqua.jl / meta | `suite/meta/` |

## Test Run Command

```bash
julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["suite/<subdir>"])' 2>&1 | tee /tmp/<branch>.log
```

Full suite:

```bash
julia --project -e 'using Pkg; Pkg.test()' 2>&1 | tee /tmp/<branch>.log
grep -E "Error|Fail|Test Summary" /tmp/<branch>.log
```
