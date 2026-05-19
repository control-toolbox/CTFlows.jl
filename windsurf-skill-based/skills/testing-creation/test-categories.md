# Test Categories

**Vocabulary used in this document:**

- **Fake** — minimal struct that implements the required contract methods; used to isolate the component under test.
- **Stub** — default method on an abstract type that throws `NotImplemented` or `ExtensionError`; tested by calling it on a fake type.
- **Mock** (interaction-recording) — not used in CTFlows; fakes are sufficient.

## 1. Unit Tests

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

## 2. Integration Tests

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

## 3. Contract Tests

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

## 4. Error Tests

**Purpose**: Verify that stubs and error paths throw the right exception with a useful message.

Two sub-cases must be distinguished:

### 4a. Interface Stubs (`NotImplemented`)

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

### 4b. Extension Stubs (`ExtensionError`)

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

## Separation Pattern

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
