# CTFlows Design v1: Objects, Single Strategy, Pipelines

This document specifies the revised architecture of CTFlows. It replaces the three v0 documents
(`design.md`, `candidate_strategies.md`, `strategies.md`) with a leaner, unified description
built around one key simplification: **a single strategy family**.

## 1. Overview

CTFlows organises its code along three concerns:

- **Objects** — `AbstractSystem`, `AbstractFlow`, `AbstractSolution`, and the config types
  `PointConfig` / `TrajectoryConfig`. They are *what* is acted upon or returned.
- **Single strategy family** — `AbstractODEIntegrator <: CTSolvers.Strategies.AbstractStrategy`.
  This is the only family. It controls *how* the Cauchy problem is solved.
- **Pipelines** — `build_system`, `build_flow`, `integrate`, `build_solution`, `solve`.
  Written on the abstract types; concrete implementations plug in without changing the pipeline.

### What changed from v0

| Concern | v0 | v1 |
| --- | --- | --- |
| System construction | `AbstractFlowModeler` (strategy) | Direct dispatch via `build_system` (no strategy) |
| AD backend | `AbstractADBackend` (strategy) | `DifferentiationInterface.jl` backend object (not a strategy) |
| ODE integration | `AbstractODEIntegrator` (strategy) | `AbstractODEIntegrator` (strategy) — unchanged |
| **Total families** | **3** | **1** |

Removing `AbstractFlowModeler` and `AbstractADBackend` from the strategy level reflects
the fact that system construction is determined entirely by the input type (Julia dispatch
is the right mechanism) and that AD configuration is best expressed as a plain
`DifferentiationInterface.jl` backend value, not as a CTSolvers strategy struct.

---

## 2. Config types

Config types carry the call-mode data and drive dispatch in `build_solution`. They are plain
structs, not strategies.

### `PointConfig`

```julia
struct PointConfig{T, X, P}
    t0::T
    x0::X
    p0::P   # nothing if no costate
    tf::T
end
```

Constructors:

- `PointConfig(t0, x0, tf)` — no costate (`p0 = nothing`)
- `PointConfig(t0, x0, p0, tf)` — with costate

**Semantics**: integrate from `t0` to `tf` starting at `x0` (and `p0` if present); return
only the **final values** `xf` (and `pf` if present).

### `TrajectoryConfig`

```julia
struct TrajectoryConfig{T, X, P}
    tspan::Tuple{T, T}
    x0::X
    p0::P   # nothing if no costate
end
```

Constructors:

- `TrajectoryConfig(tspan, x0)` — no costate
- `TrajectoryConfig(tspan, x0, p0)` — with costate

**Semantics**: integrate over the full time span; return a **solution object** containing
the trajectory (and possibly the costate) as functions of time.

---

## 3. Objects (non-strategy types)

### 3.1 `AbstractSystem`

The fully assembled object that can be integrated. It embeds its own `rhs!`, dimensional
metadata, and solution-building logic — assembled once at `build_system` time.

```julia
abstract type AbstractSystem end
```

**Required methods** (`NotImplemented` defaults):

```julia
rhs!(system::AbstractSystem)
    # Returns a closure (du, u, p, t) -> nothing filling du in place.

dimensions(system::AbstractSystem)
    # Returns a NamedTuple, e.g. (n_x=n,) for a vector field
    # or (n_x=n, n_p=n) for a Hamiltonian system.

build_solution(raw, flow::AbstractFlow, config::AbstractConfig)
    # Packages the raw integration result into the appropriate output
    # (final values or a solution object), depending on config type.
```

**Contract semantics**:

- `rhs!` returns a closure capturing whatever the system needs. Once obtained, the system
  has no further dependency on whatever produced it.
- `dimensions` is the canonical introspection point; used by the integrator to allocate
  and by the pipeline to verify compatibility.
- `build_solution` dispatches on `config` type: for `PointConfig` it extracts the final
  state (and costate); for `TrajectoryConfig` it wraps the full trajectory.

### 3.2 `AbstractFlow`

A callable object that pairs an `AbstractSystem` with an `AbstractODEIntegrator`. It
carries no business logic of its own; its job is to expose the integration protocol.

```julia
abstract type AbstractFlow end
```

**Required methods** (`NotImplemented` defaults):

