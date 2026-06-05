# Action plan — traits / interfaces / dispatch / multiphase refactor

This document orders the upcoming work. It is **CTFlows-specific** (unlike
[`philosophy/`](philosophy/PHILOSOPHY.md) and [`RULES.md`](RULES.md), which are generic).

Grounded in:

- [`traits_vs_abstract_types.md`](traits_vs_abstract_types.md) — the overall vision;
- [`multiphase_type_constraint.md`](multiphase_type_constraint.md) — the multiphase case.

## Ordering principle

From least risky to most structural, each phase **independently testable** and shielded
by **aliases** that preserve the public names. Docstrings are *not* touched during
implementation — they are written last (see the `docstrings` workflow).

```text
A. Exceptions   →  B. dynamics rename  →  C. Systems param.  →  D. Flows param. + merge
                                                                      ↓
                       G. Data (abstract dispatch)  ←  F. MultiPhase  ←  E. Interfaces & dispatch
```

---

## Phase A — Exception cleanup (zero risk)

**Goal**: align exceptions with the rule "single argument value → `IncorrectArgument`;
relation/state/composition → `PreconditionError`" (see
[`philosophy/exceptions.md`](philosophy/exceptions.md)).

- Audit `src/`: find `IncorrectArgument` thrown on a **relational** condition (two
  arguments, ordering, state) → convert to `PreconditionError`.
- Check the fields used exist (`IncorrectArgument` has `got`/`expected`, **not**
  `reason`; `PreconditionError` has `reason`).
- **Checkpoint**: affected suites via the MCP test command, then the full suite.

Independent of everything else — can start first.

---

## Phase B — Rename `content` → `dynamics` (mechanical)

**Goal**: name the axis correctly before extending it to Flows/Systems.

| Current | Target |
|---|---|
| `AbstractContentTrait` | `AbstractDynamicsTrait` |
| `StateTrait` | `StateDynamics` |
| `HamiltonianTrait` | `HamiltonianDynamics` |
| `AugmentedHamiltonianTrait` | `AugmentedHamiltonianDynamics` |
| `content_trait(·)` | `dynamics_trait(·)` |

- Files: `src/Traits/content.jl` → `dynamics.jl` (+ include in `Traits.jl`, exports),
  `src/Configs/*` (parameter `Content` → `Dyn`, aliases), `src/Solutions/building.jl`
  (dispatch `::Type{StateDynamics}`…), `docs/api_reference.jl` (file path).
- Update tests `test/suite/traits/test_content.jl` → `test_dynamics.jl`.
- **Checkpoint**: `traits`, `configs`, `solutions` suites, then full.

---

## Phase C — Parametrize systems by dynamics

**Goal**: `AbstractSystem{TD, VD, D<:AbstractDynamicsTrait}` + aliases + extractor.

- `src/Systems/abstract_system.jl`:
  - `abstract type AbstractSystem{TD, VD, D<:Traits.AbstractDynamicsTrait} end`
  - `const AbstractStateSystem{TD,VD} = AbstractSystem{TD,VD,StateDynamics}`
  - `const AbstractHamiltonianSystem{TD,VD} = AbstractSystem{TD,VD,HamiltonianDynamics}`
    (fold the AD axis back into the `ad_trait` trait, **not** a dedicated 3rd parameter
    — see Phase E).
  - `dynamics_trait(::AbstractSystem{TD,VD,D}) = D`.
- Concrete types unchanged except the supertype clause (`<: AbstractStateSystem{TD,VD}`…).
- **Checkpoint**: `systems` suite, then full.

⚠️ The current `AbstractADTrait` is a parameter of `AbstractHamiltonianSystem`. Decide
in Phase C/E whether it becomes a plain extracted trait (`ad_trait`) rather than a
parameter.

---

## Phase D — Parametrize flows + merge the concrete types

**Goal**: `AbstractFlow{TD, VD, D}` + aliases, then a single `Flow`.

- `src/Flows/abstract_flow.jl`: parametrized family + aliases + `dynamics_trait`.
- `src/Flows/flow.jl`: merge `StateFlow`/`HamiltonianFlow` → `Flow{TD,VD,D,S,I}` +
  aliases `const StateFlow{...} = Flow{...,StateDynamics,...}`.
- `src/Flows/calling.jl`: call signatures dispatch on the aliases
  (`AbstractStateFlow`/`AbstractHamiltonianFlow`) — nearly unchanged.
- **Checkpoint**: `flows`, `extensions` suites, then full.

---

## Phase E — Interfaces & dispatch on abstract types

