---
name: testing-creation
description: Julia testing standards for CTFlows: contract-first testing, test organization under test/suite/, fake structs defined at module top-level (never inside test functions), unit/integration/contract/error test separation, import qualification rules, export verification, extension stub testing with fake types. Invoke when writing or reviewing test files.
---

# Julia Testing Standards

## 🤖 **Agent Directive**

**When applying this skill, explicitly state**: "🧪 **Applying Testing Rule**: [specific testing principle being applied]"

This ensures transparency about which testing standard is being used and why.

---

This document defines the testing standards for the CTFlows.jl project. All Julia code modifications must be accompanied by appropriate tests following these guidelines.

> 📌 **Project-specific names** (module names, submodule list, test directory structure, import style, test constants): read `project.md`. Replace its content when adapting this skill to another package.

## Core Principles

1. **Contract-First Testing**: Define and test contracts (interfaces) first using stubs/mocks to verify correct routing and behavior. Test both public APIs and internal functions when they implement important logic.
2. **Orthogonality**: Tests are independent from source code structure (test organization ≠ src organization)
3. **Isolation**: Unit tests use mocks/fakes to isolate components; integration tests verify interactions
4. **Determinism**: Tests must be reproducible and not depend on external state
5. **Clarity**: Test intent must be immediately obvious from test names and structure

## Test Organization

### Directory Structure

Tests are organized under `test/suite/` by **functionality**, not by source file structure:

- `suite/common/`: Common types tests (AbstractTag, AbstractTrait, configs, traits, ODE parameters)
- `suite/data/`: Data types tests (AbstractVectorField, HamiltonianVectorField, VectorField)
- `suite/flows/`: Flow types tests (AbstractFlow, Flow, building, calling, callables)
- `suite/integrators/`: Integrator tests (AbstractIntegrator, building, SciML, IntegrationResult)
- `suite/extensions/`: Extension tests (SciML, ForwardDiff, Plots, StaticArrays)
- `suite/multiphase/`: MultiPhase flow tests (concatenation, calling)
- `suite/solutions/`: Solution building tests
- `suite/systems/`: System types tests (AbstractSystem subtypes)
- `suite/meta/`: Meta tests (Aqua.jl quality checks)

### File and Function Naming

**Required pattern:**

- File name: `test_<name>.jl`
- Entry function: `test_<name>()` (matching the filename exactly)

**Example:**

```julia
# File: test/suite/flows/test_abstract_flow.jl
module TestAbstractFlow

import Test
import CTBase.Exceptions
import CTFlows.Common
import CTFlows.Systems
import CTFlows.Flows
import CTFlows.Integrators
import CTFlows.Data
import CTSolvers: CTSolvers

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_abstract_flow()
    Test.@testset "Abstract Flow Tests" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Tests here
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_abstract_flow() = TestAbstractFlow.test_abstract_flow()
```

## Test Structure

### Test Categories (→ read `test-categories.md`)

Four categories: Unit, Integration, Contract, Error — with vocabulary (fake / stub) and the `====` separator pattern. Read `test-categories.md`.

## Critical Rules (→ read `critical-rules.md`)

Six rules to apply when writing any test file. Read `critical-rules.md` for full detail and examples.

1. **Struct definitions at top-level** — never inside test functions (world-age issues)
2. **`import` not `using`** — qualify all calls (`Flows.build_flow`, `Exceptions.NotImplemented`)
3. **Export verification** — test that public symbols are defined, internals are not re-exported
4. **Internal functions** — test `_`-prefixed functions directly when logic is complex
5. **Test independence** — create fresh instances in each testset, no shared mutable state
6. **Stub testing** — interface stubs (`NotImplemented`): fake omits the method; extension stubs (`ExtensionError`): always fake types, never real types (avoids load-order failures)

## Test Quality Standards

### Assertion Quality

**Use specific assertions:**

**✅ Good:**

```julia
Test.@test result ≈ 1.23 atol=1e-10
Test.@test obj isa Systems.AbstractSystem
Test.@test length(components) == 2
Test.@test status == :first_order
```

**❌ Poor:**

```julia
Test.@test result > 0  # Too vague
Test.@test obj != nothing  # Use Test.@test !isnothing(obj)
Test.@test true  # Meaningless
```

### Test Naming

Test names should describe **what** is being tested, not **how**:

**✅ Good:**

```julia
Test.@testset "System construction"
Test.@testset "Contract Implementation - NotImplemented errors"
Test.@testset "Complete workflow - flow building"
```

**❌ Poor:**

```julia
Test.@testset "Test 1"
Test.@testset "Builder"
Test.@testset "Check stuff"
```

## Coverage Requirements

### What to Test

**Must test:**

- ✅ Public API functions and types
- ✅ Contract implementations
- ✅ Error paths and exception handling
- ✅ Edge cases (empty inputs, boundary values, special cases)
- ✅ Type stability (for performance-critical code)
- ✅ Integration between components

**Should test:**

- ⚠️ Internal functions with complex logic
- ⚠️ Validation logic
- ⚠️ Conversion and transformation functions

**Don't test:**

- ❌ Trivial getters/setters without logic
- ❌ External library behavior
- ❌ Generated code (unless custom logic added)

### Performance and Type Stability Tests

For performance-critical code, add type stability and allocation tests.

**See also:** `type-stability` skill for comprehensive standards.

#### Type Stability Tests

`@inferred` only works on **function calls**, not direct field access:

```julia
Test.@testset "Type Stability" begin
    sys = FakeSystem(2)
    flow = build_test_flow(sys)  # helper defined at module top-level

    Test.@test_nowarn Test.@inferred Flows.system(flow)
    Test.@test_nowarn Test.@inferred Integrators.integrate(integrator, sys, t0, x0, tf)

    # ❌ WRONG: @inferred on field access
    # Test.@inferred flow.system  # ERROR!

    # ✅ CORRECT: wrap in a function call
    Test.@test_nowarn Test.@inferred Flows.system(flow)
end
```

#### Allocation Tests

```julia
Test.@testset "Allocations" begin
    sys = FakeSystem(2)
    allocs = Test.@allocated Systems.state_dimension(sys)
    Test.@test allocs == 0
end
```

## Anti-Patterns to Avoid

### ❌ Don't: Test implementation details

```julia
# BAD: Testing internal field names
Test.@test obj._internal_cache == something
```

### ❌ Don't: Use global mutable state

```julia
# BAD: Global state between tests
const GLOBAL_COUNTER = Ref(0)

Test.@testset "Test A" begin
    GLOBAL_COUNTER[] += 1  # Affects other tests!
end
```

### ❌ Don't: Depend on test execution order

```julia
# BAD: Test B depends on Test A running first
Test.@testset "Test A" begin
    global shared_data = compute_something()
end

Test.@testset "Test B" begin
    Test.@test shared_data > 0  # Breaks if A doesn't run first!
end
```

## Quality Checklist

Before finalizing tests, verify:

- [ ] All structs defined at module top-level
- [ ] Unit and integration tests clearly separated
- [ ] Method calls are qualified (e.g., `Systems.function_name`)
- [ ] Test names describe what is being tested
- [ ] Each test is independent and deterministic
- [ ] Error cases are tested with `@test_throws`
- [ ] No file I/O or external dependencies in unit tests
- [ ] Fake types implement minimal contracts
- [ ] Tests document non-obvious logic
- [ ] No global mutable state
- [ ] Tests pass locally before committing

## References

- Test execution: `testing-execution` rule (`.windsurf/rules/testing-execution.md`)
- Test runner entry point: `test/runtests.jl`
