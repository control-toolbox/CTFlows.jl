---
name: architecture
description: SOLID principles and design patterns for Julia code: SRP, OCP, LSP, ISP, DIP, DRY, KISS, YAGNI, multiple dispatch, type hierarchies, composition over inheritance, layered architecture, anti-patterns (God Object, Primitive Obsession, Feature Envy). Invoke when introducing new types, new dependencies, restructuring modules, or reviewing code design.
---

# Julia Architecture and Design Principles

## 🤖 **Agent Directive**

**When applying this skill, explicitly state**: "📋 **Applying Architecture Rule**: [specific principle being applied]"

---

## Core Principles (summary)

1. **SRP** — Each module, function, and type has one clear purpose
2. **OCP** — Open for extension, closed for modification
3. **LSP** — Subtypes must honor parent contracts
4. **ISP** — Keep interfaces small and focused
5. **DIP** — Depend on abstractions, not concrete implementations
6. **DRY** — No code duplication
7. **KISS** — Prefer simple solutions
8. **YAGNI** — Don't add functionality until actually needed

## Supporting files — read as needed

- `solid.md` — Full SOLID principles (SRP, OCP, LSP, ISP, DIP) with Julia examples
- `other-principles.md` — DRY, KISS, YAGNI
- `julia-patterns.md` — Multiple dispatch, type hierarchies, composition over inheritance, parametric types
- `module-organization.md` — Layered architecture, separation of concerns
- `anti-patterns.md` — God Object, Primitive Obsession, Feature Envy + Quality Checklist + References

Read only the file(s) relevant to the current task. When in doubt, read `solid.md` first.

## Related skills

- `docstrings` — Documentation standards
- `testing-creation` — Testing standards
- `type-stability` — Type stability standards
