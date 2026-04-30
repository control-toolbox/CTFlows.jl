---
trigger: always_on
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

## Test Organization

### Directory Structure

Tests are organized under `test/suite/` by **functionality**, not by source file structure:

- `suite/systems/`: System types tests (AbstractSystem, concrete systems, MultiPhaseSystem)
- `suite/flows/`: Flow types tests (AbstractFlow, Flow, MultiPhaseFlow)
- `suite/modelers/`: Flow modeler strategy tests (AbstractFlowModeler, concrete modelers)
- `suite/integrators/`: ODE integrator strategy tests (AbstractODEIntegrator, concrete integrators)
- `suite/ad_backends/`: AD backend strategy tests (AbstractADBackend, concrete backends)
- `suite/pipelines/`: Pipeline function tests (build_system, build_flow, integrate, build_solution, solve)
- `suite/exceptions/`: Exception system tests
- `suite/meta/`: Meta tests (Aqua.jl quality checks, exports verification)

### File and Function Naming

**Required pattern:**

- File name: `test_<name>.jl`
- Entry function: `test_<name>()` (matching the filename exactly)

**Example:**

```julia
# File: test/suite/systems/test_abstract_system.jl
module TestAbstractSystem

import Test
import CTBase.Exceptions
import CTFlows.Systems
import CTFlows.Flows

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_abstract_system()
    Test.@testset "Abstract System Tests" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Tests here
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_abstract_system() = TestAbstractSystem.test_abstract_system()
```

## Test Structure

### Module Isolation

Every test file must:

1. Define a module for namespace isolation
2. Define all helper types/functions at **top-level** (never inside test functions)
3. Export the test function to the outer scope

### Unit vs Integration Tests

**Clearly separate** unit and integration tests with section comments:

```julia
function test_system_components()
    Test.@testset "System Components" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================
        
        Test.@testset "Abstract Types" begin
            # Pure unit tests here
        end
        
        # ====================================================================
        # UNIT TESTS - Contract Implementation
        # ====================================================================
        
        Test.@testset "Contract Implementation" begin
            # Contract tests with fakes
        end
        
        # ====================================================================
        # INTEGRATION TESTS
        # ====================================================================
        
        Test.@testset "Integration Tests" begin
            # Multi-component interaction tests
        end
    end
end
```

### Test Categories

#### 1. Unit Tests

**Purpose**: Test single functions/components in isolation

**Characteristics:**

- Pure logic, deterministic
- Use fake structs to isolate behavior
- No file I/O, network, or external dependencies
- Fast execution (<1ms per test)

**Example:**

```julia
Test.@testset "UNIT TESTS - System Types" begin
    Test.@testset "System construction" begin
        sys = Systems.FakeSystem(2)
        Test.@test sys isa Systems.FakeSystem
        Test.@test sys isa Systems.AbstractSystem
    end
end
```

#### 2. Integration Tests

**Purpose**: Test interaction between multiple components

**Characteristics:**

- Exercise complete workflows
- May use temporary directories (`mktempdir`)
- Test component integration
- Slower execution (acceptable up to 1s per test)

**Example:**

```julia
Test.@testset "INTEGRATION TESTS" begin
    Test.@testset "Complete flow workflow" begin
        # Create fake system
        sys = Systems.FakeSystem(2)
        
        # Create fake modeler and integrator
        modeler = Modelers.FakeModeler()
        integrator = Integrators.FakeIntegrator()
        
        # Build flow
        flow = Pipelines.build_flow(sys, integrator)
        Test.@test flow isa Flows.Flow
        
        # Integrate
        xf = Pipelines.integrate(flow, 0.0, [1.0, 0.0], 1.0)
        Test.@test length(xf) == 2
    end
end
```

#### 3. Contract Tests

**Purpose**: Verify API contracts using fake implementations

**Characteristics:**

- Define minimal fake types at top-level
- Implement only required contract methods
- Test routing, defaults, and error paths
- Verify Liskov Substitution Principle

**Example:**

```julia
# TOP-LEVEL: Fake type for contract testing
struct FakeSystem <: Systems.AbstractSystem
    state_dim::Int
end

# Implement contract
Systems.dimensions(sys::FakeSystem) = (n_x=sys.state_dim, n_p=sys.state_dim)
Systems.rhs!(sys::FakeSystem) = (du, u, p, t) -> nothing

# Test contract
Test.@testset "Contract Implementation" begin
    sys = FakeSystem(2)
    dims = Systems.dimensions(sys)
    Test.@test dims.n_x == 2
end
```

