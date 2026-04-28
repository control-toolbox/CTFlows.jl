---
trigger: always_on
---

# Julia Submodule Architecture Standards

## 🤖 **Agent Directive**

**When applying this rule, explicitly state**: "🏗️ **Applying Modules Rule**: [specific principle being applied]"

This ensures transparency about which submodule-architecture principle is being used and why.

---

This document defines the submodule organisation, import conventions, and qualification rules for Julia code in the Control Toolbox ecosystem. The reference implementation is [CTSolvers.jl](https://github.com/control-toolbox/CTSolvers.jl); every package in the stack (including CTFlows) must follow the same pattern so that code, tests, and cross-package imports remain predictable and stable.

## Core Principles

1. **One submodule per concern** — each submodule lives in its own subdirectory `src/<Name>/<Name>.jl` and has a single, well-defined responsibility.
2. **Manifest-only top-level** — the package's top-level file only `include`s subdirectories and does `using .Submodule`; **it exports nothing**.
3. **Submodules export their public API** — every submodule declares `export` for the symbols it considers public; internal helpers stay unexported and are reached via full qualification.
4. **Qualified imports for external packages** — use `using PackageName: PackageName` or `import PackageName.SubModule` instead of bare `using`.
5. **Qualified usage everywhere** — always call sibling-module or external symbols as `Submodule.function` / `Submodule.Type`; never rely on implicit scope.
6. **One-way dependency flow** — submodules form a DAG; lower-level modules cannot import higher-level ones, and there are no cycles.

## Submodule Directory Layout

Each submodule occupies its own subdirectory. The `<Name>.jl` file at the root of that directory is the **manifest**; every other `.jl` file is `include`d by the manifest (possibly from nested subdirectories).

Reference layout (CTSolvers):

```text
src/
├── CTSolvers.jl                        # top-level manifest (exports nothing)
├── Core/
│   └── Core.jl                         # Core manifest
├── Options/
│   ├── Options.jl                      # manifest
│   ├── not_provided.jl
│   ├── option_value.jl
│   ├── option_definition.jl
│   └── extraction.jl
├── Strategies/
│   ├── Strategies.jl                   # manifest
│   ├── display_formatting.jl
│   ├── contract/                       # nested subdirectory
│   │   ├── abstract_strategy.jl
│   │   ├── metadata.jl
│   │   └── strategy_options.jl
│   └── api/
│       ├── registry.jl
│       ├── builders.jl
│       └── …
├── Optimization/
├── Orchestration/
├── Modelers/
├── DOCP/
└── Solvers/
```

Rules:

- A submodule directory contains exactly one manifest named after the module.
- Nested subdirectories (`contract/`, `api/`, …) are allowed for organisation.
- No logic in the manifest — only imports, includes, and exports.

## The Submodule Manifest Pattern

Canonical structure of `src/<Name>/<Name>.jl`:

```julia
"""
Module docstring — purpose, responsibilities, dependencies.
"""
module Name

# 1. External-package imports (qualified, pollution-free)
import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Exceptions
using SolverCore: SolverCore
using ADNLPModels: ADNLPModels

# 2. Internal sibling-submodule imports
using ..Options
using ..Strategies
import ..Core as CTCore
using ..Core: AbstractTag

# 3. Include files (ordered by internal dependency)
include(joinpath(@__DIR__, "abstract_types.jl"))
include(joinpath(@__DIR__, "contract.jl"))
include(joinpath(@__DIR__, "builders.jl"))

# 4. Public API — exports only
export AbstractX, ConcreteX
export build_x, validate_x

end # module Name
```

Ordering rules:

1. Docstring first (module-level documentation).
2. `module` declaration.
3. External-package imports.
4. Internal sibling imports.
5. `include(...)` calls (in dependency order).
6. `export` statements.
7. `end # module Name`.

Section separators (`# ===…===`) are encouraged for readability.

## External Package Import Style

Three acceptable patterns, in order of preference:

### 1. Name-qualified `using` (preferred for packages)

```julia
using SolverCore: SolverCore
using ADNLPModels: ADNLPModels
```

This brings only the module name into scope. Call sites use `SolverCore.solve(...)`, `ADNLPModels.ADNLPModel(...)`.

### 2. Submodule `import`

```julia
import CTBase.Exceptions
```

This makes `Exceptions` available as a qualifier but does not bring its exported symbols into scope. Call sites use `Exceptions.NotImplemented(...)`, `Exceptions.IncorrectArgument(...)`.

### 3. Symbol-qualified `import` (reserved for macros and heavily-used single symbols)

```julia
import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
```

Use only for:

- Macros (cannot be qualified at usage site without awkwardness).
- Single symbols used pervasively where qualification would add noise (rare).

### Forbidden patterns

```julia
# ❌ Bare using — pollutes namespace
using ADNLPModels

# ❌ Symbol-list using — opaque origin at call sites
using CTBase: AbstractModel, Dimension, validate, check
```

## Internal Submodule Import Style

From within a submodule manifest, sibling submodules are reached via the parent scope `..`.

### Importing a whole sibling

```julia
using ..Options
using ..Strategies
```

Brings the submodule name into scope. Call sites use `Options.extract_option(...)`, `Strategies.metadata(...)`.

### Aliasing

```julia
import ..Core as CTCore
```

Use when the original name would conflict with another symbol, or when a shorter internal handle improves readability.

### Specific symbol from a sibling

```julia
using ..Core: AbstractTag
```

Use only when the symbol is pervasive within the current submodule *and* using it unqualified is unambiguous (typically for abstract types inherited from a Core module).

## Qualification at Call Sites

All references to external or sibling-submodule symbols must be qualified. This is the main consequence of the import conventions above.

**✅ Correct:**

```julia
function Strategies.metadata(::Type{<:Modelers.ADNLP{P}}) where {P<:CPU}
    return Strategies.StrategyMetadata(
        Strategies.OptionDefinition(
            name=:backend, type=Symbol, default=:optimized,
            description="AD backend used by ADNLPModels",
        ),
    )
end

throw(
    Exceptions.NotImplemented(
        "Model building not implemented";
        required_method = "(modeler::$(typeof(modeler)))(prob::Optimization.AbstractOptimizationProblem, initial_guess)",
        suggestion = "Implement the callable method for $(typeof(modeler)) to build NLP models",
        context = "AbstractNLPModeler - required method implementation",
    ),
)
```

**❌ Wrong — unqualified, fragile to refactoring:**

```julia
# Where does StrategyMetadata come from? ADNLP? CPU?
function metadata(::Type{<:ADNLP{P}}) where {P<:CPU}
    return StrategyMetadata(
        OptionDefinition(name=:backend, type=Symbol, default=:optimized),
    )
end
```

### Why qualification matters

- **Explicit origin at every call site** — readers immediately see which submodule a symbol belongs to.
- **Refactor safety** — if `Strategies` is renamed or moved, only the `using ..Strategies` line changes; all call sites stay correct as long as the new import uses the same name (or is aliased to it).
- **No accidental shadowing** — qualified names cannot be captured by a local variable with the same stem.
- **Cross-package consistency** — the same pattern works for external packages (`Exceptions.NotImplemented`) and sibling submodules (`Strategies.metadata`).

## Dependency Order and the DAG

The loading order in the top-level manifest must reflect a correct topological order of submodule dependencies.

Reference DAG (CTSolvers):

```text
Core
 ├── Options
 │    └── Strategies
 │         ├── Orchestration
 │         └── Optimization
 │              ├── Modelers
 │              │    └── DOCP
 │              │         └── Solvers
```

Rules:

- The top-level manifest lists `include`/`using` calls in topological order.
- A submodule can only `using ..Lower` where `Lower` was already loaded.
- **No cycles** — if two submodules need each other, extract the shared concern into a lower-level submodule (typically `Core` or a dedicated `Types` module).

## Exports and Public API

Two-level rule:

- **Submodule level** — each submodule declares `export` at the end of its manifest for the symbols that form its public API. Internal helpers (names prefixed with `_`, or kept unexported by convention) stay unexported and are reached via full qualification.
- **Top-level (package) level** — the package manifest **exports nothing**. It only loads submodules with `using .Submodule` so they become accessible as `Package.Submodule`. There are **no `export` statements** at the top level.

### Consequences

- Users access public symbols via `Package.Submodule.sym` — explicit, stable, self-documenting.
- Adding a new public symbol in a submodule is a local change (one `export` line).
- Moving a symbol between submodules is visible at the call site (the qualification changes).
- Namespace conflicts between submodules cannot occur at package load time, because nothing is brought into the package-level scope.

### Top-level manifest example

```julia
"""
    CTFlows

Brief description of the package.

# Architecture Overview

CTFlows is organised into specialised submodules; all public symbols are
accessed via qualified paths (e.g. `CTFlows.Systems.AbstractSystem`).
"""
module CTFlows

include(joinpath(@__DIR__, "Core", "Core.jl"))
using .Core

include(joinpath(@__DIR__, "Systems", "Systems.jl"))
using .Systems

include(joinpath(@__DIR__, "Modelers", "Modelers.jl"))
using .Modelers

# … more submodules …

# NO export statements here.

end # module CTFlows
```

### User access patterns

```julia
using CTFlows                          # brings no symbols into scope directly
CTFlows.Systems.AbstractSystem         # fully qualified (recommended)

using CTFlows.Systems                  # brings Systems exports into scope
AbstractSystem                         # unqualified (user's choice, at their own risk)
```

The `export` inside each submodule makes the unqualified form available to users who explicitly opt in via `using CTFlows.Submodule`. The package-level `using CTFlows` remains silent.

## Proposed CTFlows Layout

Informed by [`reports/design.md`](../../reports/design.md), the CTFlows submodule breakdown mirrors CTSolvers' separation of concerns:

```text
src/
├── CTFlows.jl                  # top-level manifest, exports nothing
├── Core/Core.jl                # shared types and utilities
├── Systems/Systems.jl          # AbstractSystem + concrete systems + MultiPhaseSystem
├── Flows/Flows.jl              # AbstractFlow, Flow, MultiPhaseFlow
├── Modelers/Modelers.jl        # AbstractFlowModeler + concrete modelers
├── Integrators/Integrators.jl  # AbstractODEIntegrator + concrete integrators
├── ADBackends/ADBackends.jl    # AbstractADBackend + concrete backends
└── Pipelines/Pipelines.jl      # build_system, build_flow, integrate, build_solution, solve
```

Dependency order (topologically sorted):

```text
Core
 ├── Systems
 ├── Integrators
 ├── ADBackends
 ├── Modelers         (depends on Systems, ADBackends)
 ├── Flows            (depends on Systems, Integrators)
 └── Pipelines        (depends on all of the above)
```

The `Options` and `Strategies` infrastructure is consumed from CTSolvers via standard package imports (`using CTSolvers: CTSolvers` then qualified calls like `CTSolvers.Strategies.AbstractStrategy`).

## Quality Checklist

Before finalising a submodule or a package restructure, verify:

- [ ] Each submodule lives in its own subdirectory with a `<Name>.jl` manifest.
- [ ] The manifest contains only a docstring, `module`, imports, `include`s, `export`s, and `end`.
- [ ] External-package imports use `using Pkg: Pkg`, `import Pkg.Sub`, or (for macros) `import Pkg: sym`.
- [ ] Internal imports use `using ..Sibling`, `import ..Sibling as Alias`, or `using ..Sibling: Sym`.
- [ ] All references to sibling or external symbols are fully qualified at call sites.
- [ ] The dependency graph is acyclic and respected by the top-level loading order.
- [ ] Each submodule declares `export` for its public API.
- [ ] The top-level package manifest contains **no** `export` statements.