```julia
(flow::AbstractFlow)(config)      # dispatch on PointConfig or TrajectoryConfig
system(flow::AbstractFlow)        # returns the embedded AbstractSystem
integrator(flow::AbstractFlow)    # returns the embedded AbstractODEIntegrator
```

**Concrete `Flow{S,I} <: AbstractFlow`** (provided by CTFlows):

```julia
struct Flow{S <: AbstractSystem, I <: AbstractODEIntegrator} <: AbstractFlow
    system::S
    integrator::I
end

system(f::Flow)     = f.system
integrator(f::Flow) = f.integrator

function (f::Flow)(config)
    r = integrate(f.system, config, f.integrator)
    return build_solution(r, f, config)
end
```

`build_flow` is the canonical constructor:

```julia
build_flow(system::AbstractSystem, integrator::AbstractODEIntegrator) = Flow(system, integrator)
```

### 3.3 `AbstractSolution`

Solution wrapper returned by a `TrajectoryConfig` call. Distinct from `CTModels.Solution`
(which is an OCP solution); `AbstractSolution` is CTFlows' own trajectory wrapper.

```julia
abstract type AbstractSolution end
```

**Required methods** (`NotImplemented` defaults):

```julia
state(sol::AbstractSolution)       # trajectory x(t) as a callable or array
time_grid(sol::AbstractSolution)   # time points
```

> **Note**: Phase 1 returns the raw `ODESolution` from SciML rather than a custom
> `AbstractSolution` subtype. The wrapper and its getters are deferred to a later phase.

---

## 4. Single strategy family: `AbstractODEIntegrator`

`AbstractODEIntegrator` is the **only** strategy family in CTFlows. It is
`<: CTSolvers.Strategies.AbstractStrategy` and therefore inherits the full CTSolvers
contract for free: `id`, `metadata`, `options`, `Base.show`, `describe`.

```julia
abstract type AbstractODEIntegrator <: CTSolvers.Strategies.AbstractStrategy end
```

**Business callable** (`NotImplemented` default):

```julia
function (integrator::AbstractODEIntegrator)(ode_problem)
    throw(NotImplemented(
        "AbstractODEIntegrator callable not implemented";
        required_method = "(integrator::$(typeof(integrator)))(ode_problem)",
        suggestion = "Implement (i::YourIntegrator)(prob) returning an ODE solution.",
        context = "AbstractODEIntegrator call - required method implementation",
    ))
end
```

The callable receives a fully assembled `ODEProblem` (or equivalent SciML object) and
returns a raw integration result (e.g. an `ODESolution`). It does not know about config
types or solution wrappers — that is `build_solution`'s job.

**Concrete strategies**: `SciMLIntegrator` (Phase 1, lives in `CTFlowsSciMLExt`) wraps
any SciML algorithm. Later phases may introduce per-algorithm strategies
(`Tsit5Integrator`, `Rodas4Integrator`, …) or GPU-parameterised variants.

**Candidate options** (Phase 1 subset):

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `alg` | Any | `Tsit5()` | ODE algorithm |
| `abstol` | Float64 | `1e-10` | Absolute tolerance |
| `reltol` | Float64 | `1e-10` | Relative tolerance |
| `maxiters` | Int | `10^5` | Maximum number of steps |
| `dt` | Float64 | — | Fixed step size (if non-adaptive) |
| `adaptive` | Bool | `true` | Adaptive step size control |
| `save_everystep` | Bool | `true` | Save at every solver step |
| `saveat` | Vector | `[]` | Save at specific times |

---

## 5. Automatic differentiation: not a strategy

