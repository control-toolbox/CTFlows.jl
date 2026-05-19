---
trigger: model_decision
---

# Julia Implementation Plan Standards

## 🤖 **Agent Directive**

**When applying this rule, explicitly state**: "📋 **Applying Plan Rule**: [specific planning principle being applied]"

This ensures transparency about which planning standard is being used and why.

---

This document defines how to produce a complete, actionable implementation plan before writing any code. Plans are written first; implementation follows the plan step by step. **Docstrings are never written during implementation — they are a dedicated final step.**

## Core Principles

1. **Plan before code** — a plan must be fully written and reviewed before any file is touched.
2. **One step = one atomic change** — each step modifies a single file or a single cohesive concern. Steps must be independently reviewable.
3. **Dependency-aware ordering** — steps must respect the DAG of submodule dependencies. A file that depends on another always comes after it.
4. **Interleaved test checkpoints** — instead of a massive test phase at the end, plans must include regular test checkpoints after logical groups of implementation steps. This provides validation before moving to the next phase.
5. **Docstrings are last** — no docstring is written during implementation steps. A single dedicated step at the very end of the plan writes all docstrings at once, when the code is stable.
6. **No silent assumptions** — any architectural decision made during planning must be stated explicitly in the plan (load-order changes, new exports, removed symbols, etc.).
7. **Skills are cited at the point of use** — every step that triggers a skill from `.windsurf/skills/` must name that skill explicitly so the implementer knows which standard to follow.

## CTFlows Project Configuration

### Package

- **Name**: `CTFlows`
- **Base branch**: `develop`
- **Test entry point**: `test/runtests.jl`
- **Test subdirectory**: `test/suite/<subdir>/test_<name>.jl`
- **Extension directory**: `ext/`

### Module Dependency DAG

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

### Submodule List

| Submodule | Source file | Purpose |
| --- | --- | --- |
| `Common` | `src/Common/Common.jl` | AbstractTag, AbstractTrait, traits, ODE params |
| `Data` | `src/Data/Data.jl` | VectorField, HamiltonianVectorField |
| `Systems` | `src/Systems/Systems.jl` | AbstractSystem subtypes |
| `Integrators` | `src/Integrators/Integrators.jl` | AbstractIntegrator, result types |
| `Flows` | `src/Flows/Flows.jl` | AbstractFlow, Flow, MultiPhaseFlow |
| `Solutions` | `src/Solutions/Solutions.jl` | Solution building and accessors |

### Test Subdirectory Map

| Module(s) under test | Test subdirectory |
| --- | --- |
| Common | `suite/common/` |
| Data | `suite/data/` |
| Systems | `suite/systems/` |
| Integrators | `suite/integrators/` |
| Flows | `suite/flows/` |
| Solutions | `suite/solutions/` |

## Skills Reference

The following skills from `.windsurf/skills/` govern implementation. The plan must mention each skill **at the step where it applies**, not just once globally.

| Skill | Scope | Typical trigger in a plan |
| --- | --- | --- |
| `architecture` | SOLID principles, patterns, module organisation | Any step that introduces a new type, new dependency, or restructures a module |
| `modules` (rule) | Submodule manifests, import style, qualification, export declarations | Any step touching a `<Name>.jl` manifest, import list, or `export` block |
| `exceptions` (rule) | Structured exceptions: `IncorrectArgument`, `PreconditionError`, `NotImplemented`, `ParsingError`, `AmbiguousDescription`, `ExtensionError`, `SolverFailure` | Any step adding a stub, a contract method, or an error path |
| `testing-creation` (skill) | Test structure, fake types at top-level, unit/integration/contract/error separation | Every test step |
| `testing-execution` (rule) | Running tests, coverage reports | The verification step |
| `type-stability` (skill) | `@inferred`, parametric types, avoiding `Any` | Steps introducing new structs or performance-critical functions |
| `performance` (skill) | Profiling, benchmarking, allocation reduction | Steps on hot paths or after type-stability work |
| `docstrings` (rule) | Docstring templates, `$(TYPEDEF)`, `$(TYPEDSIGNATURES)`, cross-references | The dedicated docstring step only |
| `documentation` (rule) | `docs/` organisation, `make.jl`, API reference generation | If the plan includes a documentation update step |

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

```text
Module A  →  Module B, Module C
Module B  →  Module D
```

Use the same notation as the existing codebase. This graph drives step ordering in section 5.

### 4. Branch step

Always start with:

```markdown
### Step 0 — Branch

\`\`\`bash
git checkout develop && git pull
git checkout -b <branch-name>
\`\`\`
```

