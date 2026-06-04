# Development notes — CTFlows.jl

Design reflections, the coding philosophy, the agent rules, and the action plan for the
ongoing refactor.

## Contents

| Item | Scope | Purpose |
|---|---|---|
| [action_plan.md](action_plan.md) | CTFlows-specific | Ordered, phased plan for the traits / interfaces / dispatch / multiphase refactor |
| [RULES.md](RULES.md) | Generic | Tools & procedures for an agent: running tests (MCP), building docs (draft workflow), git, output capture |
| [philosophy/](philosophy/PHILOSOPHY.md) | Generic | Code philosophy (abstract, generic examples): modules, types/traits/interfaces, exceptions, docstrings, testing, documentation |
| [traits_vs_abstract_types.md](traits_vs_abstract_types.md) | CTFlows-specific | Overall reflection: fewer abstract types, clearer interfaces, trait dispatch; exception choice; `content`→`dynamics`; phased proposal |
| [multiphase_type_constraint.md](multiphase_type_constraint.md) | CTFlows-specific | The homogeneous-type constraint breaking multi-phase concatenation, and the compatibility model (tuple + trait-bound `Vararg`) that fixes it |

## Through-line

Both architectural reports converge on a single principle:

> **One abstract type per real *noun*; one trait-parameter per *orthogonal axis*;
> dispatch via a trait extractor.** The `Configs` module already embodies this model;
> the debt is localized to the **dynamics** axis (`StateDynamics`/`HamiltonianDynamics`/
> `AugmentedHamiltonianDynamics`, to be renamed from the current "content") mis-encoded
> as a hierarchy in `Flows`/`Systems`.

The multi-phase case is the sharpest illustration: once dynamics is treated as a
trait-parameter, the concatenation rule fits in one line at the type level.

## How these relate

- **[philosophy/](philosophy/PHILOSOPHY.md)** = the durable "how we design" (generic).
- **[RULES.md](RULES.md)** = the durable "how we operate the toolchain" (generic).
- **[action_plan.md](action_plan.md)** = the current "what to do next" (project-specific),
  grounded in the two architectural reports.
- This directory supersedes the older
  [`../abstract_interface/rapport.md`](../abstract_interface/rapport.md) (see the
  reconciliation table in [traits_vs_abstract_types.md](traits_vs_abstract_types.md)).
