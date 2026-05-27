---
trigger: glob
glob: "src/**/*.jl, ext/**/*.jl"
---

# Julia Documentation Standards

## 🤖 **Agent Directive**

**When applying this rule, explicitly state**: "📚 **Applying Documentation Rule**: [specific documentation principle being applied]"

This ensures transparency about which documentation standard is being used and why.

---

This document defines the documentation standards for the Control Toolbox project. All Julia code (functions, structs, macros, modules) must be documented following these guidelines.

## Core Principles

1. **Completeness**: Every exported symbol and significant internal component must have a docstring
2. **Accuracy**: Documentation must reflect actual behavior, not aspirational or outdated information
3. **Clarity**: Write for users who understand Julia but may be unfamiliar with the specific domain
4. **Consistency**: Follow the templates and conventions defined here

## Docstring Placement

- Docstrings go **immediately above** the declaration they document
- No blank lines between docstring and declaration
- For multi-method functions, document the most general signature or provide method-specific docstrings

## Required Docstring Structure

Every docstring should contain:

1. **Signature line** (for functions): Use `$(TYPEDSIGNATURES)` from DocStringExtensions
2. **One-sentence summary**: Clear, concise description of purpose
3. **Detailed description** (if needed): Explain behavior, constraints, invariants, edge cases
4. **Structured sections** (as applicable):
   - `# Arguments`: For functions/macros
   - `# Fields`: For structs/types
   - `# Returns`: For functions that return values
   - `# Throws`: For functions that may throw exceptions
   - `# Example` or `# Examples`: Demonstrate usage
   - `# Notes`: Performance considerations, stability warnings, implementation details
   - `# References`: Citations to papers, algorithms, or external documentation
   - `See also:`: Related functions/types with `[@ref]` links

## Cross-References

### Internal References

For symbols within the current package or its dependencies, use `[@ref]` syntax with **full module path** including the root package and submodules:

```julia
See also: [`CTFlows.Flows.build_flow`](@ref), [`CTFlows.Flows.AbstractFlow`](@ref)
```

**Rules for @ref:**

1. Use full module path including root package (e.g., `CTFlows.Integrators.SciMLTag`, not just `SciMLTag`)
2. Include all nested submodules in the path
3. Only use for symbols documented in the current package's documentation

**Examples:**

✅ **Correct internal references:**

- [`CTFlows.Integrators.SciMLTag`](@ref)
- [`CTFlows.Flows.AbstractFlow`](@ref)
- [`CTFlows.Common.AbstractTag`](@ref)

❌ **Incorrect internal references:**

- [`SciMLTag`](@ref)  # Missing module qualification
- [`Integrators.SciMLTag`](@ref)  # Missing root package name

### External Package References

For symbols in external packages that are not part of the current documentation build, use `[@extref]` syntax with the **full module path** including submodules:

```julia
See also: [`CTSolvers.Options.OptionValue`](@extref)
```

**Rules for @extref:**

1. Use the complete module path (e.g., `CTSolvers.Options.OptionValue`, not just `OptionValue`)
2. Include all submodules in the path
3. Only use for symbols that are not documented in the current package's documentation
4. Use when the symbol is from a dependency that has its own separate documentation

**Examples:**

✅ **Correct external references:**

- [`CTBase.Exceptions.IncorrectArgument`](@extref)
- [`CTSolvers.Options.OptionValue`](@extref)
- [`CTBase.Tags.Autonomous`](@extref)

❌ **Incorrect external references:**

- [`OptionValue`](@extref)  # Missing module path
- [`CTSolvers.OptionValue`](@ref)  # Wrong syntax for external symbol

**When to use which:**

- Use `[@ref]` for symbols within CTFlows or its included documentation
- Use `[@extref]` for symbols from external packages with separate documentation (CTBase, CTSolvers)

## CTFlows Submodule Qualification

Public symbols are always accessed through their submodule, never through the root package:

```julia
CTFlows.Flows.build_flow(...)    # ✅ correct
CTFlows.build_flow(...)          # ❌ wrong — nothing exported at root level
```

### Exposed Submodules

| Submodule | Exported symbols (examples) |
| --- | --- |
| `CTFlows.Common` | `AbstractTag`, `AbstractTrait`, `Autonomous`, `Fixed` |
| `CTFlows.Data` | `VectorField`, `HamiltonianVectorField` |
| `CTFlows.Flows` | `AbstractFlow`, `Flow`, `MultiPhaseFlow` |
| `CTFlows.Integrators` | `AbstractIntegrator`, `AbstractIntegrationResult` |