**Goal**: lift concrete methods up to abstract types, dispatch by trait (keeps the good
parts of [`../abstract_interface/rapport.md`](../abstract_interface/rapport.md)).

- `build_system(::AbstractVectorField)`, `(::AbstractHamiltonianVectorField)`,
  `(::AbstractHamiltonian, backend)` — accept abstract inputs.
- `hamiltonian_vector_field`, `build_rhs`, `build_oop_rhs`, `rhs` — define **once** on
  `AbstractHamiltonianSystem`/`AbstractStateSystem`, branch on `ad_trait(sys)`.
- `NotImplemented` stubs on the abstract types for contract methods.
- **Do not** add more abstract types (e.g. `AbstractSystemWithAD`) — AD is a trait
  (see the reflection).
- **Checkpoint**: `systems`, `differentiation`, `extensions` suites, then full.

---

## Phase F — MultiPhase refactor (tuple + dynamics constraint)

**Goal**: lift the homogeneous-type constraint (see
[`multiphase_type_constraint.md`](multiphase_type_constraint.md)).

- Field `flows::Tuple{Vararg{AbstractFlow{TD,VD,D}}}` instead of a `Vector` with fixed
  `S`/`I`.
- `*` builds a tuple (`(get_flows(f1)..., get_flows(f2)...)`).
- Explicit `*` methods for the state × Hamiltonian error (`PreconditionError`).
- `_handoff`: runtime dimensional check (`PreconditionError`).
- **Checkpoint**: `multiphase` suite, then full.

---

## Phase G — Data: abstract dispatch

**Goal**: finalize abstract usage on the data side (Systems consumes abstract Data types).

- Ensure `Systems` consumes `AbstractVectorField`/`AbstractHamiltonian` rather than the
  concrete types where appropriate (follow-on from Phase E).
- Confirm the typed constructors (`VectorField(f, TD, VD, MD)` etc.) are in place.
- **Checkpoint**: `data`, `systems` suites, then full.

> **Scope boundary — `Data` and `Solutions` are NOT parametrized by `D`.**
>
> The dynamics axis stops at `Flows`/`Systems`. The decisive test: fix TD/VD/MD — does
> the dynamics value range over instances of the *same* concrete struct?
>
> | Layer | Same layout, varies by `D`? | Encoding |
> |---|---|---|
> | `Flow` | **Yes** — `StateFlow`/`HamiltonianFlow` have identical fields | `D` parameter + merge |
> | `AbstractSystem` | **Yes** (abstract level) | `D` parameter + aliases |
> | `Data` | **No** — `VectorField` (has `MD`, returns `ẋ`), `Hamiltonian` (scalar, no `MD`), `HamiltonianVectorField` (returns `(ẋ,ṗ)`) have different fields/arities/contracts | distinct nouns, unchanged |
> | `Solutions` | **No** — `VectorFieldSolution{R}` vs `HamiltonianVectorFieldSolution{X0,R}` have different fields and interface | distinct nouns, unchanged |
>
> These layers participate in the dynamics axis through their *boundaries*:
> - **In**: `Configs` carries `D` as a parameter — the sole producer of the dynamics
>   value for the integration pipeline.
> - **Out**: `build_solution(::Type{Mode}, ::Type{Dynamics}, config, result)` in
>   `Solutions/building.jl` already dispatches correctly; Phase B only renames values
>   (`StateTrait`→`StateDynamics`, …), the structure is correct as is.
>
> An optional constant extractor `Traits.dynamics_trait(::AbstractVectorField) =
> StateDynamics` can be added (one line, no struct change) if a future consumer needs it,
> but is not required by any current phase.
>
> **Extensions (SciML)**: `SciMLFunctionSystem <: AbstractStateSystem{…}` and
> `SciMLProblemFlow <: AbstractStateFlow{…}` compile verbatim once those become aliases.
> No edits needed in the extension — proof that the scope is correctly bounded.
> See [traits_vs_abstract_types.md](traits_vs_abstract_types.md) §3 for the full
> argument.

---

## Cross-cutting — Tests & documentation

At every phase:
- Tests first (contract/error), run via the **MCP** (see [`RULES.md`](RULES.md)).
- Update the guides `docs/src/flows/*` and the API reference (`docs/api_reference.jl`
  must reflect renamed/added files).
- **Docstrings last**, once the API has stabilized.
- **No commit without explicit approval** (see [`RULES.md`](RULES.md)).

## Recommended order in one line

**A → B → C → D → E → F → G**, running A in parallel if useful (independent).
