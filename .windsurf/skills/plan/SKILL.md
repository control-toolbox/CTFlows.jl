---
name: plan
description: Standards for writing implementation plans before coding in Julia/CTFlows: plan structure (title, what changes, dependency graph, branch step, numbered implementation steps, interleaved test checkpoints, docstring step, verification step, files summary), ordering rules, naming conventions, checklist. Invoke when creating or reviewing an implementation plan.
---

# Julia Implementation Plan Standards

## 🤖 **Agent Directive**

**When applying this skill, explicitly state**: "📋 **Applying Plan Rule**: [specific planning principle being applied]"

This ensures transparency about which planning standard is being used and why.

---

This document defines how to produce a complete, actionable implementation plan before writing any code. Plans are written first; implementation follows the plan step by step. **Docstrings are never written during implementation — they are a dedicated final step.**

> 📌 **Project-specific names** (package name, module DAG, test paths, branch convention): read `project.md`. Replace its content when adapting this skill to another package.

---

## Core Principles

1. **Plan before code** — a plan must be fully written and reviewed before any file is touched.
2. **One step = one atomic change** — each step modifies a single file or a single cohesive concern. Steps must be independently reviewable.
3. **Dependency-aware ordering** — steps must respect the DAG of submodule dependencies (see `modules.md`). A file that depends on another always comes after it.
4. **Interleaved test checkpoints** — instead of a massive test phase at the end, plans must include regular test checkpoints after logical groups of implementation steps. This provides validation before moving to the next phase.
5. **Docstrings are last** — no docstring is written during implementation steps. A single dedicated step at the very end of the plan writes all docstrings at once, when the code is stable.
6. **No silent assumptions** — any architectural decision made during planning must be stated explicitly in the plan (load-order changes, new exports, removed symbols, etc.).
7. **Skills are cited at the point of use** — every step that triggers a skill from `.windsurf/skills/` must name that skill explicitly so the implementer knows which standard to follow.

---

## Skills Reference

The following skills from `.windsurf/skills/` govern implementation. The plan must mention each skill **at the step where it applies**, not just once globally.

| Skill | Scope | Typical trigger in a plan |
|---|---|---|
| `architecture` | SOLID principles, patterns, module organisation | Any step that introduces a new type, new dependency, or restructures a module |
| `modules` (rule) | Submodule manifests, import style, qualification, export declarations | Any step touching a `<Name>.jl` manifest, import list, or `export` block |
| `exceptions` | Structured exceptions: `NotImplemented`, `IncorrectArgument`, `UnauthorizedCall`, `ParsingError` | Any step adding a stub, a contract method, or an error path |
| `testing-creation` | Test structure, fake types at top-level, unit/integration/contract/error separation | Every test step |
| `testing-execution` (rule) | Running tests, coverage reports | The verification step |
| `type-stability` | `@inferred`, parametric types, avoiding `Any` | Steps introducing new structs or performance-critical functions |
| `performance` | Profiling, benchmarking, allocation reduction | Steps on hot paths or after type-stability work |
| `docstrings` | Docstring templates, `$(TYPEDEF)`, `$(TYPEDSIGNATURES)`, cross-references | The dedicated docstring step only |
| `documentation` (rule) | `docs/` organisation, `make.jl`, API reference generation | If the plan includes a documentation update step |

---

## Plan Structure

A valid plan contains the following sections **in order**:

### 1. Title and summary

```markdown
# <Title of the refactor or feature>

<One-paragraph summary: what changes, why it changes, and what the end state looks like.>
```

### 2. What changes and why

Describe:

- **What is being changed**: files, symbols, types, interfaces.
- **Why**: the architectural motivation (decoupling, new contract, load-order fix, etc.).
- **What disappears**: explicitly list every symbol, callable, or file that is deleted.
- **What is added**: new files, new types, new exports.

### 3. Dependency graph after the change

Always include a dependency diagram showing the new module/file relationships:

```
Module A  →  Module B, Module C
Module B  →  Module D
```

Use the same notation as the existing codebase. This graph drives step ordering in section 5.

### 4. Branch step

Always start with:

```markdown
### Step 0 — Branch

\`\`\`bash
git checkout <base-branch> && git pull
git checkout -b <branch-name>
\`\`\`
```

