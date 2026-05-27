# CTFlows.jl — Agent Navigation Guide

Quick-reference for Cascade: project architecture and available workflows.

---

## Project Overview

**CTFlows.jl** is a Julia package in the [control-toolbox](https://github.com/control-toolbox) ecosystem.
It provides the **flow layer** for optimal control problems: assembling systems, integrating ODEs, and building solutions.

**Stack position:** CTBase → CTModels → **CTFlows** → CTSolvers → OptimalControl

---

## Source Architecture

Submodule layout (all public symbols accessed via qualified paths — no top-level exports):

```
src/
├── CTFlows.jl          # Top-level manifest — exports nothing
├── Common/             # Shared types and tags (AbstractTag, AbstractTrait, …)
├── Data/               # Vector fields and Hamiltonian data structures
├── Flows/              # AbstractFlow, Flow, MultiPhaseFlow, building logic
└── Integrators/        # AbstractODEIntegrator, building logic

ext/
├── CTFlowsSciML/       # SciML ODE integration extension
├── CTFlowsForwardDiff.jl
├── CTFlowsOrdinaryDiffEqTsit5.jl
├── CTFlowsPlots.jl
└── CTFlowsStaticArrays.jl

test/suite/             # Tests organised by functionality (not by src layout)
docs/                   # Documenter.jl site (auto-generated API via CTBase)
```

---

## Windsurf Workflows (always active)

| Workflow | Trigger | Purpose |
|---|---|---|
| `architecture.md` | — | Introducing new types, restructuring modules, reviewing SOLID/patterns |
| `docstrings.md` | — | Writing or reviewing Julia docstrings |
| `documentation.md` | `glob: docs/**/*` | Documenter.jl layout, `make.jl` template, `api_reference.jl`, `InterLinks` setup |
| `exceptions.md` | — | Adding error paths, contract stubs, argument validation |
| `modules.md` | `glob: src/**/*.jl, ext/**/*.jl` | Submodule conventions: qualified imports, manifest pattern, export policy, DAG ordering |
| `performance.md` | — | Hot paths, inner loops, profiling, benchmarking |
| `plan.md` | — | Writing an implementation plan before coding |
| `testing-creation.md` | — | Writing or reviewing test files under `test/suite/` |
| `testing-execution.md` | `model_decision` | How to run tests (commands, `tee` capture, `jtest` alias) |
| `type-stability.md` | — | New structs, parametric types, `@inferred` test design |

Workflows live in `.windsurf/workflows/`.

---

## Key Conventions

- **No top-level exports** — use `CTFlows.Submodule.symbol` everywhere.
- **Qualified imports** — `using PackageName: PackageName`, never bare `using`.
- **Fake types at module top-level** — never inside test functions.
- **Plans before code** — write a full plan (see `plan.md` rule) before touching files.
- **Docstrings last** — written only after all implementation steps are stable.
