# Julia-Specific Patterns

## Multiple Dispatch

Use multiple dispatch for extensibility and clarity:

```julia
# Define behavior for different type combinations
function combine(a::Number, b::Number)
    return a + b
end

function combine(a::Vector, b::Vector)
    return vcat(a, b)
end

function combine(a::String, b::String)
    return a * b
end

# Extensible: add new methods without modifying existing code
```

---

## Type Hierarchies

Design type hierarchies that reflect conceptual relationships:

```julia
# Clear hierarchy
abstract type AbstractStrategy end
abstract type AbstractDirectMethod <: AbstractStrategy end
abstract type AbstractIndirectMethod <: AbstractStrategy end

struct DirectShooting <: AbstractDirectMethod end
struct DirectCollocation <: AbstractDirectMethod end
struct IndirectShooting <: AbstractIndirectMethod end
```

---

## Composition Over Inheritance

Prefer composition (has-a) over inheritance (is-a) when appropriate:

```julia
# Composition: Model has a solver
struct OptimizationModel
    problem::AbstractProblem
    solver::AbstractSolver
    options::NamedTuple
end

# Not: OptimizationModel <: AbstractSolver
```

---

## Parametric Types

Use parametric types for type stability and flexibility:

```julia
# Type-stable with parameters
struct Container{T}
    items::Vector{T}
end

# Flexible: works with any type
c1 = Container([1, 2, 3])        # Container{Int}
c2 = Container([1.0, 2.0, 3.0])  # Container{Float64}
```
