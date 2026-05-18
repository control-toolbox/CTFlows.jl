---
name: type-stability
description: Julia type stability standards for CTFlows: what type stability means, testing with @inferred and @code_warntype, parametric types vs abstract fields, NamedTuple vs Dict, avoiding Any in hot paths, conditional return types, global variables, function barriers, fixing type instabilities. Invoke when introducing new structs, parametric types, or performance-critical functions.
---

# Julia Type Stability Standards

## 🤖 **Agent Directive**

**When applying this skill, explicitly state**: "🔧 **Applying Type Stability Rule**: [specific type stability principle being applied]"

This ensures transparency about which type stability standard is being used and why.

---

This document defines type stability standards for the Control Toolbox project. Type stability is crucial for Julia performance and must be carefully considered in performance-critical code paths.

## Core Principles

1. **Type Inference**: The compiler must be able to determine return types from input types
2. **Performance**: Type-stable code is typically 10-100x faster than type-unstable code
3. **Testability**: Type stability must be verified with `@inferred` tests
4. **Clarity**: Type-stable code is often clearer and more maintainable

## What is Type Stability?

A function is **type-stable** if the type of its return value can be inferred from the types of its inputs at compile time.

```julia
# ✅ Type-stable: return type is always Int
function get_dimension(ocp::OptimalControlProblem)::Int
    return ocp.state_dimension
end

# ❌ Type-unstable: return type depends on runtime value
function get_value(dict::Dict{Symbol, Any}, key::Symbol)
    return dict[key]  # Could be Int, Float64, String, anything!
end
```

## Testing Type Stability

### Using `@inferred`

```julia
@testset "Type Stability" begin
    ocp = create_test_ocp()

    @test_nowarn @inferred get_dimension(ocp)
    @test_nowarn @inferred state_dimension(ocp)
    @test_nowarn @inferred process_constraint(ocp, :initial)
end
```

### Common Mistake: Testing Non-Functions

```julia
# ❌ WRONG: @inferred on field access
@inferred ocp.state_dimension  # ERROR: Not a function call!

# ✅ CORRECT: Wrap in a function
function get_state_dim(ocp)
    return ocp.state_dimension
end
@inferred get_state_dim(ocp)
```

### Using `@code_warntype`

```julia
julia> @code_warntype get_value(dict, :key)
# Look for red "Any" or yellow warnings in the output
```

**What to look for:**
- Red `Any` or `Union{...}` in return type
- Yellow warnings about type instabilities
- Multiple possible return types

## Type-Stable Structures

### Use Parametric Types

**❌ Type-Unstable:**

```julia
struct OptionDefinition
    name::Symbol
    type::Type
    default::Any  # Type-unstable!
end
```

**✅ Type-Stable:**

```julia
struct OptionDefinition{T}
    name::Symbol
    type::Type{T}
    default::T  # Type-stable!
end

function get_default(opt::OptionDefinition{T}) where T
    return opt.default  # Return type: T
end
```

### Use NamedTuple Instead of Dict

**❌ Type-Unstable:**

```julia
struct StrategyMetadata
    specs::Dict{Symbol, OptionDefinition}  # Values have unknown types
end
```

**✅ Type-Stable:**

```julia
struct StrategyMetadata{NT <: NamedTuple}
    specs::NT  # Type-stable with known keys
end
```

### Avoid Abstract Types in Structs

**❌ Type-Unstable:**

```julia
struct Container
    items::Vector{Number}  # Abstract type!
end
```

**✅ Type-Stable:**

```julia
struct Container{T <: Number}
    items::Vector{T}  # Concrete type parameter
end
```

## Common Type Instabilities

### 1. Untyped Containers

```julia
# ❌ Type-unstable
results = []  # Vector{Any}

# ✅ Type-stable
results = Int[]
```

### 2. Conditional Return Types

```julia
# ❌ Type-unstable: Union{Int, Nothing}
function get_value(x::Int)
    if x > 0
        return x
    else
        return nothing
    end
end

# ✅ Type-stable
function get_value(x::Int)::Int
    return x > 0 ? x : 0
end
```

### 3. Global Variables

```julia
# ❌ Type-unstable
global_counter = 0

# ✅ Type-stable
const GLOBAL_COUNTER = Ref(0)
```

### 4. Type-Unstable Fields

```julia
# ❌ Type-unstable
mutable struct Cache
    data::Any
end

# ✅ Type-stable
mutable struct Cache{T}
    data::T
end
```

## Fixing Type Instabilities

### Strategy 1: Add Type Annotations

```julia
function process(x::Vector{Float64})
    result = Float64[]
    # ...
end
```

### Strategy 2: Use Function Barriers

```julia
# Type-unstable outer function
function outer(data::Dict{Symbol, Any})
    value = data[:key]  # Type-unstable
    return inner(value)  # Function barrier isolates instability
end

# Type-stable inner function
function inner(value::Int)
    return value^2
end
```

### Strategy 3: Parametric Types

```julia
# Before
struct Container
    data::Vector{Any}
end

# After
struct Container{T}
    data::Vector{T}
end
```

## When Type Stability Matters

### Critical Paths (must be type-stable)

- Inner loops (called millions of times)
- Hot paths in solvers
- Numerical computations
- Real-time systems

### Less Critical Paths

- One-time setup code
- User-facing API layers
- Error handling paths
- Debugging utilities

## Performance Testing

```julia
@testset "Allocations" begin
    ocp = create_test_ocp()

    allocs = @allocated state_dimension(ocp)
    @test allocs == 0

    allocs = @allocated build_model(ocp)
    @test allocs < 1000  # bytes
end
```

## Quality Checklist

Before finalizing code, verify:

- [ ] Critical functions tested with `@inferred`
- [ ] No `Any` types in hot paths
- [ ] Parametric types used where appropriate
- [ ] `@code_warntype` shows no red flags
- [ ] Allocation tests pass for critical operations
- [ ] Benchmarks meet performance targets

## Key Takeaways

1. Type stability is crucial for Julia performance
2. Test with `@inferred` for all critical functions
3. Use parametric types and NamedTuple for type-stable structures
4. Avoid `Any` and abstract types in hot paths
5. Use `@code_warntype` to debug instabilities
6. Test allocations for performance-critical code

## Related Skills

- `performance` skill — profiling, benchmarking, allocation reduction
- `testing-creation` skill — type stability test patterns
- `architecture` skill — parametric type design