**Note:** Use `develop` as the base branch for CTFlows.

### 5. Implementation steps

Number every step starting from 1. Each step must follow this template:

```markdown
### Step N — `path/to/file.jl` [(new file) | (modified)]

> 📐 Follow `architecture` skill — [specific principle, e.g. "new abstract type follows the contract pattern"]
> 🏗️ Follow `modules` rule — [specific rule, e.g. "add export at manifest end; use `using ..Sibling` for imports"]
> ⚠️ Follow `exceptions` rule — [if stubs or error paths are added, e.g. "use `NotImplemented` with `required_method` and `suggestion` fields"]
> 🔬 Follow `type-stability` skill — [if new parametric types or performance-critical functions are introduced]

- <Bullet describing the first change in this file, naming exact symbols>
- <Bullet describing the second change>
- …

> ⛔ Do NOT write docstrings in this step. Leave existing docstrings untouched;
    new stubs get a single `# TODO: docstring` comment only.

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
- Fake types are defined at **module top-level**, never inside test functions.
- Test files are named `test_<name>.jl` and placed in the appropriate `test/suite/<subdir>/` directory.
- Use the test subdirectory map to determine where tests belong.

### 7. Docstring step

The final step (or final steps if large) writes all docstrings at once:

```markdown
### Step N — Docstrings

> 📚 Follow `docstrings` rule — use templates with `$(TYPEDEF)` and `$(TYPEDSIGNATURES)`, include required sections, use CTFlows-qualified references.

- Add docstrings to all newly added public symbols in this phase.
- Replace `# TODO: docstring` comments with proper docstrings.
- Follow the CTFlows docstring conventions (full module paths like `CTFlows.Flows.build_flow`).
- Ensure cross-references use `[@ref]` for internal symbols and `[@extref]` for external symbols.
```

### 8. Verification step

The final step runs the full test suite and checks coverage:

```markdown
### Step N — Verification

> ▶️ Follow `testing-execution` rule — run full test suite with coverage.

- Run full test suite:
  \`\`\`bash
  julia --project -e 'using Pkg; Pkg.test("CTFlows")' 2>&1 | tee /tmp/verification.log
  \`\`\`
- Check coverage if applicable.
- Review test output for failures.
```

### 9. Files summary

List all files touched by the plan:

```markdown
## Files Summary

### New files
- `src/Flows/NewType.jl`
- `test/suite/flows/test_new_type.jl`

### Modified files
- `src/Flows/Flows.jl`
- `src/Flows/building.jl`

### Deleted files
- `src/Flows/OldType.jl`
```

## Naming Conventions

### Branch names

Use descriptive branch names:

```bash
git checkout -b feature/add-hamiltonian-flows
git checkout -b refactor/extract-integrator-interface
git checkout -b fix/ode-integration-stability
```

### Test file names

Test files are named `test_<name>.jl` where `<name>` describes what is being tested:

```julia
test/suite/flows/test_flow.jl
test/suite/integrators/test_sciml_integrator.jl
test/suite/data/test_vector_field.jl
```

## Ordering Rules

1. **Respect the module DAG**: steps touching lower-level modules (Common, Data) come before steps touching higher-level modules (Flows, Solutions).
2. **Manifests last within a module**: when editing a submodule, edit implementation files first, then update the `<Name>.jl` manifest at the end of that module's steps.
3. **Extensions after core**: any step touching `ext/` comes after all core steps are complete.
4. **Tests after implementation**: test checkpoints come after the implementation steps they validate.

## Checklist

Before finalizing a plan, verify:

- [ ] Plan includes a clear title and one-paragraph summary
- [ ] "What changes and why" section is complete
- [ ] Dependency graph shows the new relationships
- [ ] Branch step uses `develop` as base
- [ ] Implementation steps are numbered starting from 1
- [ ] Each step cites relevant skills at the point of use
- [ ] Steps respect the module DAG ordering
- [ ] Test checkpoints are interleaved (not just one at the end)
- [ ] Fake types are defined at module top-level in test steps
- [ ] Docstring step is separate and comes after all implementation
- [ ] Verification step runs the full test suite
- [ ] Files summary lists all new, modified, and deleted files
- [ ] No docstrings are written during implementation steps
- [ ] CTFlows-specific paths and names are used throughout

## Related Rules

- `.windsurf/rules/architecture.md` - Architecture and design principles
- `.windsurf/rules/modules.md` - Submodule conventions
- `.windsurf/rules/exceptions.md` - Exception handling standards
- `.windsurf/rules/docstrings.md` - Documentation standards
- `.windsurf/rules/testing-execution.md` - Test execution standards