#### 4. Error Tests

**Purpose**: Verify error handling and exception quality

**Characteristics:**

- Test `NotImplemented` errors for unimplemented contracts
- Verify exception types and messages
- Test edge cases and invalid inputs
- Ensure graceful failure

**Example:**

```julia
Test.@testset "Error Cases" begin
    Test.@testset "NotImplemented Errors" begin
        sys = MinimalSystem()  # Doesn't implement contract
        Test.@test_throws Exceptions.NotImplemented Systems.dimensions(sys)
    end
    
    Test.@testset "Invalid Arguments" begin
        Test.@test_throws Exceptions.IncorrectArgument Pipelines.build_system(sys, modeler)
    end
end
```

## Critical Rules

### 1. Struct Definitions at Top-Level

**NEVER define `struct`s inside test functions.** All helper types, mocks, and fakes must be defined at the **module top-level**.

**❌ Wrong:**

```julia
function test_something()
    Test.@testset "Test" begin
        struct FakeType end  # WRONG! Causes world-age issues
        # ...
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
        # ...
    end
end

end # module
```

### 2. Import and Qualification Rules

**Use `import` instead of `using`** to avoid namespace pollution:

```julia
import Test
import CTBase.Exceptions
import CTFlows.Systems
import CTFlows.Flows
import CTFlows.Modelers
import CTFlows.Integrators
import CTFlows.Pipelines
```

**Always qualify method calls**, omitting the root module for submodules:

**✅ Correct:**

```julia
# Submodule qualification (omit CTBase/CTFlows root)
Test.@test_throws Exceptions.IncorrectArgument invalid_call()
Test.@test Systems.dimensions(sys) == (n_x=2, n_p=2)
Test.@test Pipelines.build_system(sys, modeler) isa Systems.AbstractSystem
```

**❌ Wrong:**

```julia
# Don't include root module for submodules
Test.@test_throws CTBase.Exceptions.IncorrectArgument invalid_call()  # Too verbose
Test.@test CTFlows.Systems.dimensions(sys) == (n_x=2, n_p=2)  # Too verbose

# Don't use unqualified calls
Test.@test true  # Ambiguous
```

**Why:** Explicit qualification makes test intent clear while avoiding excessive verbosity.

### 3. Export Verification

Add dedicated tests to verify exports and internal symbols:

```julia
Test.@testset "Exports Verification" begin
    # Public API should be exported from submodules
    Test.@testset "Exported Functions" begin
        for f in (:AbstractSystem, :AbstractFlow, :build_system, :build_flow)
            Test.@test isdefined(Systems, f)  # Exported from submodule
        end
    end
    
    # Internal functions should NOT be exported
    Test.@testset "Internal Functions (not exported)" begin
        for f in (:_validate_system, :_build_rhs_internal)
            Test.@test isdefined(Systems, f)  # Exists
            Test.@test !isdefined(CTFlows, f)  # Not exported at package level
        end
    end
end
```

### 4. Testing Internal Functions

**Internal functions (prefixed with `_`) should be tested** when they contain significant logic, even if they're not part of the public API.

**Approaches:**

**1. Direct testing** - Test internal functions directly via qualified calls:

```julia
Test.@testset "Internal Function Tests" begin
    # Test _validate_system directly
    result = Systems._validate_system(sys, dims)
    Test.@test result isa Bool
    Test.@test result == true
end
```

**2. Indirect testing** - Test through public API (when internal logic is simple):

```julia
Test.@testset "build_system - validation" begin
    # This indirectly tests _validate_system and _assemble_internal
    sys = Systems.FakeSystem(2)
    built = Pipelines.build_system(sys, modeler)
    Test.@test Systems.dimensions(built).n_x == 2
end
```

**When to test directly:**

- Complex logic with multiple branches
- Error handling paths
- Edge cases that are hard to trigger via public API

**When to test indirectly:**

- Simple delegation or data transformation
- Logic already covered by integration tests
- Implementation details likely to change

### 5. Test Independence

Each test must be independent and not rely on execution order:

**✅ Correct:**

```julia
Test.@testset "Test A" begin
    sys = Systems.FakeSystem(2)  # Create fresh instance
    # Test A logic
end

Test.@testset "Test B" begin
    sys = Systems.FakeSystem(2)  # Create fresh instance
    # Test B logic
end
```

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

### Documentation

Document complex test setups and non-obvious test logic:

