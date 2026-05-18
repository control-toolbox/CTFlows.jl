# Module Organization

## Layered Architecture

Organize code in layers with clear dependencies:

```text
Low-level (Core types, utilities)
    ↓
Mid-level (Business logic, algorithms)
    ↓
High-level (User-facing API, orchestration)
```

**Example:**

```julia
# Low-level: Core types
module Types
    abstract type AbstractProblem end
    struct Problem <: AbstractProblem
        # ...
    end
end

# Mid-level: Algorithms
module Solvers
    using ..Types
    function solve(p::AbstractProblem)
        # ...
    end
end

# High-level: User API
module API
    using ..Types
    using ..Solvers
    export solve, Problem
end
```

---

## Separation of Concerns

Keep different concerns in separate modules:

```julia
# Validation logic
module Validation
    function validate_dimensions(n, m)
        # ...
    end
end

# Parsing logic
module Parsing
    function parse_input(text)
        # ...
    end
end

# Business logic
module Core
    using ..Validation
    using ..Parsing
    # ...
end
```
