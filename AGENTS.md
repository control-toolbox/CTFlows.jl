# CTFlows.jl — Agent Navigation Guide

Quick-reference for Cascade: project architecture, available skills, and active rules.

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

## Windsurf Skills

Skills are loaded on demand (progressive disclosure — no permanent token cost).
Invoke by name or let the model decide based on context.

| Skill | When to use |
|---|---|
| `architecture` | Introducing new types, restructuring modules, reviewing SOLID/patterns |
| `plan` | Writing an implementation plan before coding |
| `testing-creation` | Writing or reviewing test files under `test/suite/` |
| `docstrings` | Writing or reviewing Julia docstrings |
| `exceptions` | Adding error paths, contract stubs, argument validation |
| `performance` | Hot paths, inner loops, profiling, benchmarking |
| `type-stability` | New structs, parametric types, `@inferred` test design |

Skills live in `.windsurf/skills/<name>/SKILL.md`.

---

## Windsurf Rules (always active)

| Rule | Trigger | Purpose |
|---|---|---|
| `modules.md` | `glob: src/**/*.jl, ext/**/*.jl` | Submodule conventions: qualified imports, manifest pattern, export policy, DAG ordering |
| `documentation.md` | `glob: docs/**/*` | Documenter.jl layout, `make.jl` template, `api_reference.jl`, `InterLinks` setup |
| `testing-execution.md` | `model_decision` | How to run tests (commands, `tee` capture, `jtest` alias) |

Rules live in `.windsurf/rules/`.

---

## Key Conventions

- **No top-level exports** — use `CTFlows.Submodule.symbol` everywhere.
- **Qualified imports** — `using PackageName: PackageName`, never bare `using`.
- **Fake types at module top-level** — never inside test functions.
- **Plans before code** — write a full plan (see `plan` skill) before touching files.
- **Docstrings last** — written only after all implementation steps are stable.