AD in CTFlows is handled via [`DifferentiationInterface.jl`](https://juliadiff.org/DifferentiationInterface.jl/DifferentiationInterface/stable/).

**Key decisions**:

- `DifferentiationInterface` and `ForwardDiff` are **direct dependencies** of CTFlows.
- `AutoForwardDiff()` is the **default backend** — no `using ForwardDiff` required from the user.
- Users who want a different backend (e.g. `AutoZygote()`, `AutoEnzyme()`) pass it explicitly
  as the `ad_backend` argument to `build_system`.
- The `ad_backend` is a plain `DifferentiationInterface.jl` backend object — **not** a
  CTSolvers strategy. There is no `AbstractADBackend` family.

**Where it is used**:

- `VectorField` → no AD needed; `build_system(vf)` takes no `ad_backend`.
- `Hamiltonian` → AD needed to compute `∂H/∂x` and `∂H/∂p`:

  ```julia
  build_system(H)               # uses AutoForwardDiff() by default
  build_system(H, ad_backend)   # uses the given DI backend
  ```

- OCP with control law → same pattern as Hamiltonian.

**Internal usage**: CTFlows calls `DifferentiationInterface.gradient`, `.jacobian`, etc.
directly, passing the backend provided (or the default). The user never needs to call
these functions directly.

---

## 6. `build_system` — type dispatch, no strategy

System construction is handled by Julia's multiple dispatch on the input type. There is
no `AbstractFlowModeler` strategy; `build_system` dispatches on the concrete type of its
first argument.

```julia
# VectorField — no AD
build_system(vf::VectorField) → VectorFieldSystem

# Hamiltonian — AD with default backend
build_system(H::Hamiltonian) → HamiltonianSystem

# Hamiltonian — AD with explicit backend
build_system(H::Hamiltonian, ad_backend) → HamiltonianSystem

# OCP with control law — AD with default backend
build_system(ocp, u) → OCPSystem

# OCP with control law — AD with explicit backend
build_system(ocp, u, ad_backend) → OCPSystem
```

Each method constructs the appropriate `AbstractSystem` subtype, embedding the `rhs!`,
dimensional metadata, and the `build_solution` logic at construction time. After
`build_system`, the system is self-contained and the input object is no longer needed.

---

## 7. Pipelines

All pipeline functions are written on the abstract types declared in §3 and §4. Concrete
types plug in without modifying the pipeline.

### 7.1 `build_flow`

```julia
function build_flow(system::AbstractSystem, integrator::AbstractODEIntegrator)
    return Flow(system, integrator)
end
```

### 7.2 `integrate`

```julia
function integrate(system::AbstractSystem, config, integrator::AbstractODEIntegrator)
    prob = ode_problem(system, config)   # build ODEProblem from system + config
    return integrator(prob)              # integrator's business callable
end
```

`ode_problem` is an optional contract method on `AbstractSystem` used by SciML-based
integrators to extract a standard `ODEProblem`.

### 7.3 Flow callable and `build_solution`

```julia
function (flow::Flow)(config)
    r = integrate(system(flow), config, integrator(flow))
    return build_solution(r, flow, config)
end
```

`build_solution` dispatches on the config type:

```julia
# PointConfig — extract and return final values
function build_solution(raw, flow::AbstractFlow, config::PointConfig)
    # extract xf (and pf if config.p0 ≢ nothing) from raw
end

# TrajectoryConfig — wrap full trajectory
function build_solution(raw, flow::AbstractFlow, config::TrajectoryConfig)
    # return an AbstractSolution wrapping the raw ODESolution
end
```

### 7.4 `solve`

```julia
function solve(system::AbstractSystem, config, integrator::AbstractODEIntegrator)
    f = build_flow(system, integrator)
    return f(config)   # integrate + build_solution
end
```

> **Important**: `solve` operates on a **system** (not a flow). Calling a flow directly
> (`flow(config)`) is also valid and is the idiomatic form when the flow has already been
> built. There is **no `solve` method on `AbstractFlow`**.

---

## 8. Summary

### Types

| Type | Kind | Required methods |
| --- | --- | --- |
| `PointConfig` | object (config) | constructor |
| `TrajectoryConfig` | object (config) | constructor |
| `AbstractSystem` | object | `rhs!`, `dimensions`, `build_solution` |
| `AbstractFlow` | object | `(flow)(config)`, `system`, `integrator` |
| `AbstractSolution` | object | `state`, `time_grid` |
| `Flow{S,I}` | concrete object | provided by CTFlows |
| `AbstractODEIntegrator` | **strategy** | CTSolvers contract + `(integrator)(prob)` |

### Pipeline functions

| Function | Signature | Result |
| --- | --- | --- |
| `build_system` | `(object[, ad_backend])` | `AbstractSystem` |
| `build_flow` | `(system, integrator)` | `Flow` |
| `integrate` | `(system, config, integrator)` | raw result |
| `build_solution` | `(raw, flow, config)` | `xf[,pf]` or `AbstractSolution` |
| `solve` | `(system, config, integrator)` | `xf[,pf]` or `AbstractSolution` |
| `(flow)(config)` | callable | `xf[,pf]` or `AbstractSolution` |
