# Abstract types, interfaces and trait-based dispatch

**Overall architectural reflection — CTFlows.jl**

This report answers three related questions:

1. **Exception choice** — when to throw `IncorrectArgument` vs `PreconditionError`
   (and the other CTBase types)?
2. **`AbstractContentTrait`** — how is it used? How large a change to parametrize
   flows/systems by the content trait?
3. **Big picture** — can we have *fewer abstract types*, clearer *interfaces
   (contracts)*, and more *specific dispatch via traits*?

It supersedes — and proposes to replace — the report
[`../abstract_interface/rapport.md`](../abstract_interface/rapport.md), whose direction
("add *more* abstract types") partly contradicts the conclusion below.

---

## 1. CTBase exception choice

CTBase defines seven exceptions under `CTException`. The two that overlap in practice
are `IncorrectArgument` and `PreconditionError`. The boundary is sharp once stated
correctly:

| Exception | Fields | Semantics | Usage rule |
|---|---|---|---|
| `IncorrectArgument` | `msg, got, expected, suggestion, context` | "an input value is out of the allowed domain" | **a single argument** is invalid, independently of the others |
| `PreconditionError` | `msg, reason, suggestion, context` | "the call violates a precondition / is not allowed in this state" | arguments valid individually, but their **combination / timing / manner** is forbidden |
| `NotImplemented` | `msg, required_method, suggestion, context` | interface point a concrete subtype must implement | **contract stub** on an abstract type |
| `ExtensionError` | `weakdeps, feature, context` | optional dependency not loaded | feature behind a `weakdep` (e.g. SciML) |
| `SolverFailure` | `msg, retcode, suggestion, context` | numerical failure of a solver | non-success integration retcode |
| `AmbiguousDescription` | `description, candidates, …` | unresolved symbol tuple | strategy / description routing |
| `ParsingError` | `msg, location, suggestion` | syntax/structure error | parsing |

### The decision rule

> **`IncorrectArgument`** = "*this value* is wrong" (domain of **one** argument).
> **`PreconditionError`** = "*this combination / state / timing* is wrong" (a
> **relational** or contextual contract, each argument valid on its own).

### Application to CTFlows

The current usage in [`src/Flows/calling.jl`](../../src/Flows/calling.jl) is
**correct**: the variable contract (`Fixed` receives a variable, `NonFixed` does not,
`variable_costate` unsupported…) is **relational** — the value of `variable` may be
perfectly valid, what is forbidden is its presence/absence *relative to the flow's
trait*. → `PreconditionError`. ✓

By contrast, the report [`multiphase_type_constraint.md`](multiphase_type_constraint.md)
initially had mis-chosen `IncorrectArgument` calls (using a `reason` field that
`IncorrectArgument` **does not have**). Corrected to `PreconditionError` because all
those errors are relational:

| Situation | Correct exception | Why |
|---|---|---|
| Concatenate state × Hamiltonian | `PreconditionError` | each flow valid; the *combination* is forbidden |
| Phases with different TD/VD | `PreconditionError` | relational between phases |
| Non-increasing switching times | `PreconditionError` | relational ordering of values |
| Dimension mismatch at a boundary | `PreconditionError` | precondition of the next phase |
| Negative tolerance, empty phase tuple | `IncorrectArgument` | domain of **one** argument |
| Unimplemented contract method | `NotImplemented` | interface stub |
| `:sciml` option without the extension loaded | `ExtensionError` | missing weakdep |

