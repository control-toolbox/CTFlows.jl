# Other Design Principles

## DRY - Don't Repeat Yourself

Avoid code duplication. Every piece of knowledge should have a single representation.

**✅ Good - Extract common logic:**

```julia
function validate_positive(x, name)
    x > 0 || throw(IncorrectArgument("$name must be positive"))
end

function create_model(n::Int, m::Int)
    validate_positive(n, "n")
    validate_positive(m, "m")
    return Model(n, m)
end
```

**❌ Bad - Duplicated validation:**

```julia
function create_model(n::Int, m::Int)
    n > 0 || throw(ArgumentError("n must be positive"))
    m > 0 || throw(ArgumentError("m must be positive"))
    return Model(n, m)
end

function create_problem(n::Int, m::Int)
    n > 0 || throw(ArgumentError("n must be positive"))  # Duplicated!
    m > 0 || throw(ArgumentError("m must be positive"))  # Duplicated!
    return Problem(n, m)
end
```

---

## KISS - Keep It Simple, Stupid

Prefer simple solutions over complex ones. Avoid over-engineering.

**✅ Good - Simple and clear:**

```julia
function compute_mean(xs)
    return sum(xs) / length(xs)
end
```

**❌ Bad - Over-engineered:**

```julia
function compute_mean(xs)
    accumulator = zero(eltype(xs))
    counter = 0
    for x in xs
        accumulator = accumulator + x
        counter = counter + 1
    end
    return accumulator / counter
end
```

---

## YAGNI - You Aren't Gonna Need It

Don't add functionality until it's actually needed.

**✅ Good - Implement what's needed:**

```julia
struct Model
    coeffs::Vector{Float64}
end

function evaluate(m::Model, x)
    return dot(m.coeffs, x)
end
```

**❌ Bad - Premature features:**

```julia
struct Model
    coeffs::Vector{Float64}
    cache::Dict{Vector, Float64}        # Not needed yet
    optimization_history::Vector        # Not needed yet
    metadata::Dict{Symbol, Any}         # Not needed yet
    version::String                     # Not needed yet
end
```
