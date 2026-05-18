---
name: docstrings
description: Julia docstring standards for CTFlows/Control Toolbox: TYPEDEF and TYPEDSIGNATURES macros from DocStringExtensions, required sections (Arguments, Fields, Returns, Throws, Example, Notes, References, See also), internal @ref vs external @extref cross-reference syntax, safe runnable examples policy, function/struct/abstract type templates. Invoke when writing or reviewing docstrings.
---

# Julia Documentation Standards

## 🤖 **Agent Directive**

**When applying this skill, explicitly state**: "📚 **Applying Documentation Rule**: [specific documentation principle being applied]"

This ensures transparency about which documentation standard is being used and why.

---

This document defines the documentation standards for the Control Toolbox project. All Julia code (functions, structs, macros, modules) must be documented following these guidelines.

> 📌 **Project-specific names** (package name, submodule qualification style, `@extref` packages): read `project.md`. Replace its content when adapting this skill to another package.

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
See also: [`PackageName.Submodule.related_function`](@ref), [`PackageName.Submodule.RelatedType`](@ref)
```

**Rules for @ref:**

1. Use full module path including root package (e.g., `CTFlows.Integrators.SciMLTag`, not just `SciMLTag`)
2. Include all nested submodules in the path
3. Only use for symbols documented in the current package's documentation

**Examples:**

✅ **Correct internal references:**

- [`CTFlows.Integrators.SciMLTag`](@ref)
- [`CTFlows.Options.OptionValue`](@ref)
- [`CTFlows.Systems.AbstractSystem`](@ref)

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

- [`CTSolvers.Options.OptionValue`](@extref)
- [`CTBase.Exceptions.IncorrectArgument`](@extref)
- [`CTModels.Init.build_initial_guess`](@extref)

❌ **Incorrect external references:**

- [`OptionValue`](@extref)  # Missing module path
- [`CTSolvers.OptionValue`](@ref)  # Wrong syntax for external symbol

**When to use which:**

- Use `[@ref]` for symbols within OptimalControl or its included documentation
- Use `[@extref]` for symbols from external packages with separate documentation

## Templates (→ read `templates.md`)

Copy-paste templates for functions, structs, and abstract types are in `templates.md`.

- **Function template** — `$(TYPEDSIGNATURES)`, Arguments, Returns, Throws, Example, Notes, See also
- **Struct template** — `$(TYPEDEF)`, Fields, Constructor Validation, Example, Notes, See also
- **Abstract type template** — `$(TYPEDEF)`, Interface Requirements, Example, See also

## Example Safety Policy

Examples in docstrings must be **safe and reproducible**:

### ✅ Safe Examples

- Pure computations with deterministic results
- Constructors with simple, valid inputs
- Queries on created objects
- Examples that start with `using CTModels.ModuleName`

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
ocp = Model(...)
constraint!(ocp, :state, 0.0, :initial)
sol = solve(ocp, strategy=MyStrategy())
\`\`\`
```

## Module Prefix Convention

- **Exported symbols**: Use directly without module prefix
  ```julia-repl
  julia> using CTModels.Options
  julia> opt = OptionValue(100, :user)  # OptionValue is exported
  ```

- **Internal symbols**: Use module prefix
  ```julia-repl
  julia> using CTModels.Options
  julia> Options.internal_function(...)  # Not exported
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
- [ ] Cross-references use `[@ref]` syntax for related items
- [ ] No invented behavior or aspirational features
- [ ] Consistent with project style and terminology
