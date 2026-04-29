# CTFlows Design: Contracts and Pipelines

This document specifies the abstract types, strategy family contracts, and pipeline functions
of CTFlows in enough detail to write tests with fake concrete types. It is the operational
counterpart of [`candidate_strategies.md`](candidate_strategies.md) (which lists candidates
and rationale) and [`strategies.md`](strategies.md) (which describes the CTSolvers strategy
contract on which this design rests).

## 1. Overview

CTFlows organises its code along three concerns:

- **Objects** — `AbstractSystem` and `AbstractFlow` (with their multi-phase variants). They
  are *what* is acted upon. Not strategies.
- **Strategy families** — `AbstractFlowModeler`, `AbstractODEIntegrator`, `AbstractADBackend`.
  Each family is `<: CTSolvers.Strategies.AbstractStrategy` and inherits the full CTSolvers
  contract (`id`, `metadata`, `options`, `Base.show`, `describe`, …).
- **Actions / pipelines** — `build_system`, `build_flow`, `integrate`, `build_solution`,
  `solve`. They are written **on the abstract types** so that a concrete implementation
  (real or fake) plugs in without changing the pipeline.

Every required method has a default implementation that throws
`CTBase.Exceptions.NotImplemented` with a descriptive message and a suggestion — this is the
mechanism that *forces* every concrete type to honour its contract, exactly as in
[`abstract_strategy.jl`](https://github.com/control-toolbox/CTSolvers.jl/blob/main/src/Strategies/contract/abstract_strategy.jl).

The pseudo-code below is illustrative; the actual Julia source will live in `src/`.

## 2. Non-strategy types (objects)

These are pure objects with their own contract. They do **not** inherit from
`AbstractStrategy`, so `id`/`metadata`/`options` do not apply, and `Base.show` must be
defined explicitly using the same tree-style formatting as CTSolvers strategies (cf.
[`abstract_strategy.jl#L299-L349`](https://github.com/control-toolbox/CTSolvers.jl/blob/ff6e57d3dd598a4143b8f2bf0a85d5fa4c264c92/src/Strategies/contract/abstract_strategy.jl#L299-L349)).

### 2.1 `AbstractSystem`

The fully assembled object that can be integrated. It embeds its own `rhs!`, dimensional
metadata, and solution-building logic — assembled once at `build_system` time.

```julia
abstract type AbstractSystem end
```

**Required methods** (NotImplemented defaults):

```julia
function rhs!(system::AbstractSystem)
    throw(NotImplemented(
        "AbstractSystem rhs! method not implemented";
        required_method = "rhs!(system::$(typeof(system)))",
        suggestion = "Return a function (du, u, p, t) -> nothing that fills du in place.",
        context = "AbstractSystem.rhs! - required method implementation",
    ))
end

function dimensions(system::AbstractSystem)
    throw(NotImplemented(
        "AbstractSystem dimensions method not implemented";
        required_method = "dimensions(system::$(typeof(system)))",
        suggestion = "Return a NamedTuple, e.g. (n_x=n, n_p=n, n_u=m, n_v=k).",
        context = "AbstractSystem.dimensions - required method implementation",
    ))
end

function build_solution(system::AbstractSystem, ode_sol)
    throw(NotImplemented(
        "AbstractSystem build_solution method not implemented";
        required_method = "build_solution(system::$(typeof(system)), ode_sol)",
        suggestion = "Package the raw ODE trajectory into the appropriate result (raw trajectory or CTModels.Solution).",
        context = "AbstractSystem.build_solution - required method implementation",
    ))
end
```

**Contract semantics**:

- `rhs!` returns a closure that captures whatever the system needs (parameters, control law,
  AD backend results, …). Once obtained, the system has no further dependency on the modeler.
- `dimensions` is the canonical introspection point for state/costate/control/variable sizes;
  it is what the integrator and the multi-phase composition use to verify compatibility.
- `build_solution` is the post-processing step. For raw systems (vector field) it returns
  the trajectory as-is; for OCP systems it integrates the Lagrange cost, reconstructs the
  control, and returns a `CTModels.Solution`.

**`Base.show`**:

- `Base.show(io, ::MIME"text/plain", system)` — tree-style: type name → `id` (none, since
  not a strategy) → `dimensions` fields, one per line.
- `Base.show(io, system)` — compact: `TypeName(n_x=…, n_p=…, …)`.

### 2.2 `AbstractFlow`

A callable object that combines an `AbstractSystem` with an `AbstractODEIntegrator`. It
carries no business logic of its own — its job is to expose the integration protocol.

```julia
abstract type AbstractFlow end
```

**Required methods** (NotImplemented defaults):

```julia
function (flow::AbstractFlow)(t0, x0, tf)
    throw(NotImplemented(...; required_method = "(flow::$(typeof(flow)))(t0, x0, tf)"))
end

function (flow::AbstractFlow)(t0, x0, p0, tf)
    throw(NotImplemented(...; required_method = "(flow::$(typeof(flow)))(t0, x0, p0, tf)"))
end

function system(flow::AbstractFlow)
    throw(NotImplemented(...; required_method = "system(flow::$(typeof(flow)))"))
end

function integrator(flow::AbstractFlow)
    throw(NotImplemented(...; required_method = "integrator(flow::$(typeof(flow)))"))
end
```

**Concrete `Flow <: AbstractFlow`** (provided by CTFlows):

```julia
struct Flow{S<:AbstractSystem, I<:AbstractODEIntegrator} <: AbstractFlow
    system::S
    integrator::I
end

system(f::Flow)     = f.system
integrator(f::Flow) = f.integrator

function (f::Flow)(t0, x0, tf)
    # build ODEProblem from rhs!(f.system), tspan = (t0, tf), initial = x0
    # call f.integrator(prob, (t0, tf))
    # return f.system.build_solution(ode_sol)  # or raw trajectory depending on system
end
```

**`Base.show`**:

- Plain text: tree-style with `system` (compact form) and `integrator` (its `id`) as children.
- Compact: `Flow(system=…, integrator=…)`.

### 2.3 `MultiPhaseSystem <: AbstractSystem`

An ordered list of systems plus switching conditions, assembled into one composite
`AbstractSystem`. Inherits the full `AbstractSystem` contract — `rhs!`, `dimensions`, and
`build_solution` are all defined and dispatch internally to the relevant phase.

**Additional required methods** (NotImplemented defaults):

```julia
function phases(system::MultiPhaseSystem)
    throw(NotImplemented(...; required_method = "phases(system::$(typeof(system)))"))
end

function switching(system::MultiPhaseSystem)
    throw(NotImplemented(...; required_method = "switching(system::$(typeof(system)))"))
end
```

`phases` returns `Vector{<:AbstractSystem}`; `switching` returns the times or conditions
between consecutive phases. Compatibility (same OCP type, matching dimensions) is checked at
construction.

**Operator**: `sys1 ∘ sys2` builds a `MultiPhaseSystem` from compatible systems.

### 2.4 `MultiPhaseFlow <: AbstractFlow`

Concatenation of complete flows. Each phase keeps its own integrator; phases run sequentially.

**Additional required methods** (NotImplemented defaults):

```julia
function phases(flow::MultiPhaseFlow)
    throw(NotImplemented(...; required_method = "phases(flow::$(typeof(flow)))"))
end

function switching(flow::MultiPhaseFlow)
    throw(NotImplemented(...; required_method = "switching(flow::$(typeof(flow)))"))
end
```

**Operator**: `flow1 * flow2` builds a `MultiPhaseFlow`. Compatibility check: state
dimension out of `flow1` must equal state dimension in of `flow2`.

## 3. Strategy families (full CTSolvers contract)

Each family is `<: CTSolvers.Strategies.AbstractStrategy` and therefore inherits **for free**:

- `id(::Type{<:S}) → Symbol` — NotImplemented default from CTSolvers
- `metadata(::Type{<:S}) → StrategyMetadata` — NotImplemented default from CTSolvers
- `options(s::S) → StrategyOptions` — default reads `s.options` field
- `Base.show(io, ::MIME"text/plain", s)` and `Base.show(io, s)` — tree + compact, automatic
- `describe(::Type{<:S})` — automatic, prints id/hierarchy/metadata

Concrete strategy types must:

1. Have an `options::StrategyOptions` field
2. Implement `id(::Type{<:S})` and `metadata(::Type{<:S})`
3. Provide a constructor `S(; mode=:strict, kwargs...)` that calls `build_strategy_options`
4. Implement the family-specific **business callable** (see below)

### 3.1 `AbstractFlowModeler <: AbstractStrategy`

**Role**: assemble an `AbstractSystem` from a single input.

```julia
abstract type AbstractFlowModeler <: AbstractStrategy end
```

**Business callable** (NotImplemented default):

```julia
function (modeler::AbstractFlowModeler)(input)
    throw(NotImplemented(
        "AbstractFlowModeler callable not implemented";
        required_method = "(modeler::$(typeof(modeler)))(input)",
        suggestion = "Implement (m::YourModeler)(input) returning an AbstractSystem. " *
                     "For OCP modelers, accept input as a tuple (ocp, u).",
        context = "AbstractFlowModeler call - required method implementation",
    ))
end
```

**Note on input typing**: the fallback intentionally leaves `input` unqualified so concrete
modelers can dispatch freely. `OpenLoopModeler` will dispatch on `Tuple{<:OCP, <:Function}`,
`HamiltonianModeler` on `<:Hamiltonian`, etc. There is no overload `(m)(ocp, u)` — the
unified signature `(m)(input)` is the only one.

**Candidate option specs** (for `metadata`): `augmented::Bool`, `internalnorm`, `tstops`,
`jumps`. Concrete modelers add their own.

### 3.2 `AbstractODEIntegrator <: AbstractStrategy`

**Role**: solve a Cauchy problem.

```julia
abstract type AbstractODEIntegrator <: AbstractStrategy end
```

**Business callable** (NotImplemented default):

```julia
function (integrator::AbstractODEIntegrator)(ode_problem, tspan)
    throw(NotImplemented(
        "AbstractODEIntegrator callable not implemented";
        required_method = "(integrator::$(typeof(integrator)))(ode_problem, tspan)",
        suggestion = "Implement (i::YourIntegrator)(prob, tspan) returning an ODE solution.",
        context = "AbstractODEIntegrator call - required method implementation",
    ))
end
```

**Candidate option specs**: `abstol`, `reltol`, `saveat`, `dense`, `maxiters`,
`internalnorm`.

**Parameters** (in CTSolvers' parametric sense): `CPU`, `GPU` — different defaults at compile
time.

### 3.3 `AbstractADBackend <: AbstractStrategy`

**Role**: provide gradient and Jacobian capabilities used by flow modelers when assembling a
system from an OCP (e.g. computing $\partial H/\partial p$, $\partial H/\partial x$).

```julia
abstract type AbstractADBackend <: AbstractStrategy end
```

**Business callables** (NotImplemented defaults):

```julia
function ctgradient(backend::AbstractADBackend, f, x)
    throw(NotImplemented(...; required_method = "ctgradient(backend::$(typeof(backend)), f, x)"))
end

function ctjacobian(backend::AbstractADBackend, f, x)
    throw(NotImplemented(...; required_method = "ctjacobian(backend::$(typeof(backend)), f, x)"))
end
```

**Where it plugs in**: passed as a **separate argument** to `build_system` (see §4.1). The
modeler receives it and uses it internally to differentiate the user-provided functions.

**Candidate option specs**: `chunk_size`, `tag`. Concrete backends add their own.

## 4. Pipelines on abstract objects

All pipelines below are written using only the abstract types declared in §2 and §3. They
are the level at which tests are written: provide a fake concrete type implementing the
required methods, run the pipeline, check the result.

### 4.1 `build_system`

```julia
function build_system(input,
                      modeler::AbstractFlowModeler,
                      ad_backend::AbstractADBackend)
    return modeler(input, ad_backend)   # delegate to modeler's business callable
end
```

The modeler receives both the input and the AD backend; what it does with the backend is its
own concern (the contract only forces it to return an `AbstractSystem`).

> **Note**: a default AD backend can be provided so that `build_system(input, modeler)` is a
> shorter form for the common case.

### 4.2 `build_flow`

Atomic form (no modeler involved):

```julia
function build_flow(system::AbstractSystem, integrator::AbstractODEIntegrator)
    return Flow(system, integrator)
end
```

Pipeline alias (combines `build_system` and `build_flow`):

```julia
function build_flow(input,
                    modeler::AbstractFlowModeler,
                    integrator::AbstractODEIntegrator,
                    ad_backend::AbstractADBackend)
    system = build_system(input, modeler, ad_backend)
    return build_flow(system, integrator)
end
```

### 4.3 `integrate`

```julia
integrate(flow::AbstractFlow, t0, x0, tf)     = flow(t0, x0, tf)
integrate(flow::AbstractFlow, t0, x0, p0, tf) = flow(t0, x0, p0, tf)
```

Thin wrapper over the callable protocol of `AbstractFlow`. Useful when one wants to spell
out the action by name rather than calling the flow directly.

### 4.4 `build_solution`

```julia
function build_solution(system::AbstractSystem, ode_sol)
    # Delegates to the system's own build_solution (embedded by the modeler at
    # build_system time). Required method on AbstractSystem (§2.1).
    return _embedded_build_solution(system, ode_sol)
end
```

No strategy argument: the packaging logic was embedded by the modeler when the system was
assembled. This is the consequence of choosing a *fully assembled* system in §2.1.

### 4.5 `solve`

```julia
function solve(flow::AbstractFlow, tspan, x0)
    t0, tf = tspan
    ode_sol = integrate(flow, t0, x0, tf)
    return build_solution(system(flow), ode_sol)
end

function solve(flow::AbstractFlow, tspan, x0, p0)
    t0, tf = tspan
    ode_sol = integrate(flow, t0, x0, p0, tf)
    return build_solution(system(flow), ode_sol)
end
```

Two-step pipeline: integrate, then package. No additional strategy — both the integrator
(in the flow) and the solution builder (in the system) are already in place.

## 5. Summary

| Type                     | Kind         | Required methods                                       | `Base.show` |
|--------------------------|--------------|--------------------------------------------------------|-------------|
| `AbstractSystem`         | object       | `rhs!`, `dimensions`, `build_solution`                 | define      |
| `AbstractFlow`           | object       | `(flow)(t0, x0[, p0], tf)`, `system`, `integrator`     | define      |
| `MultiPhaseSystem`       | object       | inherits + `phases`, `switching`                       | define      |
| `MultiPhaseFlow`         | object       | inherits + `phases`, `switching`                       | define      |
| `AbstractFlowModeler`    | strategy     | CTSolvers contract + `(modeler)(input)`                | inherited   |
| `AbstractODEIntegrator`  | strategy     | CTSolvers contract + `(integrator)(prob, tspan)`       | inherited   |
| `AbstractADBackend`      | strategy     | CTSolvers contract + `ctgradient`, `ctjacobian`        | inherited   |

Pipeline functions on abstract types:

- `build_system(input, modeler, ad_backend) → AbstractSystem`
- `build_flow(system, integrator) → Flow` (and pipeline alias)
- `integrate(flow, t0, x0[, p0], tf) → trajectory`
- `build_solution(system, ode_sol) → Any`
- `solve(flow, tspan, x0[, p0]) → Any`

## 6. Next step

Use this specification to:

1. Define fake concrete types implementing each contract (one per abstract type).
2. Write tests that run each pipeline on the fakes and verify the calling convention,
   delegation order, and `NotImplemented` paths.
3. Once the test suite is green, replace the fakes incrementally with real implementations
   (`OpenLoopModeler`, `Tsit5Integrator`, `ForwardDiffBackend`, …) without changing the
   pipelines.
