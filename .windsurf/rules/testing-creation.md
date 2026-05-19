---
trigger: glob
glob: "test/**/*.jl"
---

# Julia Testing Standards

## 🤖 **Agent Directive**

**When applying this rule, explicitly state**: "🧪 **Applying Testing Rule**: [specific testing principle being applied]"

This ensures transparency about which testing standard is being used and why.

---

This document defines the testing standards for the CTFlows.jl project. All Julia code modifications must be accompanied by appropriate tests following these guidelines.

## Core Principles

1. **Contract-First Testing**: Define and test contracts (interfaces) first using stubs/mocks to verify correct routing and behavior. Test both public APIs and internal functions when they implement important logic.
2. **Orthogonality**: Tests are independent from source code structure (test organization ≠ src organization)
3. **Isolation**: Unit tests use mocks/fakes to isolate components; integration tests verify interactions
4. **Determinism**: Tests must be reproducible and not depend on external state
5. **Clarity**: Test intent must be immediately obvious from test names and structure

## CTFlows Project Configuration

### Package

```julia
CTFlows
```

### Submodules

| Submodule | Content |
| --- | --- |
| `Common` | `AbstractTag`, `AbstractTrait`, configs, traits, ODE parameters |
| `Data` | `AbstractVectorField`, `HamiltonianVectorField`, `VectorField` |
| `Systems` | `AbstractSystem` subtypes |
| `Flows` | `AbstractFlow`, `Flow`, `MultiPhaseFlow`, building, calling |
| `Integrators` | `AbstractIntegrator`, `AbstractIntegrationResult`, building |
| `Solutions` | Solution building and accessors |

### Import Style

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

### Test Directory Structure

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

### Test Constants

Every test file defines these constants at module level:

```julia
const VERBOSE    = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE    : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true
```

### Test Entry Point Pattern

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

### Extension Access Pattern (for extension test files)

```julia
const CTFlowsSciML = Base.get_extension(CTFlows, :CTFlowsSciML)
const CTFlowsOrdinaryDiffEqTsit5 = Base.get_extension(CTFlows, :CTFlowsOrdinaryDiffEqTsit5)
```

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

## Test Categories

**Vocabulary used in this document:**

- **Fake** — minimal struct that implements the required contract methods; used to isolate the component under test.
- **Stub** — default method on an abstract type that throws `NotImplemented` or `ExtensionError`; tested by calling it on a fake type.
- **Mock** (interaction-recording) — not used in CTFlows; fakes are sufficient.

### 1. Unit Tests

**Purpose**: Test single functions/components in isolation.

**Characteristics:**

- Pure logic, deterministic
- Use fake structs to isolate behavior
- No file I/O, network, or external dependencies
- Fast execution (<1ms per test)

**Example:**

```julia
Test.@testset "UNIT TESTS - Flow Types" begin
    Test.@testset "Flow construction" begin
        flow = Flows.Flow(fake_system, fake_integrator)
        Test.@test flow isa Flows.Flow
        Test.@test flow isa Flows.AbstractFlow
    end
end
```

---

### 2. Integration Tests

**Purpose**: Test interaction between multiple components through a complete workflow.

**Characteristics:**

- Exercise several real module boundaries together
- Use fakes only for leaf dependencies (not for the component chain being tested)
- Slower execution (acceptable up to 1s per test)

**Example:**

```julia
Test.@testset "INTEGRATION TESTS" begin
    Test.@testset "flow building and system access" begin
        sys = FakeSystem(2)   # fake leaf dependency
        integrator = FakeIntegrator()

        # build_flow exercises Flows + Systems + Integrators together
        flow = Flows.build_flow(sys, integrator)
        Test.@test flow isa Flows.AbstractFlow
        Test.@test Flows.system(flow) isa Systems.AbstractSystem
        Test.@test Flows.integrator(flow) isa Integrators.AbstractIntegrator
    end
end
```

---

### 3. Contract Tests

**Purpose**: Verify API contracts using fake implementations.

**Characteristics:**

- Define minimal fake types at top-level (never inside test functions)
- Implement only required contract methods
- Test routing, defaults, and error paths
- Verify Liskov Substitution Principle

**Example:**

