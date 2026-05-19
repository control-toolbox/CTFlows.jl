# Docstring Templates

## Function Template

```julia
"""
$(TYPEDSIGNATURES)

One-sentence description of what the function does.

Optional detailed explanation covering:
- Behavior and semantics
- Constraints and preconditions
- Common use cases or patterns

# Arguments
- `arg1::Type1`: Description of first argument
- `arg2::Type2`: Description of second argument

# Returns
- `ReturnType`: Description of return value

# Throws
- `ExceptionType`: When and why this exception is thrown

# Example
\`\`\`julia-repl
julia> using CTModels.ModuleName

julia> result = function_name(arg1, arg2)
expected_output
\`\`\`

# Notes
- Performance characteristics (if relevant)
- Thread safety (if relevant)
- Stability guarantees

See also: [`PackageName.ModuleName.related_function`](@ref), [`PackageName.ModuleName.RelatedType`](@ref)
"""
function function_name(arg1::Type1, arg2::Type2)::ReturnType
    # implementation
end
```

---

## Struct Template

```julia
"""
$(TYPEDEF)

One-sentence description of what this type represents.

Optional detailed explanation covering:
- Purpose and design intent
- Invariants that must be maintained
- Relationship to other types

# Fields
- `field1::Type1`: Description and constraints
- `field2::Type2`: Description and constraints

# Constructor Validation

Describe any validation performed by constructors (if applicable).

# Example
\`\`\`julia-repl
julia> using CTModels.ModuleName

julia> obj = StructName(value1, value2)
StructName(...)

julia> obj.field1
value1
\`\`\`

# Notes
- Mutability status (if not obvious from declaration)
- Performance considerations

See also: [`ModuleName.related_type`](@ref), [`ModuleName.constructor_function`](@ref)
"""
struct StructName{T}
    field1::Type1
    field2::Type2
end
```

---

## Abstract Type Template

```julia
"""
$(TYPEDEF)

One-sentence description of the abstraction.

Detailed explanation of:
- What types should subtype this
- Contract/interface requirements for subtypes
- Common behavior across all subtypes

# Interface Requirements

List methods that subtypes must implement:
- `required_method(::SubType)`: Description

# Example
\`\`\`julia-repl
julia> using CTModels.ModuleName

julia> MyType <: AbstractTypeName
true
\`\`\`

See also: [`ModuleName.ConcreteSubtype1`](@ref), [`ModuleName.ConcreteSubtype2`](@ref)
"""
abstract type AbstractTypeName end
```
