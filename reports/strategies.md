# Strategies — Conceptual Overview

This report introduces the notion of *strategy* as defined in [CTSolvers.jl](https://github.com/control-toolbox/CTSolvers.jl) and used as a design pattern across the Control Toolbox. It is the first step of the CTFlows refactoring described in [`roadmap.md`](roadmap.md): before deciding which strategies and families CTFlows should expose, we need a shared vocabulary and a clear understanding of the contract.

The CTFlows-specific mapping (integrators, loop encapsulations, flow modelers, differential-geometry operators, multi-phase concatenation, etc.) is **deliberately out of scope here** and will be the subject of a follow-up report.

## 1. What is a strategy?

A **strategy** is a typed, configured *descriptor* — not an algorithm. Concretely, it is a small Julia struct that:

- carries a **unique identifier** (a `Symbol`, e.g. `:ipopt`, `:collocation`),
- transports a set of **validated options** with their **provenance** (`:user` vs `:default`),
- serves as a **dispatch handle** for functional entry points such as `solve`, `build_model`, `build_solution`.

The actual algorithmic work happens in methods that dispatch on the strategy's type. The strategy itself is just a configured choice.

Every concrete strategy struct has a single field:

```julia
struct MyStrategy <: SomeFamily
    options::Strategies.StrategyOptions
end
```

## 2. The action-object-strategies pattern

A strategy is useful only through the **actions** it parameterizes. The fundamental pattern is:

```julia
action(object, strategies...) → result
```

- The **object** is the thing being acted upon — a problem, a system, a model.
- The **strategies** are the configured descriptors that control *how* the action is carried out.
- The **result** is a new object: a solution, a flow, a trajectory, …

### 2.1 Concrete example: `solve` in CTSolvers

The high-level `solve` in CTSolvers follows this pattern exactly:

```julia
function CommonSolve.solve(
    problem::Optimization.AbstractOptimizationProblem,
    initial_guess,
    modeler::Modelers.AbstractNLPModeler,
    solver::AbstractNLPSolver;
    display::Bool = __display(),
)
    # Build NLP model
    nlp = Optimization.build_model(problem, initial_guess, modeler)

    # Solve NLP
    nlp_solution = CommonSolve.solve(nlp, solver; display = display)

    # Build OCP solution
    solution = Optimization.build_solution(problem, nlp_solution, modeler)

    return solution
end
```

Here:

- **Object**: `(problem, initial_guess)`
- **Strategies**: `modeler` and `solver`
- **Result**: `solution`

The function is a *pipeline*: it sequences three atomic actions, each mediated by one strategy.

### 2.2 The atomic action

An atomic action is simply calling a strategy directly on an object:

```julia
function build_model(prob, initial_guess, modeler)
    return modeler(prob, initial_guess)
end
```

`build_model` is a thin dispatch wrapper. The real work is `modeler(prob, initial_guess)` — the
strategy *is* the callable. It holds its options and applies them when invoked. The same pattern
holds for the solver: `solver(nlp; display)` is the atomic call.

### 2.3 Why this pattern matters

- **Extensibility**: a new strategy (modeler, solver, …) is added by defining a new type and its
  callable. No existing pipeline code changes.
- **Composability**: a pipeline is a sequence of atomic actions; pipelines can be nested or
  composed without touching the strategies themselves.
- **Option routing**: because each strategy declares its options in metadata, a flat bag of
  `kwargs` at the pipeline level can be routed to the correct strategy automatically (see §5.5).
- **Separation of concerns**: the object carries the problem data; the strategies carry the
  method configuration; the pipeline carries the control flow.

## 3. Three layers of abstraction

```text
AbstractStrategy                  (root contract)
    │
    ├── AbstractStrategyFamily    (business grouping: AbstractNLPSolver,
    │                              AbstractNLPModeler, …)
    │       │
    │       └── ConcreteStrategy  (Ipopt, ADNLP, Collocation, …)
    │
    └── AbstractStrategyParameter (singleton for type-level specialization:
                                   CPU, GPU, …)
```

- **Root** — `AbstractStrategy` defines the *generic* contract (identity, metadata, options).
- **Family** — an abstract subtype that groups interchangeable strategies and adds a **business contract** (e.g. a solver must be callable on an NLP, a modeler must build a model and a solution).
- **Concrete strategy** — a struct subtyping a family, holding only an `options` field.
- **Parameter** — a singleton type used for **type-level** specialization (compile-time dispatch, distinct defaults per backend, e.g. `CPU` vs `GPU`). Parameters are not runtime values.

## 4. The contract

The contract is intentionally split into a **type level** (no instance needed) and an **instance level** (configured object). This separation enables registry lookup, option routing and validation **before** any resource allocation.

### 4.1 Root contract — `AbstractStrategy`

**Type-level methods** (callable on the type itself):

- `Strategies.id(::Type{<:S}) -> Symbol` — unique identifier of the strategy.
- `Strategies.metadata(::Type{<:S}) -> StrategyMetadata` — collection of `OptionDefinition`s, each carrying:
  - `name::Symbol`,
  - `type::Type`,
  - `default` (any),
  - `description::String`,
  - optional `aliases`,
  - optional `validator` (called during construction).

**Instance-level method**:

- `Strategies.options(s::S) -> StrategyOptions` — access to the validated options of an instance, with provenance tracking.

**Canonical constructor**:

```julia
function S(; mode::Symbol = :strict, kwargs...)
    opts = Strategies.build_strategy_options(S; mode = mode, kwargs...)
    return S(opts)
end
```

`build_strategy_options` performs name resolution (including aliases), type checking, validator execution, provenance marking, and Levenshtein-based suggestions on typos. The `mode` argument selects between:

- `:strict` — unknown option names are rejected;
- `:permissive` — unknown options are accepted with `:user` provenance and bypass type validation (useful for backend-specific kwargs).

### 4.2 Family-level contract

Each family **adds requirements on top of the root contract**. Two examples taken from CTSolvers:

- `AbstractNLPModeler` requires two callables:
  - `(modeler)(prob, initial_guess) -> NLP` (build the NLP model),
  - `(modeler)(prob, nlp_stats) -> Solution` (build the user-facing solution).
- `AbstractNLPSolver` requires one callable:
  - `(solver)(nlp; display) -> AbstractExecutionStats`.

Solvers additionally use a **Tag dispatch** pattern so that the strategy *type* can be defined in the main package while the actual implementation lives in a package extension (loaded only when the backend dependency is available). This lets the registry know about a solver before the heavy dependency is brought in.

### 4.3 Parameter contract

A parameter type must:

1. subtype `Strategies.AbstractStrategyParameter`,
2. be a **singleton** (no fields),
3. implement `Strategies.id(::Type{<:P}) -> Symbol`.

Parameters can be passed as the first positional argument of a strategy constructor (`S(GPU; kwargs...)`) and are used to specialize `metadata(S, ::Type{P})` — typically to provide different defaults per backend.

## 5. What you get once the contract is honored

Honoring the contract is what unlocks the rest of the infrastructure. The strategy author writes a small struct, an `id`, a `metadata`, a constructor and an `options` accessor, and from there:

### 5.1 Validation

- `Strategies.validate_strategy_contract(S)` checks that `id`, `metadata`, `options` and the canonical constructor are in place.
- `OptionDefinition` validators are run automatically at construction.
- Typos trigger a friendly error with the closest valid option name.

### 5.2 Registry and resolution

- `Strategies.create_registry(Family => (S1, S2, …), …)` builds a mapping family ↔ concrete strategies.
- `strategy_ids(Family, registry)`, `type_from_id(:id, Family, registry)` query it.
- `build_strategy(:id, Family, registry; kwargs...)` constructs an instance from a symbol.
- `build_strategy_from_method(method, Family, registry; kwargs...)` accepts a **method tuple** like `(:collocation, :adnlp, :ipopt)` and extracts the right symbol per family. This is the basis of multi-strategy selection.

### 5.3 Type-level introspection (no allocation)

Available without instantiating a strategy:

- `option_names(S)`,
- `option_defaults(S)`,
- `option_type(S, :name)`,
- `option_description(S, :name)`.

### 5.4 Provenance

The `StrategyOptions` of an instance distinguishes user-provided values from defaults:

- `Strategies.is_user(opts, :name)`,
- `Strategies.is_default(opts, :name)`,
- `Strategies.source(opts, :name)`.

This is essential when several layers (user, orchestrator, defaults) may want to set the same option: a layer can decide to override only what the user did *not* set explicitly.

### 5.5 Orchestration of options

Because every option is declared in metadata, a single bag of `kwargs...` provided by the user can be **routed** to the right family automatically. This is what enables a high-level call such as

```julia
solve(problem, x0, modeler, solver; max_iter = 1000, grid_size = 500, parameter = :gpu)
```

to dispatch each option to the correct strategy without the user having to know which family owns which option.

### 5.6 Functional vs object level (CommonSolve)

Once a family's callable contract is implemented, the [`CommonSolve`](https://github.com/SciML/CommonSolve.jl) integration provides three coherent levels of API "for free":

- **High level** — full pipeline:
  `solve(problem, x0, modeler, solver) -> Solution`.
- **Mid level** — NLP → stats:
  `solve(nlp, solver) -> AbstractExecutionStats`.
- **Low level** — flexible dispatch:
  `solve(any_compatible_object, solver)` falls back to `solver(any_compatible_object)`.

The high-level form is a *recipe* that internally calls the atomic operations (`build_model`, `solver(nlp)`, `build_solution`). Both levels coexist cleanly precisely because each step is mediated by a strategy that respects the contract.

### 5.7 Parameter-based specialization

When a strategy declares parameters in its registry entry, the orchestration can resolve a user-provided `parameter = :gpu` keyword into the corresponding singleton type and invoke the parameterized constructor. The strategy can then expose **different defaults** per parameter via `metadata(S, ::Type{P})`, all decided at compile time.

## 6. Higher-level orchestration: descriptive, explicit, canonical

The CommonSolve three-level API of §5.6 is the *atomic* layer. On top of it, one can build a **user-facing orchestration layer** that exploits the strategy contract (identifiers, metadata, registry, parameters) to offer much more flexible call shapes. [`OptimalControl.jl/src/solve/`](https://github.com/control-toolbox/OptimalControl.jl/tree/main/src/solve) is a reference implementation of this idea, organized in three tiers.

### 6.1 Descriptive solve — symbolic description + flat options

The user provides a partial or complete *symbolic description* of the method, plus a single flat bag of options:

```julia
solve(ocp, :collocation, :adnlp, :ipopt; grid_size = 100, max_iter = 500, display = false)
```

The orchestration:

1. **completes** the description if partial, by walking a priority list of valid method tuples;
2. **routes** each kwarg to the correct family using metadata (an option declared by `:ipopt` goes to the solver, `:grid_size` to the discretizer, …);
3. **builds** the concrete strategy instances via the registry;
4. **delegates** to the canonical solve.

When the same option name is declared by several families, disambiguation is explicit:

```julia
solve(ocp, :collocation, :adnlp, :ipopt;
      backend = route_to(adnlp = :sparse, ipopt = :cpu))
```

### 6.2 Explicit solve — typed components, partial completion

The user passes already-built strategy instances as keyword arguments, identified by their **abstract family supertype**. Missing components are completed via the registry, using the priority list:

```julia
solve(ocp; discretizer = Collocation(grid_size = 100), solver = Ipopt())
# modeler completed from the registry's first available choice
```

This is convenient when the user wants to build a strategy with non-trivial options up-front and let the system fill in the rest.

### 6.3 Canonical solve — pure execution

The lowest-level call: every component is concrete and fully specified, no defaults, no normalization, no completion. This is the layer that all higher tiers eventually delegate to.

```julia
solve(ocp, init, discretizer, modeler, solver; display)
```

### 6.4 Supporting infrastructure

Two pieces make the higher tiers possible:

- **A method priority list** — an ordered tuple of valid quadruplets `(discretizer_id, modeler_id, solver_id, parameter)`. It plays the role of both a *whitelist* of supported combinations and a *priority order* used to complete a partial description. See `OptimalControl.jl/src/helpers/methods.jl`.
- **A strategy registry** — the single source of truth `Family => (Strategy, [Parameters...])`, declaring which concrete strategies belong to which family and which parameters (e.g. `CPU`, `GPU`) each one supports. See `OptimalControl.jl/src/helpers/registry.jl`.
- **Strategy builders** — recursive helpers that turn a method tuple plus routed options into concrete, parameterized strategy instances. See `OptimalControl.jl/src/helpers/strategy_builders.jl`.

### 6.5 Why three tiers?

The descriptive tier is the user-facing *recipe*: short, declarative, almost natural language. The canonical tier is the atomic execution layer, used by orchestration code and by power users who already hold concrete strategies. The explicit tier is the bridge: typed inputs, partial inputs allowed, completion deterministic. All three rest on the same strategy contract — identifiers for symbolic dispatch, metadata for option routing, registry for completion.

### 6.6 Introspection on top of the registry: `describe`

A registry-aware `describe(:id)` can be exposed as a thin convenience wrapper that calls the generic `CTSolvers.describe(:id, registry)` with the package's own registry pre-bound. It prints the strategy's options, types, defaults and descriptions — all of which are already available through the strategy contract. See [`OptimalControl.jl/src/helpers/describe.jl`](https://github.com/control-toolbox/OptimalControl.jl/blob/main/src/helpers/describe.jl) for an example. This is essentially free once the registry is in place.

### 6.7 Where does the registry live?

The registry is the **single source of truth** for which strategies and parameters are available. It must therefore live in the package that has visibility on **all** strategies it wants to compose. In the Control Toolbox stack:

- **CTFlows** will be a dependency of **OptimalControl**, not the host of the orchestration layer.
- It is **OptimalControl** that owns and maintains the global registry, the `methods()` priority list, and the `solve` / `describe` user-facing functions.
- CTFlows' job is to **define its own families and concrete strategies** and to honor the strategy contract, so that OptimalControl can register them alongside those of CTSolvers, CTDirect, etc.

In other words: CTFlows produces strategies; OptimalControl orchestrates them.

## 7. Why this matters for CTFlows

The CTFlows refactoring described in [`roadmap.md`](roadmap.md) repeatedly hits dimensions of choice that map naturally onto this pattern:

- pluggable ODE integrator backends with a default and a `using`-based opt-in,
- open-loop / closed-loop / dynamic-closed-loop encapsulations,
- functional vs object-level API for flow construction, integration, modeling,
- CPU vs GPU execution,
- modular differential-geometry operators.

Each such dimension can become a **family** with its own business contract, populated by **concrete strategies**, and possibly specialized by **parameters**. Identifying these families, drafting their contracts and listing the concrete strategies to implement is the next step.

## 8. Next step

A follow-up report will:

- enumerate the candidate strategy **families** for CTFlows,
- propose a **business contract** (required methods / signatures) per family,
- list the first **concrete strategies** to implement,
- and connect each family back to the corresponding roadmap items.

## References

Guides:

- [Implementing a Strategy](https://github.com/control-toolbox/CTSolvers.jl/blob/main/docs/src/guides/implementing_a_strategy.md)
- [Strategy Parameters](https://github.com/control-toolbox/CTSolvers.jl/blob/main/docs/src/guides/strategy_parameters.md)
- [Implementing a Modeler](https://github.com/control-toolbox/CTSolvers.jl/blob/main/docs/src/guides/implementing_a_modeler.md)
- [Implementing a Solver](https://github.com/control-toolbox/CTSolvers.jl/blob/main/docs/src/guides/implementing_a_solver.md)

Source code:

- [`src/Strategies/Strategies.jl`](https://github.com/control-toolbox/CTSolvers.jl/blob/main/src/Strategies/Strategies.jl)
- [`src/Strategies/contract/abstract_strategy.jl`](https://github.com/control-toolbox/CTSolvers.jl/blob/main/src/Strategies/contract/abstract_strategy.jl)
- [`src/Strategies/contract/metadata.jl`](https://github.com/control-toolbox/CTSolvers.jl/blob/main/src/Strategies/contract/metadata.jl)
- [`src/Strategies/contract/parameters.jl`](https://github.com/control-toolbox/CTSolvers.jl/blob/main/src/Strategies/contract/parameters.jl)
- [`src/Strategies/contract/strategy_options.jl`](https://github.com/control-toolbox/CTSolvers.jl/blob/main/src/Strategies/contract/strategy_options.jl)
- [`src/Strategies/api/`](https://github.com/control-toolbox/CTSolvers.jl/tree/main/src/Strategies/api)
- [`src/Solvers/abstract_solver.jl`](https://github.com/control-toolbox/CTSolvers.jl/blob/main/src/Solvers/abstract_solver.jl)
- [`src/Solvers/common_solve_api.jl`](https://github.com/control-toolbox/CTSolvers.jl/blob/main/src/Solvers/common_solve_api.jl)
- [`src/Solvers/ipopt.jl`](https://github.com/control-toolbox/CTSolvers.jl/blob/main/src/Solvers/ipopt.jl)
- [`ext/CTSolversIpopt.jl`](https://github.com/control-toolbox/CTSolvers.jl/blob/main/ext/CTSolversIpopt.jl)

Orchestration example (OptimalControl.jl):

- [`src/solve/descriptive.jl`](https://github.com/control-toolbox/OptimalControl.jl/blob/main/src/solve/descriptive.jl)
- [`src/solve/explicit.jl`](https://github.com/control-toolbox/OptimalControl.jl/blob/main/src/solve/explicit.jl)
- [`src/solve/canonical.jl`](https://github.com/control-toolbox/OptimalControl.jl/blob/main/src/solve/canonical.jl)
- [`src/helpers/methods.jl`](https://github.com/control-toolbox/OptimalControl.jl/blob/main/src/helpers/methods.jl)
- [`src/helpers/registry.jl`](https://github.com/control-toolbox/OptimalControl.jl/blob/main/src/helpers/registry.jl)
- [`src/helpers/strategy_builders.jl`](https://github.com/control-toolbox/OptimalControl.jl/blob/main/src/helpers/strategy_builders.jl)
- [`src/helpers/describe.jl`](https://github.com/control-toolbox/OptimalControl.jl/blob/main/src/helpers/describe.jl)
