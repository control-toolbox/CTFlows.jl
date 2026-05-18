# Common Anti-Patterns and Quality Checklist

## Quality Checklist

Before finalizing code, verify:

- [ ] Each function has a single, clear responsibility
- [ ] Abstract types define clear interfaces
- [ ] Subtypes honor parent contracts (LSP)
- [ ] No hard-coded type checks (`isa`, `typeof`)
- [ ] Dependencies are on abstractions, not concrete types
- [ ] No code duplication (DRY)
- [ ] Solution is as simple as possible (KISS)
- [ ] No premature features (YAGNI)
- [ ] Multiple dispatch used appropriately
- [ ] Type hierarchies reflect conceptual relationships
- [ ] Module organization follows layered architecture

---

## God Object

**❌ Avoid:** One object that does everything

```julia
struct System
    data::Dict
    config::Dict
    state::Dict
    # 50+ fields
end

# 100+ methods operating on System
```

**✅ Instead:** Split into focused components

```julia
struct DataManager
    data::Dict
end

struct ConfigManager
    config::Dict
end

struct StateManager
    state::Dict
end
```

---

## Primitive Obsession

**❌ Avoid:** Using primitives instead of domain types

```julia
function create_problem(n::Int, m::Int, t0::Float64, tf::Float64)
    # What do these numbers mean?
end
```

**✅ Instead:** Use domain types

```julia
struct Dimensions
    state::Int
    control::Int
end

struct TimeInterval
    initial::Float64
    final::Float64
end

function create_problem(dims::Dimensions, time::TimeInterval)
    # Clear meaning
end
```

---

## Feature Envy

**❌ Avoid:** Methods that use more of another type's data

```julia
function compute_cost(model::Model, data::Data)
    # Uses mostly data fields, not model fields
    return data.a * data.b + data.c
end
```

**✅ Instead:** Move method to appropriate type

```julia
function compute_cost(data::Data)
    return data.a * data.b + data.c
end
```

---

## References

- [Julia Style Guide](https://docs.julialang.org/en/v1/manual/style-guide/)
- [SOLID Principles](https://en.wikipedia.org/wiki/SOLID)
- [Design Patterns in Julia](https://github.com/JuliaLang/julia/blob/master/CONTRIBUTING.md)
