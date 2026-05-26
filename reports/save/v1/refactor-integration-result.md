# Refactor Integration Result Architecture (Points 1 & 2)

Introduce `AbstractIntegrationResult` with semantic accessors to eliminate redundant callables in `AbstractIntegrator` and fully decouple the `Solutions` layer from SciML types.

---

## What changes and why

**Point 1 (fully)**: The three callables on `(int::SciML)(...)` and their wrapper counterparts in `calling.jl` are replaced by two named functions — `build_problem` and `solve_problem` — defined as `NotImplemented` stubs on `AbstractIntegrator` in `abstract_integrator.jl` and implemented in `CTFlowsSciML.jl`. No callable form survives.

**Point 2**: `Solutions` currently imports `SciMLBase` and `build_solution` takes `SciMLBase.AbstractODESolution`. After the refactoring, `Solutions` has no knowledge of SciML: it depends only on `AbstractIntegrationResult` and its semantic accessors (`final_state`, `times`, `evaluate_at`). `SciMLIntegrationResult` lives exclusively in `CTFlowsSciML`.

**Load-order fix**: `Solutions` currently loads after `Flows` in `CTFlows.jl`. Since `Flows.calling` will call `Solutions.build_solution`, `Solutions` must be moved before `Flows`.

---

## Dependency graph after refactoring

```
Flows/calling.jl  →  Integrators, Solutions          (no SciML)
Integrators/      →  Common, Systems                  (no Solutions, no SciML)
Solutions/        →  Common, Systems, AbstractIntegrationResult  (no SciML, no Integrators)
CTFlowsSciML   →  SciML + Solutions + Integrators  (sole owner of .u, .t, interpolation)
CTFlowsPlots   →  Solutions (semantic accessors only)
```

---

## Step-by-step implementation

### Step 0 — Branch

```bash
git checkout develop && git pull
git checkout -b refactor/integration-result-architecture
```

### Step 1 — `src/Solutions/integration_result.jl` (new file)

Define `abstract type AbstractIntegrationResult` and three accessor stubs with `NotImplemented` errors:
- `final_state(r::AbstractIntegrationResult)`
- `times(r::AbstractIntegrationResult)`
- `evaluate_at(r::AbstractIntegrationResult, t::Real)`

Full docstrings (TYPEDEF + TYPEDSIGNATURES, @ref cross-refs).

### Step 2 — `src/Solutions/Solutions.jl`

- `include` the new `integration_result.jl` (before `vector_field_solution.jl`)
- Remove `import SciMLBase`
- Export: `AbstractIntegrationResult`, `final_state`, `times`, `evaluate_at`
- Keep `export raw` removed (see Step 4)

### Step 3 — `src/Solutions/building.jl`

- Change both `build_solution` signatures from `ode_sol::SciMLBase.AbstractODESolution` to `result::AbstractIntegrationResult`
- `StatePointConfig` branch: `final_state(result)` replaces `ode_sol.u[end]`
- `StateTrajectoryConfig` branch: `VectorFieldSolution(result)` (no change to wrapping logic, just different argument type)
- Update docstrings

### Step 4 — `src/Solutions/vector_field_solution.jl`

- Change struct: `struct VectorFieldSolution{R<:AbstractIntegrationResult}`, field `result::R`
- **Remove `raw`** entirely: its return type would silently change from `SciMLBase.AbstractODESolution` to `AbstractIntegrationResult`, breaking callers with no clear error. Semantic accessors fully cover its use.
- Update callable: `(sol::VectorFieldSolution)(t::Real) = evaluate_at(sol.result, t)`
- Add `times(sol::VectorFieldSolution) = times(sol.result)` (needed by Plots)
- Update `Base.show` to use `times(sol.result)` and `final_state(sol.result)`
- Update docstrings (remove SciML references)

### Step 5 — `src/Solutions/Solutions.jl` (export sync)

- Remove `export raw` (raw is deleted)
- Add `export times` (new convenience delegation on VectorFieldSolution)