```julia
"""
Fake system for testing the contract interface.

This minimal implementation only provides the required contract methods
to test routing and default behavior without full system complexity.
"""
struct FakeSystem <: Systems.AbstractSystem
    state_dim::Int
end
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

**See also:** `.windsurf/rules/type-stability.md` for comprehensive type stability standards.

#### Type Stability Tests

Type stability is crucial for Julia performance. Test critical functions with `@inferred`:

```julia
Test.@testset "Type Stability" begin
    ocp = create_test_ocp()
    
    # Test type stability of critical functions
    Test.@test_nowarn Test.@inferred Systems.dimensions(sys)
    Test.@test_nowarn Test.@inferred Flows.system(flow)
    Test.@test_nowarn Test.@inferred Pipelines.build_system(sys, modeler)
    
    # Test with different input types
    Test.@test_nowarn Test.@inferred Pipelines.integrate(flow, t0, x0, tf)
    Test.@test_nowarn Test.@inferred Pipelines.build_solution(sys, ode_sol)
end
```

**Important:** `@inferred` only works on **function calls**, not direct field access:

```julia
# ❌ WRONG: @inferred on field access
Test.@inferred flow.system  # ERROR!

# ✅ CORRECT: Wrap in a function
function get_system(flow)
    return Flows.system(flow)
end
Test.@inferred get_system(flow)  # ✅ Works
```

#### Allocation Tests

Test that performance-critical operations don't allocate unnecessarily:

```julia
Test.@testset "Allocations" begin
    ocp = create_test_ocp()
    
    # Test allocation-free operations
    allocs = Test.@allocated Systems.dimensions(sys)
    Test.@test allocs == 0
    
    # Test bounded allocations
    allocs = Test.@allocated Pipelines.build_system(sys, modeler)
    Test.@test allocs < 1000  # bytes
end
```

#### When to Test Type Stability

**Must test:**

- Inner loops and hot paths
- Numerical computations
- Solver internals
- Performance-critical API functions

**Optional:**

- One-time setup code
- User-facing convenience functions
- Error handling paths

#### Debugging Type Instabilities

If `@inferred` fails, use `@code_warntype` to debug:

```julia
julia> @code_warntype Systems.problematic_function(args...)
# Look for red "Any" or yellow warnings
```

## Verification Before Code Changes

### Pre-Implementation Checklist

Before modifying code, verify:

1. **Contract understanding**: What is the expected behavior?
2. **Existing tests**: What tests already exist for this code?
3. **Test coverage**: Are there gaps in current coverage?
4. **Error cases**: What can go wrong?

### Test-First Approach

For new features or bug fixes:

1. **Write failing test** that demonstrates the issue/requirement
2. **Implement fix** to make test pass
3. **Verify** no regressions in existing tests
4. **Refactor** if needed while keeping tests green

**Example workflow:**

```julia
# Step 1: Write failing test
Test.@testset "New feature X" begin
    Test.@test_broken new_function(args) == expected  # Currently fails
end

# Step 2: Implement new_function in src/

# Step 3: Update test
Test.@testset "New feature X" begin
    Test.@test new_function(args) == expected  # Now passes
end
```

## Anti-Patterns to Avoid

### ❌ Don't: Test implementation details

```julia
# BAD: Testing internal field names
Test.@test obj._internal_cache == something
```

### ❌ Don't: Write tests just to pass

```julia
# BAD: Meaningless test
Test.@testset "Function works" begin
    result = some_function()
    Test.@test result == result  # Always true!
end
```

### ❌ Don't: Modify code to make bad tests pass

If tests fail, **fix the root cause**, not the test:

**Wrong approach:**

1. Test fails
2. Change test to pass without understanding why
3. Ship broken code

**Correct approach:**

1. Test fails
2. Understand why (bug in code or test?)
3. Fix the actual issue
4. Verify test now passes for the right reason

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
- [ ] Method calls are qualified (e.g., `CTFlows.Submodule.function_name`)
- [ ] Test names describe what is being tested
- [ ] Each test is independent and deterministic
- [ ] Error cases are tested with `@test_throws`
- [ ] No file I/O or external dependencies in unit tests
- [ ] Fake types implement minimal contracts
- [ ] Tests document non-obvious logic
- [ ] No global mutable state
- [ ] Tests pass locally before committing

## References

- Test execution guide: `testing-execution.md`
- Test README: `test/README.md`
- Test workflows: `@/test-julia`, `@/test-julia-debug`
- Shared test problems: `test/problems/TestProblems.jl`
- Test runner: Uses `CTBase.TestRunner` extension
- Design reference: `reports/design.md`
