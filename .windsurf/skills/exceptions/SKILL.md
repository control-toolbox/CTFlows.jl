---
name: exceptions
description: Julia exception standards for CTFlows/Control Toolbox: seven exception types (IncorrectArgument, PreconditionError, NotImplemented, ParsingError, AmbiguousDescription, ExtensionError, SolverFailure) with fields, usage patterns, anti-patterns, and testing. Invoke when adding error paths, contract stubs, argument validation, state machine violations, extension stubs, or solver failures.
---

# Julia Exception Standards

## 🤖 **Agent Directive**

**When applying this skill, explicitly state**: "⚠️ **Applying Exception Rule**: [specific exception principle being applied]"

This ensures transparency about which exception standard is being used and why.

---

This document defines the exception handling standards for the Control Toolbox project. All error conditions must be handled using structured, informative exceptions that provide clear guidance to users.

## Core Principles

1. **Clear Messages**: Error messages must be immediately understandable
2. **Actionable Suggestions**: Provide guidance on how to fix the problem
3. **Rich Context**: Include what was expected, what was received, and where
4. **User-Friendly**: Format errors for end users, not just developers

## Exception Types (→ read `exception-types.md`)

Seven types are available. Read `exception-types.md` for fields, examples, "when to use", and the Quick Reference table.

- **`IncorrectArgument`** — invalid argument value, type mismatch, out of range
- **`PreconditionError`** — wrong call order, state machine violation, uninitialized object
- **`NotImplemented`** — abstract interface stub, extension point, unimplemented feature
- **`ParsingError`** — DSL syntax error, configuration parsing
- **`AmbiguousDescription`** — symbol tuple not matched in description-based API
- **`ExtensionError`** — optional dependency (weak dep) not loaded
- **`SolverFailure`** — ODE integrator or optimization solver failure

## Best Practices

### Write Clear Messages

**✅ Good - Specific and clear:**

```julia
throw(IncorrectArgument(
    "State dimension must be positive",
    got="n = -1",
    expected="n > 0",
    suggestion="Provide a positive integer for state dimension"
))
```

**❌ Bad - Vague:**

```julia
throw(IncorrectArgument("Invalid input"))
```

### Use Appropriate Exception Types

**✅ Good - Correct type:**

```julia
throw(IncorrectArgument("n must be positive", got="n = -1", expected="n > 0"))
throw(PreconditionError("Cannot modify frozen OCP", reason="OCP is immutable"))
throw(NotImplemented("solve! not implemented", required_method="solve!(::MyStrategy, ...)"))
```

**❌ Bad - Wrong type:**

```julia
throw(IncorrectArgument("OCP already finalized"))  # Should be PreconditionError
throw(PreconditionError("n must be positive"))      # Should be IncorrectArgument
```

## Common Patterns

### Validation Pattern

```julia
function validate_dimension(n::Int, name::String)
    if n <= 0
        throw(IncorrectArgument(
            "Dimension must be positive",
            got="$name = $n",
            expected="$name > 0",
            suggestion="Provide a positive integer for $name"
        ))
    end
end
```

### State Machine Pattern

```julia
mutable struct OCP
    state_defined::Bool
end

function state!(ocp::OCP, n::Int)
    if ocp.state_defined
        throw(PreconditionError(
            "Cannot call state! twice",
            reason="state has already been defined for this OCP",
            suggestion="Create a new OCP instance"
        ))
    end
    ocp.state_defined = true
end
```

### Interface Pattern

```julia
abstract type AbstractStrategy end

function solve!(strategy::AbstractStrategy, problem)
    throw(NotImplemented(
        "solve! must be implemented for each strategy type",
        type_info=string(typeof(strategy)),
        suggestion="Define solve!(::$(typeof(strategy)), problem) or import the relevant package"
    ))
end
```

## Testing Exceptions

```julia
@testset "Exception Types" begin
    @test_throws IncorrectArgument invalid_function(bad_arg)

    err = try
        invalid_function(bad_arg)
    catch e
        e
    end
    @test err isa IncorrectArgument
    @test occursin("Invalid criterion", err.msg)
end
```

## Quality Checklist

Before finalizing exception handling, verify:

- [ ] Exception type is appropriate (IncorrectArgument, PreconditionError, NotImplemented, ParsingError, AmbiguousDescription, ExtensionError, SolverFailure)
- [ ] Error message is clear and specific
- [ ] `got` and `expected` fields provided when applicable
- [ ] Actionable `suggestion` provided
- [ ] `context` provided for complex errors
- [ ] Exception is tested with `@test_throws`
- [ ] Error message is user-friendly (no jargon)
- [ ] Suggestion is concrete and actionable

## Anti-Patterns

```julia
# ❌ Generic errors
error("Something went wrong")

# ❌ Missing context
throw(IncorrectArgument("Invalid value"))

# ❌ No suggestions
throw(IncorrectArgument("Unknown constraint type", got=":boundary"))
```

## Related Skills

- `testing-creation` skill — exception testing patterns
- `docstrings` skill — document exceptions in `# Throws` section
- `architecture` skill — error handling architecture