## Docstring Templates

### Function Template

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
julia> using CTFlows.Flows

julia> result = function_name(arg1, arg2)
expected_output
\`\`\`

# Notes
- Performance characteristics (if relevant)
- Thread safety (if relevant)
- Stability guarantees

See also: [`CTFlows.Flows.related_function`](@ref), [`CTFlows.Flows.RelatedType`](@ref)
"""
function function_name(arg1::Type1, arg2::Type2)::ReturnType
    # implementation
end
```

---

### Struct Template

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
julia> using CTFlows.Flows

julia> obj = StructName(value1, value2)
StructName(...)

julia> obj.field1
value1
\`\`\`

# Notes
- Mutability status (if not obvious from declaration)
- Performance considerations

See also: [`CTFlows.Flows.related_type`](@ref), [`CTFlows.Flows.constructor_function`](@ref)
"""
struct StructName{T}
    field1::Type1
    field2::Type2
end
```

---

### Abstract Type Template

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
julia> using CTFlows.Common

julia> MyType <: AbstractTypeName
true
\`\`\`

See also: [`CTFlows.Common.ConcreteSubtype1`](@ref), [`CTFlows.Common.ConcreteSubtype2`](@ref)
"""
abstract type AbstractTypeName end
```

---

## Example Safety Policy

Examples in docstrings must be **safe and reproducible**:

### ✅ Safe Examples

- Pure computations with deterministic results
- Constructors with simple, valid inputs
- Queries on created objects
- Examples that start with `using CTFlows.Submodule`

### ❌ Unsafe Examples

- File system operations (reading/writing files)
- Network requests
- Database operations
- Git operations
- Non-deterministic behavior (random numbers without seed, timing-dependent code)
- Long-running computations (>1 second)
- Dependencies on external state or global variables

### Fallback for Complex Cases

If a safe, runnable example cannot be provided:

- Use a plain code block (\`\`\`julia) instead of REPL block (\`\`\`julia-repl)
- Show usage patterns without claiming specific output
- Provide a conceptual sketch of how to use the API

Example:

```julia
# Example
\`\`\`julia
# Conceptual usage pattern
flow = CTFlows.Flows.build_flow(sys, integrator)
result = CTFlows.Flows.evaluate(flow, t0, tf)
\`\`\`
```

## Module Prefix Convention

- **Exported symbols**: Use directly without module prefix

  ```julia-repl
  julia> using CTFlows.Flows
  julia> flow = build_flow(sys, integrator)  # build_flow is exported
  ```

- **Internal symbols**: Use module prefix

  ```julia-repl
  julia> using CTFlows.Flows
  julia> Flows.internal_function(...)  # Not exported
  ```

When a docstring is defined inside `src/Flows/flow.jl`, the public prefix shown in the docs is `CTFlows.Flows.`:

```julia
"""
$(TYPEDSIGNATURES)

Build a flow from a system and an integrator.

See also: [`CTFlows.Flows.AbstractFlow`](@ref), [`CTFlows.Integrators.AbstractIntegrator`](@ref)
"""
function build_flow(sys::AbstractSystem, integrator::AbstractIntegrator)
```

## DocStringExtensions Macros

This project uses [DocStringExtensions.jl](https://github.com/JuliaDocs/DocStringExtensions.jl):

- `$(TYPEDEF)`: Auto-generates type signature for structs/abstract types
- `$(TYPEDSIGNATURES)`: Auto-generates function signature with types
- Use these instead of manually writing signatures

## Quality Checklist

Before finalizing a docstring, verify:

- [ ] Docstring is directly above the declaration (no blank lines)
- [ ] Uses `$(TYPEDEF)` or `$(TYPEDSIGNATURES)` where applicable
- [ ] One-sentence summary is clear and accurate
- [ ] All arguments/fields are documented with types and descriptions
- [ ] Return value is documented (if applicable)
- [ ] Exceptions are documented (if thrown)
- [ ] Example is safe, runnable, and demonstrates typical usage
- [ ] Cross-references use `[@ref]` for internal symbols
- [ ] Cross-references use `[@extref]` for external symbols
- [ ] Full module paths are used (e.g., `CTFlows.Flows.build_flow`)
- [ ] No invented behavior or aspirational features
- [ ] Consistent with project style and terminology

## Related Rules

- `.windsurf/rules/architecture.md` - Architecture and design principles
- `.windsurf/rules/testing.md` - Testing standards
- `.windsurf/rules/type-stability.md` - Type stability standards
