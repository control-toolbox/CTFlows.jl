---
trigger: model_decision
---

# Julia Performance and Type Stability Standards

## 🤖 **Agent Directive**

**When applying this rule, explicitly state**: "⚡ **Applying Performance Rule**: [specific performance principle being applied]"

This ensures transparency about which performance standard is being used and why.

---

This document defines performance and type stability standards for the Control Toolbox project. Performance-critical code must follow these guidelines to ensure optimal execution speed and memory efficiency.

## Core Principles

1. **Measure First**: Profile before optimizing
2. **Focus on Hot Paths**: Optimize where it matters (inner loops, critical functions)
3. **Type Stability**: Ensure type-stable code (see `type-stability` rule)
4. **Avoid Premature Optimization**: Optimize only when necessary
5. **Maintain Readability**: Don't sacrifice clarity for marginal gains

## Performance Hierarchy

### Critical (Must Optimize)

- Inner loops (called millions of times)
- Numerical computations in solvers
- Hot paths identified by profiling
- Real-time systems

### Important (Should Optimize)

- Frequently called functions
- Data processing pipelines
- API functions with performance requirements

### Low Priority (Optimize if Easy)

- One-time setup code
- User-facing convenience functions
- Error handling paths
- Debugging utilities

## Profiling

### Using Profile.jl

```julia
using Profile

@profile my_function(args...)
Profile.print()
Profile.clear()
@profile (for i in 1:1000; my_function(args...); end)
```

### Using ProfileView.jl

```julia
using ProfileView

@profview my_function(args...)
@profview for i in 1:1000
    my_function(args...)
end
```

**Interpreting Results:**
- **Red bars**: Hot spots (most time spent)
- **Wide bars**: Functions called many times
- **Type instabilities**: Yellow/red warnings

## Benchmarking

### Using BenchmarkTools.jl

```julia
using BenchmarkTools

@benchmark my_function($args...)

b1 = @benchmark old_implementation($args...)
b2 = @benchmark new_implementation($args...)
judge(median(b2), median(b1))
```

**Best Practices:**

```julia
# ✅ Interpolate variables (avoids global variable penalty)
x = rand(1000)
@benchmark my_function($x)

# ✅ Warm up before benchmarking
my_function(args...)
@benchmark my_function($args...)
```

## Memory Allocations

### Reducing Allocations

**✅ Good - Preallocate buffers:**

```julia
function process_data!(output, input)
    for i in eachindex(input)
        output[i] = input[i]^2
    end
    return output
end

output = similar(input)
process_data!(output, input)  # No allocations
```

**❌ Bad - Allocate in loop:**

```julia
function process_data(input)
    output = []
    for x in input
        push!(output, x^2)  # Allocates each iteration
    end
    return output
end
```

**✅ Good - Use views instead of copies:**

```julia
sub = @view matrix[1:10, :]  # No allocation
```

**✅ Good - In-place operations:**

```julia
A .= B .+ C  # In-place, no allocation
```

## Common Optimizations

### 1. Avoid Global Variables

```julia
# ❌ Bad
global_counter = 0

# ✅ Good
const COUNTER = Ref(0)
function increment()
    COUNTER[] += 1
end
```

### 2. Use @inbounds for Bounds-Checked Loops

```julia
function sum_array(arr)
    s = zero(eltype(arr))
    @inbounds for i in eachindex(arr)
        s += arr[i]
    end
    return s
end
```

**⚠️ Warning:** `@inbounds` disables bounds checking. Use only when safe.

### 3. Use @simd for Vectorization

```julia
function sum_array(arr)
    s = zero(eltype(arr))
    @simd for i in eachindex(arr)
        s += arr[i]
    end
    return s
end
```

### 4. Use StaticArrays for Small Arrays

```julia
using StaticArrays

v = SVector(1.0, 2.0, 3.0)
m = SMatrix{3,3}(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)
result = m * v  # No allocation!
```

### 5. Avoid Untyped Containers

```julia
# ❌ Bad
results = []  # Vector{Any}

# ✅ Good
results = Float64[]
```

### 6. Use Multiple Dispatch Effectively

```julia
function process(x)         # Generic fallback
end

function process(x::Float64)  # Fast specialized method
end
```

## Performance Testing

### Allocation Tests

```julia
@testset "Allocations" begin
    x = rand(1000)
    allocs = @allocated process!(x)
    @test allocs == 0

    allocs = @allocated build_model(x)
    @test allocs < 1000  # bytes
end
```

### Benchmark Tests

```julia
@testset "Performance" begin
    x = rand(1000)
    b = @benchmark process($x)
    @test median(b.times) < 1_000_000  # < 1ms
    @test b.allocs == 0
end
```

## Optimization Workflow

1. **Profile** — `@profview my_application()`
2. **Measure baseline** — `baseline = @benchmark critical_function($args...)`
3. **Optimize** — fix type instabilities, reduce allocations, use specialized algorithms
4. **Measure improvement** — compare `median(baseline.times)` vs `median(optimized.times)`
5. **Verify correctness** — `@test optimized_function(args...) ≈ baseline_function(args...)`

## When NOT to Optimize

**❌ Don't optimize:**
- Before profiling
- Code that runs once
- Code that's already fast enough
- At the expense of readability

## Parallelization

### Using Threads

```julia
using Base.Threads

function parallel_sum(arr)
    sums = zeros(nthreads())
    @threads for i in eachindex(arr)
        sums[threadid()] += arr[i]
    end
    return sum(sums)
end
```

**Good candidates for parallelization:** independent computations, large data sets, CPU-bound tasks.

## Quality Checklist

Before finalizing performance optimizations:

- [ ] Profiled to identify bottlenecks
- [ ] Benchmarked baseline performance
- [ ] Optimized critical paths only
- [ ] Verified type stability with `@inferred`
- [ ] Tested allocations are acceptable
- [ ] Verified correctness after optimization
- [ ] Maintained code readability
- [ ] Measured actual improvement

## Tools Reference

| Tool | Purpose |
|---|---|
| `Profile.jl` | Built-in profiling |
| `ProfileView.jl` | Visual profiling |
| `BenchmarkTools.jl` | Precise benchmarking |
| `@time` | Quick timing |
| `@allocated` | Allocation tracking |
| `@code_warntype` | Type stability |
| `StaticArrays.jl` | Fast small arrays |

## Related Skills

- `type-stability` rule — type stability standards (critical for performance)
- `testing-creation` rule — performance testing patterns
- `architecture` rule — architecture patterns that affect performance