```julia
# TOP-LEVEL: Fake type for contract testing
struct FakeSystem <: Systems.AbstractStateSystem{Common.Autonomous, Common.Fixed}
    state_dim::Int
end

# Implement contract
Systems.rhs(sys::FakeSystem) = (du, u, p, t) -> nothing
Systems.state_dimension(sys::FakeSystem) = sys.state_dim

# Test contract
Test.@testset "Contract Implementation" begin
    sys = FakeSystem(2)
    Test.@test Systems.state_dimension(sys) == 2
end
```

---

### 4. Error Tests

**Purpose**: Verify that stubs and error paths throw the right exception with a useful message.

Two sub-cases must be distinguished:

#### 4a. Interface Stubs (`NotImplemented`)

A fake that inherits from an abstract type but does **not** implement a required contract method will trigger the abstract type's stub, which throws `NotImplemented`.

```julia
# TOP-LEVEL: fake that intentionally omits the required method
struct StubIntegrator <: Integrators.AbstractIntegrator end
# (no Integrators.integrate method defined for StubIntegrator)

Test.@testset "Interface stubs" begin
    Test.@testset "integrate throws NotImplemented" begin
        stub = StubIntegrator()
        Test.@test_throws Exceptions.NotImplemented Integrators.integrate(stub, sys, t0, x0, tf)
    end
end
```

#### 4b. Extension Stubs (`ExtensionError`)

Extension stubs throw `ExtensionError` when the required weak dependency is missing. **Always use a fake type** — never a real type — so that the test is independent of whether another test file happens to load the extension.

```julia
# TOP-LEVEL: fake tag for which no extension registers an implementation
struct FakeExtTag <: Common.AbstractTag end

Test.@testset "Extension stubs" begin
    Test.@testset "unknown tag returns missing (fallback behavior)" begin
        result = Integrators.__default_sciml_algorithm(FakeExtTag)
        Test.@test result === missing
    end
end
```

> **Why fake types?** If a real type is used and the extension is loaded (by any other test in the suite), the stub is replaced by the real implementation and the test silently passes or fails for the wrong reason.

---

### Separation Pattern

Use section comments to visually separate categories within a single testset:

```julia
function test_flow_components()
    Test.@testset "Flow Components" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            # Pure unit tests
        end

        # ====================================================================
        # CONTRACT TESTS
        # ====================================================================

        Test.@testset "Contract Implementation" begin
            # Contract tests with fakes
        end

        # ====================================================================
        # INTEGRATION TESTS
        # ====================================================================

        Test.@testset "Integration" begin
            # Multi-component tests
        end

        # ====================================================================
        # ERROR TESTS
        # ====================================================================

        Test.@testset "Error Cases" begin
            # Exception and edge-case tests
        end

    end
end
```

## Critical Rules

### Rule 1 — Struct Definitions at Top-Level

**NEVER define `struct`s inside test functions.** All helper types, mocks, and fakes must be defined at the **module top-level**.

**❌ Wrong:**

```julia
function test_something()
    Test.@testset "Test" begin
        struct FakeType end  # WRONG! Causes world-age issues
    end
end
```

**✅ Correct:**

```julia
module TestSomething

# TOP-LEVEL: Define all structs here
struct FakeType end

function test_something()
    Test.@testset "Test" begin
        obj = FakeType()  # Correct
    end
end

end # module
```

---

### Rule 2 — Import and Qualification Rules

**Use `import` instead of `using`** to avoid namespace pollution:

```julia
import Test
import CTBase.Exceptions
import CTFlows.Common
import CTFlows.Data
import CTFlows.Systems
import CTFlows.Flows
import CTFlows.Integrators
import CTSolvers: CTSolvers
```

**Always qualify method calls**, omitting the root module for submodules:

**✅ Correct:**

```julia
Test.@test_throws Exceptions.IncorrectArgument invalid_call()
Test.@test Flows.system(flow) isa Systems.AbstractSystem
Test.@test Integrators.integrate(integrator, sys, t0, x0, tf) isa Integrators.AbstractIntegrationResult
```

**❌ Wrong:**

```julia
Test.@test_throws CTBase.Exceptions.IncorrectArgument invalid_call()  # Too verbose
Test.@test CTFlows.Flows.system(flow) isa CTFlows.Systems.AbstractSystem  # Too verbose
Test.@test true  # Ambiguous
```

