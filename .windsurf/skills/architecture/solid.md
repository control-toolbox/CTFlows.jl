# SOLID Principles in Julia

## Single Responsibility Principle (SRP)

Every module, function, and type should have a single, well-defined responsibility.

**✅ Good - Focused responsibilities:**

```julia
# Parsing responsibility
function parse_ocp_input(text::String)
    return parsed_data
end

# Validation responsibility
function validate_ocp_data(data)
    return is_valid, errors
end

# Processing responsibility
function solve_ocp(data)
    return solution
end
```

**❌ Bad - Too many responsibilities:**

```julia
function handle_ocp(text::String)
    parsed = parse(text)           # Parsing
    validate(parsed)               # Validation
    solution = solve(parsed)       # Processing
    save_to_file(solution, "out")  # I/O
    return format_output(solution) # Formatting
end
```

**Red flags:**

- Function names with "and" or "or"
- Functions longer than 50 lines
- Multiple `if-else` branches handling different concerns
- Modules mixing unrelated functionality

---

## Open/Closed Principle (OCP)

Software should be open for extension but closed for modification.

**✅ Good - Extensible via abstract types:**

```julia
# Define abstract interface
abstract type AbstractOptimizationProblem end

# Existing implementation
struct LinearProblem <: AbstractOptimizationProblem
    A::Matrix
    b::Vector
end

# Solver works with any AbstractOptimizationProblem
function solve(problem::AbstractOptimizationProblem)
    # Generic solving logic
end

# NEW: Extend without modifying existing code
struct NonlinearProblem <: AbstractOptimizationProblem
    f::Function
    x0::Vector
end
# Solver automatically works via multiple dispatch
```

**❌ Bad - Hard-coded type checks:**

```julia
function solve(problem)
    if problem isa LinearProblem
        # Linear solving
    elseif problem isa NonlinearProblem
        # Nonlinear solving
    # Need to modify for every new type!
    end
end
```

**How to apply:**

- Use abstract types to define interfaces
- Leverage multiple dispatch for extensibility
- Avoid type checking with `isa` or `typeof`
- Design type hierarchies that allow new subtypes

---

## Liskov Substitution Principle (LSP)

Subtypes must be substitutable for their parent types without breaking functionality.

**✅ Good - Consistent interface:**

```julia
abstract type AbstractModel end

# Contract: all models must implement `evaluate`
function evaluate(model::AbstractModel, x)
    throw(NotImplemented("evaluate not implemented for $(typeof(model))"))
end

# Subtype honors contract
struct LinearModel <: AbstractModel
    coeffs::Vector
end

function evaluate(model::LinearModel, x)
    return dot(model.coeffs, x)  # Returns a number
end

# Generic code works with any AbstractModel
function optimize(model::AbstractModel, x0)
    value = evaluate(model, x0)  # Safe for any model
    # ...
end
```

**❌ Bad - Subtype breaks contract:**

```julia
struct BrokenModel <: AbstractModel
    data::String
end

function evaluate(model::BrokenModel, x)
    return "error: invalid"  # Returns String, not number!
end

# This breaks unexpectedly
function optimize(model::AbstractModel, x0)
    value = evaluate(model, x0)
    gradient = value * 2  # ERROR if value is String!
end
```

**How to apply:**

- Define clear contracts for abstract types (via docstrings)
- Ensure all subtypes implement required methods consistently
- Return types should be compatible across hierarchy
- Test that generic code works with all subtypes

**Testing LSP:**

```julia
@testset "Liskov Substitution" begin
    # Test that all subtypes work with generic code
    for ModelType in [LinearModel, QuadraticModel, CustomModel]
        model = ModelType(test_params...)
        @test evaluate(model, x) isa Number
        @test optimize(model, x0) isa Solution
    end
end
```

---

## Interface Segregation Principle (ISP)

Keep interfaces small and focused. Don't force clients to depend on methods they don't use.

**✅ Good - Small, focused interfaces:**

```julia
# Separate capabilities
abstract type Evaluable end
abstract type Differentiable end

# Types implement only what they need
struct SimpleFunction <: Evaluable
    f::Function
end

struct SmoothFunction <: Union{Evaluable, Differentiable}
    f::Function
    df::Function
end

# Clients depend only on what they need
function plot_function(f::Evaluable, xs)
    return [evaluate(f, x) for x in xs]
end

function optimize(f::Differentiable, x0)
    return gradient_descent(f, x0)
end
```

**❌ Bad - Bloated interface:**

```julia
# Forces all types to implement everything
abstract type MathFunction end

# Required methods (even if not needed):
evaluate(f::MathFunction, x) = error("not implemented")
gradient(f::MathFunction, x) = error("not implemented")
hessian(f::MathFunction, x) = error("not implemented")
integrate(f::MathFunction, a, b) = error("not implemented")

# Simple function forced to implement everything
struct SimpleFunction <: MathFunction
    f::Function
end

evaluate(sf::SimpleFunction, x) = sf.f(x)
gradient(sf::SimpleFunction, x) = error("not differentiable")  # Forced!
hessian(sf::SimpleFunction, x) = error("not differentiable")   # Forced!
integrate(sf::SimpleFunction, a, b) = error("not integrable")  # Forced!
```

**How to apply:**

- Create small, focused abstract types
- Use `Union` types for multiple interfaces
- Don't force implementations of unused methods
- Export only necessary functions

---

## Dependency Inversion Principle (DIP)

Depend on abstractions, not concrete implementations.

**✅ Good - Depend on abstractions:**

```julia
# High-level abstraction
abstract type DataStore end

# High-level module depends on abstraction
struct DataProcessor
    store::DataStore  # Abstract type
end

function process(dp::DataProcessor, data)
    save(dp.store, data)  # Works with any DataStore
end

# Low-level implementations
struct FileStore <: DataStore
    path::String
end

struct DatabaseStore <: DataStore
    connection::DBConnection
end

# Easy to swap implementations
processor1 = DataProcessor(FileStore("data.txt"))
processor2 = DataProcessor(DatabaseStore(conn))
```

**❌ Bad - Depend on concrete types:**

```julia
# Tightly coupled to file system
struct DataProcessor
    file_path::String
end

function process(dp::DataProcessor, data)
    write(dp.file_path, data)  # Hard-coded to files
end

# Can't switch to database without modifying DataProcessor
```

**How to apply:**

- Define abstract types for dependencies
- Pass abstract types as arguments
- Use dependency injection
- Avoid hard-coding concrete types