### Step 6 — `src/Integrators/abstract_integrator.jl`

- Remove ALL three callable stubs `(integrator::AbstractIntegrator)(...)`
- Add two named function stubs with `NotImplemented`:
  ```julia
  function build_problem(int::AbstractIntegrator, sys, config; variable)
      throw(NotImplemented(...))
  end
  function solve_problem(int::AbstractIntegrator, prob)
      throw(NotImplemented(...))
  end
  ```
- Update `AbstractIntegrator` docstring: contract is now two named functions, not callables
- Full docstrings on both stubs

### Step 7 — `src/Integrators/Integrators.jl`

- Export `build_problem`, `solve_problem` (new public contract)

### Step 8 — `src/CTFlows.jl`

- Load order must be: `Common → Data → Systems → Integrators → Solutions → Flows`
- Move `Solutions` include/using **before** `Flows`
- `Integrators` (with exported `build_problem`/`solve_problem`) must already be loaded when `Flows` calls them; `Solutions` must be loaded before `Flows` references `Solutions.build_solution`

### Step 9 — `src/Flows/Flows.jl`

- Add `using ..Solutions` (required for `calling.jl` to call `Solutions.build_solution`)

### Step 10 — `src/Flows/calling.jl`

- Remove the three wrapper functions (`build_problem`, `solve_problem`, `build_solution`)
- Replace `call` body with:
  ```julia
  prob   = Integrators.build_problem(int, sys, config; variable=variable)
  result = Integrators.solve_problem(int, prob)
  return Solutions.build_solution(result, config)
  ```
- Update docstring for `call`

### Step 11 — `ext/CTFlowsSciML.jl`

- Remove all three callables `(integ::SciML)(...)`
- Add `SciMLIntegrationResult{S<:SciMLBase.AbstractODESolution} <: Solutions.AbstractIntegrationResult` struct
- Implement `Solutions.final_state`, `Solutions.times`, `Solutions.evaluate_at` on it
- Replace callable implementations with named function implementations:
  ```julia
  function Integrators.build_problem(int::SciML, sys, config; variable)
      # ODEProblem(...)
  end
  function Integrators.solve_problem(int::SciML, prob)
      ode_sol = SciMLBase.solve(prob; Strategies.options_dict(int)...)
      return SciMLIntegrationResult(ode_sol)
  end
  ```
- Full docstrings

### Step 12 — `ext/CTFlowsPlots.jl`

- Replace `Plots.plot(Solutions.raw(sol))` delegation with semantic accessor approach:
  ```julia
  ts     = Solutions.times(sol)
  states = reduce(hcat, sol.(ts))'  # safe for any state dimension, incl. 1D
  Plots.plot(ts, states; kwargs...)
  ```
- `reduce(hcat, ...)` works whether each `sol(t)` returns a scalar-wrapped vector, a vector, etc.; prefer over `stack(...)` for 1D safety
- Same for `plot!` variants
- Update docstrings

### Step 13 — `test/suite/flows/test_calling.jl`

- `FakeIntegratorForCalling`: remove third callable and `build_solution_called` field
- Implement `Integrators.build_problem(::FakeIntegratorForCalling, ...)` and `Integrators.solve_problem(::FakeIntegratorForCalling, ...)` as named function extensions (not callables)
- `solve_problem` should return a fake that satisfies `Solutions.AbstractIntegrationResult`
- Update test assertions to match new workflow (verify `build_solution` is NOT called on integrator)

### Step 14 — `test/suite/solutions/test_building_solutions.jl`

- Remove `import SciMLBase`
- Replace `FakeODESolution <: SciMLBase.AbstractODESolution` with `FakeIntegrationResult <: Solutions.AbstractIntegrationResult`
- Implement `final_state`, `times`, `evaluate_at` on the fake
- All `build_solution` tests use the new fake — no SciML in this file

### Step 15 — `test/suite/solutions/test_vector_field_solution.jl`