**Operational heuristic**: if the message must mention **two things** ("x *relative to*
y", "this phase *after* that one"), it is almost always `PreconditionError`. If it
mentions **one** value ("n must be > 0"), it is `IncorrectArgument`.

---

## 2. The dynamics trait (formerly `AbstractContentTrait`)

### Naming decision: `content` → `dynamics`

"content" is too neutral: it does not name the axis being distinguished. This trait
distinguishes the **kind of integrated dynamics** (equivalently, the structure of the
carried object). So the whole axis is renamed:

| Current | Target | Carried object |
|---|---|---|
| `AbstractContentTrait` | `AbstractDynamicsTrait` | — |
| `StateTrait` | `StateDynamics` | `x` |
| `HamiltonianTrait` | `HamiltonianDynamics` | `(x, p)` |
| `AugmentedHamiltonianTrait` | `AugmentedHamiltonianDynamics` | `(x, p, p_v)` |
| `content_trait(·)` | `dynamics_trait(·)` | extractor |

Bonus: the target values no longer need the `Trait` suffix (present today only to avoid
collision with `Data.Hamiltonian` and "State") — `StateDynamics` / `HamiltonianDynamics`
are clean and collision-free. The accessor is `dynamics_trait` (not `dynamics`) so as
not to clash with a possible `dynamics(sys)` returning the *function*.

> In what follows: blocks describing the **current code** keep the old names (repo
> reality); **proposal** blocks use the target names.

### State of play (current names)

The trait already exists:

```julia
abstract type AbstractContentTrait <: AbstractTrait end
struct StateTrait               <: AbstractContentTrait end  # carried: x
struct HamiltonianTrait         <: AbstractContentTrait end  # carried: (x, p)
struct AugmentedHamiltonianTrait<: AbstractContentTrait end  # carried: (x, p, p_v)
```

But it is used **only** in `Configs`, which makes it a *type parameter*:

```julia
abstract type AbstractConfigWithMaC{X0, Mode<:AbstractModeTrait, Content<:AbstractContentTrait}
        <: AbstractConfig{X0} end

# dispatch aliases
const AbstractStateConfig{X0, M}       = AbstractConfigWithMaC{X0, M, StateTrait}
const AbstractHamiltonianConfig{X0, M} = AbstractConfigWithMaC{X0, M, HamiltonianTrait}

# trait extractor
content_trait(::AbstractConfigWithMaC{X0, Mode, Content}) where {X0, Mode, Content} = Content
```

…and `build_solution` dispatches by **passing the extracted trait** as a type argument:

```julia
build_solution(::Type{PointTrait}, ::Type{StateTrait},       config, result) = …
build_solution(::Type{PointTrait}, ::Type{HamiltonianTrait}, config, result) = …
```

**This is exactly the target pattern.** `Configs` proves CTFlows already does
"trait-as-parameter + alias + extractor + dispatch".

### The contrast: Flows and Systems do the opposite

Where `Configs` encodes the content in a *parameter*, `Flows` and `Systems` encode it in
the *type hierarchy*:

```julia
# Flows — content is a branch of the tree
abstract type AbstractFlow{TD, VD} end
abstract type AbstractStateFlow{TD, VD, S<:AbstractStateSystem{TD,VD}}        <: AbstractFlow{TD, VD} end
abstract type AbstractHamiltonianFlow{TD, VD, S<:AbstractHamiltonianSystem{…}} <: AbstractFlow{TD, VD} end
struct StateFlow{TD, VD, S, I}       <: AbstractStateFlow{…} end
struct HamiltonianFlow{TD, VD, S, I} <: AbstractHamiltonianFlow{…} end
```

`StateFlow` and `HamiltonianFlow` have **identical fields** (`system`, `integrator`).
They differ only in (a) the call signature (`(t0,x0,tf)` vs `(t0,x0,p0,tf)`) and (b) the
solution type produced — *two differences already dispatched by trait elsewhere* (in
`Configs`/`build_solution`).

### Proposal: unify on the dynamics-parameter (target names)

```julia
# A single family, parametrized by the dynamics
abstract type AbstractFlow{TD, VD, D<:AbstractDynamicsTrait} end

const AbstractStateFlow{TD, VD}       = AbstractFlow{TD, VD, StateDynamics}
const AbstractHamiltonianFlow{TD, VD} = AbstractFlow{TD, VD, HamiltonianDynamics}

dynamics_trait(::AbstractFlow{TD, VD, D}) where {TD, VD, D} = D
```

And — since the fields are identical — **merge the two concrete structs**:

```julia
struct Flow{TD, VD, D, S<:AbstractSystem{TD,VD}, I<:AbstractIntegrator} <: AbstractFlow{TD, VD, D}
    system     :: S
    integrator :: I
end

const StateFlow{TD,VD,S,I}       = Flow{TD,VD,StateDynamics,S,I}
const HamiltonianFlow{TD,VD,S,I} = Flow{TD,VD,HamiltonianDynamics,S,I}
```

Call signatures stay cleanly dispatched via the aliases:

```julia
(f::AbstractStateFlow)(t0, x0, tf; …)        = _invoke_flow(f, StatePointConfig(t0, x0, tf); …)
(f::AbstractHamiltonianFlow)(t0, x0, p0, tf; …) = _invoke_flow(f, HamiltonianPointConfig(t0, x0, p0, tf); …)
```

Likewise on the systems side:

```julia
abstract type AbstractSystem{TD, VD, D<:AbstractDynamicsTrait} end
const AbstractStateSystem{TD,VD}       = AbstractSystem{TD,VD,StateDynamics}
const AbstractHamiltonianSystem{TD,VD} = AbstractSystem{TD,VD,HamiltonianDynamics}
```

### Benefits

- **Multi-phase becomes trivial**: the concatenation constraint becomes
  `Tuple{Vararg{AbstractFlow{TD,VD,D}}}` — same dynamics `D` *including the augmented
  case*, expressed in one line at the type level (cf.
  [`multiphase_type_constraint.md`](multiphase_type_constraint.md)).
- **Fewer types**: one `AbstractFlow` instead of three levels; potentially one `Flow`
  concrete type instead of two.
- **Dispatchable dynamics**: `dynamics_trait(flow)` everywhere, consistent with `Configs`.
- **A single pattern** across the whole codebase.

### Size of the change

**Medium, mostly mechanical.** Files touched:

| File | Change |
|---|---|
| `src/Traits/content.jl` → `dynamics.jl` | rename the trait (`AbstractDynamicsTrait`, `StateDynamics`, …) + `dynamics_trait`; exports |
| `src/Configs/*`, `src/Solutions/building.jl` | adapt to the new names (`content_trait` → `dynamics_trait`, values) |
| `src/Flows/abstract_flow.jl` | redefine the hierarchy + aliases + `dynamics_trait` |
| `src/Flows/flow.jl` | merge `StateFlow`/`HamiltonianFlow` into `Flow` + aliases |
| `src/Flows/calling.jl` | dispatch on the aliases (nearly unchanged: `AbstractStateFlow` stays a valid type) |
| `src/Systems/abstract_system.jl` | same on the systems side |
| `src/MultiPhase/*` | benefits directly; field → tuple |
| export / type tests | update subtyping assertions |

Reassuring point: **the aliases preserve the public names** (`AbstractStateFlow`,
`HamiltonianFlow`, …). User code and most internal code dispatching on those names keep
working — an alias is a real type for dispatch. That is what makes the migration
low-risk.

---

## 3. Big picture: noun vs adjective

### The guiding principle

The classic Julia tension:

- **Abstract type** = good for a *noun* ("what is it"), `is-a` relations and shared
  methods. But: single inheritance only → combinatorial explosion across several
  orthogonal axes.
- **Trait (as a type parameter)** = good for an *adjective / capability*. Composes
  freely, dispatched via an extractor.

> **Rule.** One abstract type per real *noun*. One trait-parameter per *orthogonal axis*.
> Concrete types are reserved for *genuinely different data layouts*.

### Audit of CTFlows axes

| Axis | Values | Nature | Current encoding | Ideal encoding |
|---|---|---|---|---|
| Time | `Autonomous` / `NonAutonomous` | adjective | trait-parameter ✓ | trait ✓ |
| Variable | `Fixed` / `NonFixed` | adjective | trait-parameter ✓ | trait ✓ |
| Mutability | `InPlace` / `OutOfPlace` | adjective | trait-parameter ✓ | trait ✓ |
| AD | `WithAD` / `WithoutAD` | capability | trait-parameter ✓ | trait ✓ |
| Variable costate | `Supports…` / `No…` | capability | trait + delegation ✓ | trait ✓ |
| Mode | `Point` / `Trajectory` | adjective | trait-parameter (Configs) ✓ | trait ✓ |
| **Dynamics** (ex-content) | `StateDynamics` / `HamiltonianDynamics` / `AugmentedHamiltonianDynamics` | adjective* | **inconsistent**: trait in `Configs`, **hierarchy** in `Flows`/`Systems` | **trait-parameter everywhere** |
| "Vector field" vs "Hamiltonian+AD" vs "HVF" | — | **noun** | concrete types `VectorFieldSystem` / `HamiltonianSystem` / `HamiltonianVectorFieldSystem` | **concrete types** (correct) |

\* Dynamics is an *adjective* from the standpoint of the *integration machinery* (system
+ integrator, build/solve/build_solution are identical), even if a layperson reads it as
a "noun". Proof: `Configs` already treats it as a trait without trouble.

**Audit conclusion**: exactly one axis is misplaced — **dynamics** (ex-content) in
`Flows`/`Systems`. Everything else already follows the right pattern. The architectural
debt is therefore *localized*, not systemic.

### Where concrete types remain justified

The three concrete systems have **genuinely different fields**:

- `VectorFieldSystem` stores a `VectorField` (+ pre-built RHS).
- `HamiltonianVectorFieldSystem` stores a `HamiltonianVectorField`.
- `HamiltonianSystem` stores a `Hamiltonian` **and** an AD backend.

These are real *nouns* (distinct data layouts). We keep them — but they now share
`AbstractSystem{TD,VD,D}` and are further distinguished by the `ad_trait`
(`WithAD`/`WithoutAD`) trait. That is exactly what trait dispatch enables:
`hamiltonian_vector_field(sys)` can be defined **once** on `AbstractHamiltonianSystem`
and branch on `ad_trait(sys)` instead of having one method per concrete type.

### Reconciliation with the `abstract_interface` report

The previous report is **right** on one point and **wrong** on another:

| `abstract_interface` recommendation | Verdict | Reason |
|---|---|---|
| Define contracts (`NotImplemented`) on abstract types | ✅ **Keep** | that is the very definition of an interface |
| Accept abstract inputs (`build_system(::AbstractVectorField)`) | ✅ **Keep** | real extensibility |
| Move `hamiltonian_vector_field`, `build_rhs`… onto abstract types + trait dispatch | ✅ **Keep** | exactly the right pattern |
| Annotate internal helpers for type stability | ✅ **Keep** | correct |
| **Create *more* abstract types** (e.g. `AbstractSystemWithAD`) | ❌ **Drop** | AD is an *orthogonal capability* → it is `ad_trait`, not a type. An `AbstractSystemWithAD` type would glue AD to the hierarchy and collide with the dynamics axis (single inheritance!). |

In other words: **keep the idea of interfaces on abstract types + trait dispatch, but
flip the urge to "add abstract types" into "add trait-parameters and aliases".**

### Scope of the axis: where it stops (Data, Solutions, extensions)

A natural follow-up: if the dynamics axis is good for `Flows`/`Systems`, should it be
pushed into **`Data`** (`VectorField` / `Hamiltonian` / `HamiltonianVectorField`) and
**`Solutions`** (`VectorFieldSolution` / `HamiltonianVectorFieldSolution`) too? **No.**
The axis is right for Flows/Systems for a precise reason that does *not* hold downstream,
and the boundary is worth stating as a rule.

#### The decisive test: parameter vs noun

> **Test.** Fix every *other* trait (`TD`, `VD`, `MD`). Does the dynamics value still
> range over several instances of the **same concrete struct**?
>
> - **Yes** → dynamics is an orthogonal *adjective* → encode it as a **type parameter**
>   `D` (+ aliases). The machinery is layout-agnostic.
> - **No** → each dynamics value corresponds to a **different struct with different
>   fields** → dynamics is a *noun* → keep distinct concrete types; do **not** add `D`.

Applying it:

| Layer | Same layout, varies only by dynamics? | Encoding |
|---|---|---|
| `AbstractFlow` / `Flow` | **Yes** — `StateFlow` and `HamiltonianFlow` have *identical* fields (`system`, `integrator`); only the call signature and produced solution differ | parameter `D` **+ merge** |
| `AbstractSystem` (abstract) | **Yes** at the abstract level — concrete systems keep distinct fields but share `AbstractSystem{TD,VD,D}` via aliases | parameter `D` |
| `Data` | **No** — `VectorField` carries a mutability trait `MD` and returns `ẋ`; `Hamiltonian` is **scalar** (no `MD` at all) and returns `ℝ`; `HamiltonianVectorField` returns `(ẋ, ṗ)`. Different arities, fields and contracts. | **distinct nouns** (unchanged) |
| `Solutions` | **No** — `VectorFieldSolution{R}` vs `HamiltonianVectorFieldSolution{X0,R}`: different fields (`x0`, needed to split `x`/`p`) and different interface (`costate`, tuple-valued `sol(t)`). | **distinct nouns** (unchanged) |

So the dynamics axis extends to **`Flows` + `Systems` (+ `MultiPhase`, which derives from
them)** — and stops there. `Data` and `Solutions` are *nouns* with genuinely different
data layouts; parametrizing them by `D` would be redundant (`VectorField` is *always*
`StateDynamics`) and would buy no merge, no shared method, no tuple constraint.

#### How Data and Solutions still participate in the axis

They participate through their **boundaries**, not through a parameter:

- **Input side — `Configs`.** `Configs` is where the dynamics trait *lives as a
  parameter* (`AbstractConfigWithMaC{X0, Mode, Dynamics}`). It is the single producer of
  the dynamics value for the integration pipeline.
- **Output side — `build_solution`.** `Solutions` already consumes the dynamics trait
  the *right* way: `build_solution(::Type{Mode}, ::Type{Dynamics}, config, result)`
  dispatches on `Mode × Dynamics` (Point/Trajectory × State/Hamiltonian/Augmented). This
  is the target pattern, already in place. Phase B only renames the *values*
  (`StateTrait`→`StateDynamics`, …) in `src/Solutions/building.jl`; the structure is
  correct as is.
- **Data→System / System→Solution handoffs** dispatch on the *concrete* Data/Solution
  type (`build_system(::VectorField)`, …). The dynamics nature is already carried by the
  type, so no trait extraction is required at these seams.

#### Optional: a constant `dynamics_trait` extractor (not a parameter)

Even where dynamics is a noun, a uniform **extractor** can be exposed — a *method*
returning a compile-time constant per type, not a struct parameter:

```julia
# src/Data/* — optional, one line per abstract Data type
Traits.dynamics_trait(::Data.AbstractVectorField)           = Traits.StateDynamics
Traits.dynamics_trait(::Data.AbstractHamiltonian)           = Traits.HamiltonianDynamics
Traits.dynamics_trait(::Data.AbstractHamiltonianVectorField)= Traits.HamiltonianDynamics
```

This is the `eltype`-style "trait over a noun": it gives the whole stack one vocabulary
and would let a future generic check assert that a flow's system dynamics matches the
data it wraps. It changes **no layout** and adds **no parameter**. It is *optional* and
low-priority — justified only once a consumer needs it (none today). Do **not** confuse
it with the `Flows`/`Systems` parameter: there `D` is read off a *type parameter*
(varies); here it is a hard-coded constant (invariant per type).

#### Extensions (SciML): no change, and that is the proof

The SciML extension reaches the dynamics axis **only** through supertypes:

- `SciMLFunctionSystem <: Systems.AbstractStateSystem{NonAutonomous, NonFixed}`
- `SciMLProblemFlow <: Flows.AbstractStateFlow{…}`
- RHS functors `<: Systems.AbstractIPRHS / AbstractOoPRHS` — *unrelated* to dynamics.
- `SciMLIntegrationResult <: Integrators.AbstractIntegrationResult` — Integrators layer,
  *no* dynamics involvement.

Once `AbstractStateSystem{TD,VD} = AbstractSystem{TD,VD,StateDynamics}` and
`AbstractStateFlow{TD,VD} = AbstractFlow{TD,VD,StateDynamics}` become **aliases**, the
subtyping clauses above stay valid verbatim — an alias is a real type for subtyping and
dispatch. So **the entire `CTFlowsSciML` extension compiles untouched** by the
parametrization. This non-invasiveness is itself evidence that the change is correctly
scoped: a refactor that forced edits into the weak-dependency extension would be
leaking the axis past its proper boundary.

> **Synthesis of scope.** Parametrize by `D` exactly where the *machinery is identical
> and only the carried object differs* (`Flows`, `Systems`, hence `MultiPhase`). Keep
> distinct concrete types where the *data layout genuinely differs* (`Data`,
> `Solutions`). Let those layers touch the axis through `Configs` (in) and
> `build_solution` (out). The aliases keep the extensions free of any change.

---

## 4. The cost of trait dispatch (and why it is negligible here)

The pattern used in `calling.jl`:

```julia
function _invoke_flow(flow, config; variable, unsafe)
    VD = Traits.variable_dependence(flow)          # extract the trait
    return _invoke_flow(VD, typeof(variable), flow, config; …)  # re-dispatch
end
```

This is the **Holy trait pattern**. It is **type-stable** here because
`variable_dependence(flow)` reads a *type parameter*: the result is a type known at
compile time, so the re-dispatch resolves statically. The only overhead is a call layer
the compiler inlines. Keep it as is.

⚠️ The pitfall to avoid: extracting a trait from a *runtime value* (not encoded in the
type) would make the re-dispatch dynamic and break inference. That is not the case as
long as traits remain type parameters.

---

## 5. Phased proposal

| Phase | Content | Risk |
|---|---|---|
| **0** | Adopt the exception rule (§1); fix existing relational `IncorrectArgument`→`PreconditionError` | none |
| **0bis** | Rename the axis: `content`→`dynamics` (`AbstractDynamicsTrait`, `StateDynamics`, … ; `content_trait`→`dynamics_trait`) in `Traits`/`Configs`/`Solutions` | low (purely mechanical) |
| **1** | Parametrize `AbstractSystem{TD,VD,D}` + aliases + `dynamics_trait`, leaving concretes alone (just `<: AbstractSystem{TD,VD,StateDynamics}`) | low |
| **2** | Same for `AbstractFlow{TD,VD,D}` + aliases | low |
| **3** | Merge `StateFlow`/`HamiltonianFlow` → `Flow{…,D,…}` + aliases | medium (type tests) |
| **4** | Move getters/builders (`hamiltonian_vector_field`, `build_rhs`…) onto abstracts with `ad_trait` dispatch (resumes `abstract_interface` phases 4-5) | medium |
| **5** | Rework `MultiPhase` on a tuple + `Vararg{AbstractFlow{TD,VD,D}}` constraint | medium |
| **6** | Cleanup: remove redundant concrete methods now covered by the abstracts | low |

Each phase is independently testable and the aliases guarantee **no regression of the
public names**.

---

## 6. One-sentence synthesis

> CTFlows already has, in `Configs`, the right model — *one abstract type per noun, one
> trait-parameter per adjective, dispatch via a trait extractor*. The debt is localized
> to the **dynamics** axis (ex-"content", to be renamed) mis-encoded as a hierarchy in
> `Flows`/`Systems`; fixing it reduces the number of types, makes the contracts explicit,
> simplifies multi-phase, and requires only mechanical changes shielded by aliases.
