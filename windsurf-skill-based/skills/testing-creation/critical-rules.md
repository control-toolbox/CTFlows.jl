# Critical Rules

## Rule 1 — Struct Definitions at Top-Level

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

## Rule 2 — Import and Qualification Rules

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

## Rule 3 — Export Verification

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

## Rule 4 — Testing Internal Functions

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

## Rule 5 — Test Independence

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

## Rule 6 — Stub Testing

Two kinds of stubs exist in CTFlows; each requires a different approach.

### 6a. Interface Stubs (`NotImplemented`)

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

### 6b. Extension Stubs (`ExtensionError` / fallback behavior)

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