**Note:** Use `develop` as the base branch if it exists, unless otherwise specified.

### 5. Implementation steps

Number every step starting from 1. Each step must follow this template:

```markdown
### Step N — `path/to/file.jl` [(new file) | (modified)]

> 📐 Follow `architecture` skill — [specific principle, e.g. "new abstract type follows the contract pattern"]
> 🏗️ Follow `modules` rule — [specific rule, e.g. "add export at manifest end; use `using ..Sibling` for imports"]
> ⚠️ Follow `exceptions` skill — [if stubs or error paths are added, e.g. "use `NotImplemented` with `required_method` and `suggestion` fields"]
> 🔬 Follow `type-stability` skill — [if new parametric types or performance-critical functions are introduced]

- <Bullet describing the first change in this file, naming exact symbols>
- <Bullet describing the second change>
- …

> ⛔ Do NOT write docstrings in this step. Leave existing docstrings untouched;
>    new stubs get a single `# TODO: docstring` comment only.
```

Rules for step content:
- **One file per step** when the change is non-trivial. Multiple small related files (e.g. a manifest + one tiny helper) may share a step if they are always changed together.
- **Name the exact symbols** being added, removed, or renamed — no vague language like "update the code".
- **Specify signatures** for new functions: `function build_problem(int::AbstractIntegrator, sys, config; variable)`.
- **Specify struct fields** for new types: `struct SciMLIntegrationResult{S<:SciMLBase.AbstractODESolution}`, field `sol::S`.
- **Call out load-order changes** explicitly when a `using` or `include` order changes in a manifest.
- **Call out export changes**: which symbols are added to or removed from `export`.

### 6. Test checkpoints (Interleaved)

After a logical group of implementation steps, add a dedicated test checkpoint. Continue numbering. Plans should have multiple test checkpoints interspersed rather than one big block at the end.

```markdown
### Step N — Test Checkpoint: <Subsystem/Phase>

> 🧪 Follow `testing-creation` skill — [specific rule, e.g. "define all fake structs at module top-level; separate unit/integration/contract/error testsets"]
> 🔬 Follow `type-stability` skill — [if type-stability tests are needed for new symbols]
> ▶️ Follow `testing-execution` rule — run targeted tests for this phase.

- Define `struct Fake<X> <: <AbstractType>` at module top-level in `test/suite/<subdir>/test_<name>.jl` (never inside test functions).
- Implement the required contract methods on the fake.
- Test sections:
  - `@testset "Contract: NotImplemented errors"` — verify stubs throw correctly.
  - `@testset "Functional: <describe>"` — verify behaviour with fakes.
  - `@testset "Exports"` — verify new exports are present, deleted symbols are gone.
  - `@testset "Type Stability"` — `@inferred` checks on new performance-critical functions (if applicable).
- Run targeted tests:
  \`\`\`bash
  julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["suite/<subdir>"])' 2>&1 | tee /tmp/phase_N.log
  \`\`\`
```

Rules for test steps:
- Every new public symbol gets at least one test.
- Every deleted public symbol gets a regression test confirming it no longer exists.
- Fake types are defined at **module top-level** — never inside test functions (`testing-creation` skill §1).
- Use fake subtypes for stub/extension testing, never real types (`testing-creation` skill §6).
- No extension package imports (e.g. `import SciMLBase`) in files that test pure-Julia contracts.
- A new `test_decoupling.jl` file is added whenever an architectural decoupling is claimed.

### 7. Docstring step (always last implementation activity)

```markdown
### Step N — Docstrings (all modified files)

> 📚 Follow `docstrings` skill — apply `$(TYPEDEF)` / `$(TYPEDSIGNATURES)`, full sections
>    (`# Arguments`, `# Returns`, `# Throws`, `# Example`), `[@ref]` / `[@extref]` cross-references,
>    and safe runnable examples only.

Write or update docstrings for every new or changed public symbol:
- `src/X/y.jl` — `AbstractFoo`, `bar`, `baz`
- `src/Y/z.jl` — `build_something`, `SomeResult`
- `ext/MyExt.jl` — `ConcreteResult`, accessor implementations
- …
```

If the plan also modifies `docs/`, add:

```markdown
> 📖 Follow `documentation` rule — update `docs/api_reference.jl` and `docs/make.jl` if new submodules
>    or extensions are introduced; add/remove entries in `automatic_reference_documentation` calls.
```

### 8. Verification step (always final)

```markdown
### Step N — Run tests