**Why:** Explicit qualification makes test intent clear while avoiding excessive verbosity.

---

### Rule 3 — Export Verification

Add dedicated tests to verify exports and internal symbols:

```julia
Test.@testset "Exports Verification" begin
    Test.@testset "Submodule exports" begin
        for sym in (:AbstractFlow, :Flow, :build_flow)
            Test.@test isdefined(Flows, sym)
        end
    end

    Test.@testset "Package-level non-exports" begin
        for sym in (:_internal_helper,)
            Test.@test isdefined(Flows, sym)          # exists in submodule
            Test.@test !isdefined(CTFlows, sym)       # not re-exported at package level
        end
    end
end
```

---

### Rule 4 — Testing Internal Functions

**Internal functions (prefixed with `_`) should be tested** when they contain significant logic.

**Direct testing** — preferred when logic is complex or has multiple branches:

```julia
Test.@testset "Internal Function Tests" begin
    result = Flows._validate_flow(flow, config)
    Test.@test result isa Bool
    Test.@test result == true
end
```

**Indirect testing** — acceptable when logic is simple or already covered by integration tests:

```julia
Test.@testset "build_flow - validation" begin
    flow = Flows.build_flow(sys, integrator)
    Test.@test Flows.system(flow) isa Systems.AbstractSystem
end
```

**When to test directly:**

- Complex logic with multiple branches
- Error handling paths
- Edge cases hard to trigger via public API

**When to test indirectly:**

- Simple delegation or data transformation
- Logic already covered by integration tests
- Implementation details likely to change

---

### Rule 5 — Test Independence

Each test must be independent and not rely on execution order. Create fresh instances inside each testset:

**✅ Correct:**

```julia
Test.@testset "Test A" begin
    flow = Flows.build_flow(FakeSystem(2), FakeIntegrator())
    # Test A logic
end

Test.@testset "Test B" begin
    flow = Flows.build_flow(FakeSystem(2), FakeIntegrator())  # Fresh instance
    # Test B logic
end
```

**❌ Wrong:**

```julia
flow = Flows.build_flow(...)  # Shared state

Test.@testset "Test A" begin
    # Modifies flow — affects Test B!
end
```

---

### Rule 6 — Stub Testing

Two kinds of stubs exist in CTFlows; each requires a different approach.

#### 6a. Interface Stubs (`NotImplemented`)

An abstract type's default method throws `NotImplemented` when a concrete subtype has not provided an implementation. Test this by creating a **fake that omits the required method**.

```julia
# TOP-LEVEL: fake that deliberately does NOT implement integrate
struct StubIntegrator <: Integrators.AbstractIntegrator end

Test.@testset "Interface stubs" begin
    Test.@testset "integrate stub throws NotImplemented" begin
        stub = StubIntegrator()
        Test.@test_throws Exceptions.NotImplemented Integrators.integrate(stub, sys, t0, x0, tf)
    end
end
```

This test is safe regardless of which extensions are loaded.

#### 6b. Extension Stubs (`ExtensionError` / fallback behavior)

Extension code registers implementations for **known** types. When called with an **unknown** type, the stub (fallback) returns `missing` or throws `ExtensionError`. **Always use a fake type** that no extension knows about.

**Why:** If a real type is used (e.g., `Integrators.SciML`) and the extension is loaded by another test file, the stub is replaced by the real implementation — the test silently passes or fails for the wrong reason.

```julia
# TOP-LEVEL: fake tag — no extension registers an impl for this
struct FakeExtTag <: Common.AbstractTag end

Test.@testset "Extension stubs" begin
    Test.@testset "unknown tag → fallback returns missing" begin
        result = Integrators.__default_sciml_algorithm(FakeExtTag)
        Test.@test result === missing
    end
end
```

**❌ Wrong — real type, load-order dependent:**

```julia
# FAILS when CTFlowsSciML is loaded elsewhere in the suite
Test.@test_throws Exceptions.ExtensionError Integrators.SciML()
```

**Allowed with real types:**

- Type hierarchy checks: `Test.@test Integrators.SciMLIntegrator <: Integrators.AbstractIntegrator`
- Pure metadata methods that don't depend on extension state (`id`, `description`)

---

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
