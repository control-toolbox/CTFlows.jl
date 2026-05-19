# Project: CTFlows

> **Adaptation guide** — This file contains everything that changes between packages in the control-toolbox ecosystem.
> When copying this skill to another package, only edit this file (and the `description` field in `SKILL.md`).

---

## Package

```julia
CTFlows
```

## Submodules

| Submodule | Content |
| --- | --- |
| `Common` | `AbstractTag`, `AbstractTrait`, configs, traits, ODE parameters |
| `Data` | `AbstractVectorField`, `HamiltonianVectorField`, `VectorField` |
| `Systems` | `AbstractSystem` subtypes |
| `Flows` | `AbstractFlow`, `Flow`, `MultiPhaseFlow`, building, calling |
| `Integrators` | `AbstractIntegrator`, `AbstractIntegrationResult`, building |
| `Solutions` | Solution building and accessors |

## Import Style

Use the `import X: X` qualified form so the submodule name is in scope:

```julia
import CTBase.Exceptions: Exceptions
import CTFlows: CTFlows
import CTFlows.Common: Common
import CTFlows.Data: Data
import CTFlows.Systems: Systems
import CTFlows.Flows: Flows
import CTFlows.Integrators: Integrators
import CTFlows.Solutions: Solutions
import CTSolvers.Strategies: Strategies
import CTSolvers.Options: Options
```

For extension test files that load SciML or StaticArrays, also add:

```julia
using SciMLBase: SciMLBase, ODEProblem
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, Tsit5
import StaticArrays: SA
```

## Test Directory Structure

```text
test/suite/
├── common/        # AbstractTag, AbstractTrait, configs, traits, ODE parameters
├── data/          # AbstractVectorField, HamiltonianVectorField, VectorField
├── flows/         # AbstractFlow, Flow, building, calling, callables
├── integrators/   # AbstractIntegrator, building, SciML, IntegrationResult
├── extensions/    # SciML, ForwardDiff, Plots, StaticArrays
├── multiphase/    # MultiPhase flow tests (concatenation, calling)
├── solutions/     # Solution building
├── systems/       # AbstractSystem subtypes
└── meta/          # Aqua.jl quality checks
```

## Test Constants

Every test file defines these constants at module level:

```julia
const VERBOSE    = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE    : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true
```

## Test Entry Point Pattern

```julia
# Inside the module
function test_<name>()
    Test.@testset "<Description>" verbose=VERBOSE showtiming=SHOWTIMING begin
        # …
    end
end

# CRITICAL: redefine in outer scope so the test runner can call it
test_<name>() = Test<Name>.test_<name>()
```

## Extension Access Pattern (for extension test files)

```julia
const CTFlowsSciML = Base.get_extension(CTFlows, :CTFlowsSciML)
const CTFlowsOrdinaryDiffEqTsit5 = Base.get_extension(CTFlows, :CTFlowsOrdinaryDiffEqTsit5)
```