> ▶️ Follow `testing-execution` rule — standard test command below.

\`\`\`bash
julia --project -e 'using Pkg; Pkg.test()' 2>&1 | tee /tmp/<branch_name>.log
grep -E "Error|Fail|Test Summary" /tmp/<branch_name>.log
\`\`\`

Expected: all test suites pass, zero failures, zero errors.
```

### 9. Files summary

Close the plan with a compact table:

```markdown
## Files summary

**New**: `src/X/y.jl`, `test/suite/z/test_w.jl`

**Modified**:
- `src/A/A.jl` — load order, exports  (`modules` rule)
- `src/B/b.jl` — signature change  (`architecture` skill, `exceptions` skill)
- …

**Deleted**: (none) | `src/old_file.jl`
```

---

## Ordering Rules

Apply these rules in order when sequencing steps:

1. **Lower-level modules before higher-level modules** — respect the dependency DAG from the `modules` rule. If `Solutions` is used by `Flows`, all `Solutions` steps come before `Flows` steps.
2. **Manifests after the files they include** — when a manifest's `include` list or `export` list changes, the step for the manifest comes after the steps for the included files.
3. **Extensions after core modules** — extension files (`ext/`) always follow the core module files they extend.
4. **Test checkpoints interleaved** — place test checkpoints immediately after the implementation steps of a logical phase, before moving to the next implementation phase.
5. **Docstring step after all test steps** — docstrings are always the last implementation activity.
6. **Verification step is always the final step**.

---

## Naming Conventions for Steps

| Situation | Step title pattern |
|---|---|
| New file | `Step N — \`path/to/file.jl\` (new file)` |
| Modified file | `Step N — \`path/to/file.jl\`` |
| Group of manifest + small helpers | `Step N — \`src/X/X.jl\` + \`src/X/helpers.jl\`` |
| New test file | `Step N — \`test/suite/x/test_y.jl\` (new file)` |
| Modified test file | `Step N — \`test/suite/x/test_y.jl\`` |
| Test Checkpoint | `Step N — Test Checkpoint: <Subsystem>` |
| Docstring phase | `Step N — Docstrings (all modified files)` |
| Verification | `Step N — Run tests` |

---

## What a Plan Must NOT Contain

- ❌ Any actual Julia code written inline in the plan body (code blocks showing *signatures* and *shapes* are fine; full implementations are not).
- ❌ Docstrings for new symbols (defer to the docstring step).
- ❌ Vague change descriptions ("update the function", "fix the imports") — always name the exact symbol.
- ❌ Steps that mix implementation and testing in the same step (except trivially small changes).
- ❌ Steps that skip the load-order / export impact of a change.
- ❌ A test step that uses `isdefined(Module, :SomePkg)` as a decoupling check — use fake subtypes instead (`testing-creation` skill §6).
- ❌ A step that omits which `.windsurf/skills/` skill (or rule) applies to it.

---

## Checklist Before Handing the Plan to the Implementer

- [ ] Title, summary, and "What changes and why" are present and accurate.
- [ ] Dependency graph is drawn and consistent with the `modules` rule.
- [ ] Every step modifies exactly one file (or a justified small group).
- [ ] Steps are ordered correctly per the DAG and ordering rules above.
- [ ] Every step cites the relevant skill(s) or rule(s) explicitly.
- [ ] Every new public symbol has a corresponding test step.
- [ ] Every deleted public symbol has a regression test step.
- [ ] No docstrings are written before the dedicated docstring step.
- [ ] The docstring step names every file and every symbol that needs a docstring, and cites the `docstrings` skill.
- [ ] If `docs/` is modified, the docstring step also cites the `documentation` rule.
- [ ] The verification step is present, cites the `testing-execution` rule, and uses `Pkg.test()`.
- [ ] The files summary lists new, modified, and deleted files, with the relevant skill/rule beside each entry.
- [ ] Architectural decisions (load-order changes, export additions/removals) are stated explicitly.