- Remove `import SciMLBase`
- Replace `FakeODESolution` with `FakeIntegrationResult <: Solutions.AbstractIntegrationResult`
- Remove all tests for `raw` (deleted)
- Update callable test to use `evaluate_at` semantics
- Update `Base.show` tests accordingly

### Step 16 — `test/suite/extensions/test_sciml_extension.jl`

- Replace all three callable forms (`integ(sys, config; variable)`, `integ(prob)`, `integ(ode_sol, sys, config)`) with named function calls (`Integrators.build_problem`, `Integrators.solve_problem`)
- Add tests for `SciMLIntegrationResult`: construction, `final_state`, `times`, `evaluate_at`
- Verify `Integrators.solve_problem` returns a `Solutions.AbstractIntegrationResult`

### Step 17 — `test/suite/solutions/test_decoupling.jl` (new, priority)

**Do NOT use `!isdefined(Solutions, :SciMLBase)` as a check** — another test file may have already loaded SciML, making the check unreliable. Use the same pattern as the rest of the test suite: fake subtypes for stub testing, real types (via explicit `using`) for positive testing.

- **Stub tests** (use fake subtypes — always reliable regardless of what is loaded):
  - `struct FakeResult <: Solutions.AbstractIntegrationResult end` at module top-level
  - `@test_throws NotImplemented Solutions.final_state(FakeResult())`
  - `@test_throws NotImplemented Solutions.times(FakeResult())`
  - `@test_throws NotImplemented Solutions.evaluate_at(FakeResult(), 0.0)`

- **Functional decoupling test** (the real architectural guarantee):
  - Define `MockIntegrationResult <: Solutions.AbstractIntegrationResult` — pure Julia, zero SciML imports
  - Implement `final_state`, `times`, `evaluate_at` with deterministic test data
  - `Solutions.build_solution(mock, sys, StatePointConfig)` → returns expected state vector
  - `Solutions.build_solution(mock, sys, StateTrajectoryConfig)` → returns `VectorFieldSolution`
  - `VectorFieldSolution(mock)` callable: `sol(0.5)` returns expected value
  - `Base.show(io, sol)` and `Base.show(io, MIME("text/plain"), sol)` run without error
  - If this passes: `Solutions` is functionally decoupled from SciML regardless of what is loaded elsewhere

- **Symmetrical check**: also verify `Solutions` is decoupled from `Integrators` — the functional test covers this implicitly since `MockIntegrationResult` has no integrator type dependency, but add an explicit assertion `@test !(:Integrators in nameof.(Solutions.usings))` or equivalent if feasible

### Step 18 — Run tests

```bash
julia --project -e 'using Pkg; Pkg.test()' 2>&1 | tee /tmp/ctflows_refactor.log
grep -E "Error|Fail|Test Summary" /tmp/ctflows_refactor.log
```

---

## Files summary

**New**: `src/Solutions/integration_result.jl`, `test/suite/solutions/test_decoupling.jl`

**Modified**:
- `src/CTFlows.jl` — load order
- `src/Solutions/Solutions.jl` — imports, exports, includes
- `src/Solutions/building.jl` — signature change
- `src/Solutions/vector_field_solution.jl` — struct, remove `raw`, new accessors
- `src/Integrators/abstract_integrator.jl` — remove callables, add named stubs
- `src/Integrators/Integrators.jl` — export `build_problem`, `solve_problem`
- `src/Flows/Flows.jl` — add `using ..Solutions`
- `src/Flows/calling.jl` — simplify to `call` only
- `ext/CTFlowsSciML.jl` — remove callables, add `SciMLIntegrationResult`, named impls
- `ext/CTFlowsPlots.jl` — semantic accessors
- `test/suite/flows/test_calling.jl`
- `test/suite/solutions/test_building_solutions.jl`
- `test/suite/solutions/test_vector_field_solution.jl`
- `test/suite/extensions/test_sciml_extension.jl`
