# Hamiltonian Type — Implementation Plan

## Context

CTFlows.jl (`develop` branch) currently supports two entry points for constructing Hamiltonian flows:

- `HamiltonianVectorField` — the user provides the vector field `(ẋ, ṗ) = F(t, x, p[, v])` directly.
- `HamiltonianVectorFieldSystem` — wraps a `HamiltonianVectorField` and pre-builds in-place and out-of-place RHS closures.
- `HamiltonianFlow` — wraps a `HamiltonianVectorFieldSystem` and an `AbstractIntegrator`.

The naming convention in `develop` is already consistent:

| `Data` | `Systems` |
|---|---|
| `VectorField` | `VectorFieldSystem` |
| `HamiltonianVectorField` | `HamiltonianVectorFieldSystem` |
| `Hamiltonian` *(new)* | `HamiltonianSystem` *(new)* |

There is no way today to provide a **scalar Hamiltonian function** `H(t, x, p[, v]) → ℝ` and have the vector field derived automatically via automatic differentiation. The user must compute `∂H/∂p` and `∂H/∂x` manually.

## Objectives

1. Add a `Hamiltonian` scalar type in `Data`, parallel to `HamiltonianVectorField`.
2. Add a `Differentiation` module with an `AbstractADBackend` strategy and its contract.
3. Add an `AbstractADTrait` in `Common` to encode whether a system carries an AD backend.
4. Add `HamiltonianSystem` built from a `Hamiltonian` + backend, with RHS closures that use the AD backend and a runtime cache passed through `ODEParameters`.
5. Keep `HamiltonianFlow` structurally unchanged; route cache preparation via a `prepare_cache` function using three-layer trait dispatch (`ad_trait`).
6. Support `augment=true` on point calls for `NonFixed` Hamiltonian flows, computing the variable costate `pv(tf) = -∫ ∂H/∂v dt` without zero dynamics.
7. Provide a high-level `Flow(h::Hamiltonian; ...)` constructor.

## Dependency Graph After Changes

```
Common  (traits incl. AbstractADTrait, AbstractCache, ODEParameters)
    ↓
Data  (Hamiltonian, HamiltonianVectorField, VectorField)
    ↓
Differentiation  (AbstractADBackend <: CTSolvers strategy, stubs)
    ↓
Systems  (HamiltonianVectorFieldSystem [WithoutAD], HamiltonianSystem [WithAD])
    ↓
Flows  (HamiltonianFlow, prepare_cache trait dispatch, augment=true)
    ↓
Solutions
    ↓
ext/CTFlowsDifferentiationInterface  (concrete cache, gradient implementations)
```

---

## Phase 1 — New Trait and Cache Foundation in `Common`

### Step 1 — `src/Common/abstract_trait.jl` (modified)

Add a new trait family for AD capability alongside the existing traits:

```julia
abstract type AbstractADTrait <: AbstractTrait end
struct WithAD    <: AbstractADTrait end  # system carries H + AD backend
struct WithoutAD <: AbstractADTrait end  # system carries HVF directly
```

Add `AbstractCache` as a common abstract type (parallel to `AbstractTag`, `AbstractTrait`):

```julia
abstract type AbstractCache end
```

Add a new content trait for augmented integration (used by `AugmentedHamiltonianPointConfig` — see Step 24a):

```julia
struct AugmentedHamiltonianTrait <: ContentTrait end
```

Export: `AbstractADTrait`, `WithAD`, `WithoutAD`, `AbstractCache`, `AugmentedHamiltonianTrait`.

### Step 2 — `src/Common/ode_parameters.jl` (modified)

Extend `ODEParameters` with an optional cache field:

```julia
struct ODEParameters{V, C<:Union{AbstractCache, Nothing}}
    variable::V
    cache::C
end
```

Add a convenience constructor `ODEParameters(variable) = ODEParameters(variable, nothing)` to keep all existing call sites unchanged.

Add a getter for the cache:

```julia
function cache(p::ODEParameters)
    return p.cache
end
```

### Step 3 — Test Checkpoint: Common traits and ODEParameters

- `@testset "Unit: WithAD / WithoutAD construction"` — subtypes of `AbstractADTrait`
- `@testset "Unit: AbstractCache abstract type"` — cannot be instantiated
- `@testset "Unit: ODEParameters with cache"` — both constructors work, cache field accessible
- `@testset "Unit: ODEParameters backward compat"` — single-arg constructor gives `cache=nothing`
- `@testset "Unit: AugmentedHamiltonianTrait construction"` — subtype of `ContentTrait`
- `@testset "Exports"` — all new names exported from `Common`

---

## Phase 2 — `Hamiltonian` Type in `Data`

### Step 4 — `src/Data/hamiltonian.jl` (new file)

Define a scalar Hamiltonian type, independent of `AbstractVectorField` (a Hamiltonian is not a vector field):

```julia
abstract type AbstractHamiltonian{
    TD <: Common.TimeDependence,
    VD <: Common.VariableDependence
} end

struct Hamiltonian{F<:Function, TD, VD} <: AbstractHamiltonian{TD, VD}
    f::F
end
```

- Out-of-place only (a scalar return has no meaningful in-place form).
- Trait accessors `time_dependence`, `variable_dependence` implemented at the abstract level.
- Constructor `Hamiltonian(f; is_autonomous, is_variable)` with Bool flags and defaults (no auto-detection).
  - Defaults from `Common.__is_autonomous()` and `Common.__is_variable()`.
- Natural call signatures: 4 combinations (Autonomous/NonAutonomous × Fixed/NonFixed).
- Uniform call signature `(t, x, p, v)` forwarding to the natural signature.
- `Base.show`.

### Step 5 — `src/Data/Data.jl` (modified)

- Add `include("hamiltonian.jl")` after `hamiltonian_vector_field.jl`.
- Export `AbstractHamiltonian`, `Hamiltonian`.

### Step 6 — Test Checkpoint: `Data.Hamiltonian`

- `@testset "Unit: Construction with all trait combinations"`
- `@testset "Unit: Natural call signatures"` — all 4 combinations
- `@testset "Unit: Uniform call signature (t, x, p, v)"` — all 4 combinations
- `@testset "Unit: Type stability"` — uniform call type stability
- `@testset "Exports"` — `AbstractHamiltonian`, `Hamiltonian` exported from `Data`

---

## Phase 3 — `Differentiation` Module and `AbstractADBackend`

### Step 7 — `src/Differentiation/abstract_ad_backend.jl` (new file)

On the exact model of `Integrators/abstract_integrator.jl`:

```julia
abstract type AbstractADBackend <: CTSolvers.Strategies.AbstractStrategy end
```

The contract is defined by three stubs (all throw `NotImplemented`):

```julia
# Returns (∂H/∂x, ∂H/∂p) — raw partial derivatives, not negated.
# The negation (ṗ = -∂H/∂x) is the RHS's responsibility, not the backend's.
function hamiltonian_gradient(backend::AbstractADBackend, h, t, x, p, v, cache=nothing)
    throw(NotImplemented(...))
end

# Returns ∂H/∂v — raw partial derivative, not negated.
function variable_gradient(backend::AbstractADBackend, h, t, x, p, v, cache=nothing)
    throw(NotImplemented(...))
end

# Returns a concrete AbstractCache built from typical values.
function prepare_cache(backend::AbstractADBackend, h, typical_x, typical_p, typical_v)
    throw(NotImplemented(...))
end
```

Design notes:

- `cache` defaults to `nothing` so calls without a prepared cache still work.
- Gradients are returned **non-negated**; the RHS closures apply the signs.
- `prepare_cache` returns a `Common.AbstractCache` subtype; the concrete type is extension-specific.

### Step 8 — `src/Differentiation/differentiation_interface.jl` (new file)

Concrete strategy wrapping DifferentiationInterface.jl backends:

```julia
struct DifferentiationInterface{O<:CTSolvers.Strategies.StrategyOptions} <: AbstractADBackend
    options::O
end
```

Implements `CTSolvers.Strategies.id`, `description`, `metadata` for the strategy contract.
`ADTypes` is a hard dependency (`[deps]`), so `AutoForwardDiff` is always available.
The `:backend` option definition uses `AutoForwardDiff()` directly as the default:

```julia
default = AutoForwardDiff()   # ADTypes.jl — always available (hard dep)
```

No tag/stub pattern needed — unlike `SciML` where the default algorithm (`Tsit5()`) comes
from a substantial optional package, `AutoForwardDiff()` is a zero-cost type from the
lightweight `ADTypes.jl` hard dep.

### Step 9 — `src/Differentiation/building.jl` (new file)

```julia
function build_ad_backend(; kwargs...)
    return DifferentiationInterface(; kwargs...)
end
```

Parallel to `Integrators.build_integrator`.

### Step 10 — `src/Differentiation/Differentiation.jl` (new file)

Module manifest: imports, includes in order, exports.

External imports include `using ADTypes: ADTypes` (hard dep — provides `AutoForwardDiff`).

Exports: `AbstractADBackend`, `DifferentiationInterface`, `build_ad_backend`,
`hamiltonian_gradient`, `variable_gradient`, `prepare_cache`.

### Step 11 — `src/CTFlows.jl` (modified)

Add `include("Differentiation/Differentiation.jl")` and `using .Differentiation` after `Data`, before `Systems`.

### Step 12 — Test Checkpoint: `Differentiation` module

- `@testset "Unit: DifferentiationInterface construction"` — `DifferentiationInterface()` works; default `:backend` is `AutoForwardDiff()`
- `@testset "Unit: CTSolvers.Strategies contract"` — `id`, `description`, `metadata`
- `@testset "Unit: build_ad_backend"`
- `@testset "Error: hamiltonian_gradient stub throws NotImplemented"`
- `@testset "Error: variable_gradient stub throws NotImplemented"`
- `@testset "Error: prepare_cache stub throws NotImplemented"`
- `@testset "Exports"` — all names exported

---

## Phase 4 — `HamiltonianSystem` in `Systems`

### Step 13 — `src/Systems/abstract_system.jl` (modified)

Add the AD trait parameter to the Hamiltonian system hierarchy:

```julia
abstract type AbstractHamiltonianSystem{
    TD <: Common.TimeDependence,
    VD <: Common.VariableDependence,
    AT <: Common.AbstractADTrait
} <: AbstractSystem{TD, VD} end
```

Add trait accessor:

```julia
Common.ad_trait(::AbstractHamiltonianSystem{TD, VD, AT}) where {TD, VD, AT} = AT
```

Update `HamiltonianVectorFieldSystem` parent type to `AbstractHamiltonianSystem{TD, VD, WithoutAD}`.

### Step 14 — `src/Systems/hamiltonian_system.jl` (new file)

`HamiltonianSystem` is the new type built from a scalar `Hamiltonian` and an AD backend.
It carries `WithAD` and pre-builds RHS closures that read `cache(λ)` at each ODE step.

```julia
struct HamiltonianSystem{
    N,
    F       <: Function,
    TD      <: Common.TimeDependence,
    VD      <: Common.VariableDependence,
    BACKEND <: Differentiation.AbstractADBackend,
    RHS     <: Function,
    OOPROHS <: Function,
} <: AbstractHamiltonianSystem{TD, VD, WithAD}
    h::Data.Hamiltonian{F, TD, VD}
    backend::BACKEND
    rhs::RHS
    rhs_oop::OOPROHS
end
```

**RHS construction** — captures `h` and `backend`; reads `cache(λ)` at each step:

```julia
function _build_rhs(h, backend, ::Val{N}) where N
    return function (du, u, λ, t)
        x, p   = _ham_split(u, N)
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, t, x, p, variable(λ), cache(λ))
        _ham_assign!(du, ∂p, -∂x, N)   # ẋ = ∂H/∂p,  ṗ = -∂H/∂x
        return nothing
    end
end
```

**Augmented RHS** — built lazily (not stored in the struct) using concrete dimensions
provided at integration time. This avoids the unresolvable split when `N = nothing`:

```julia
function build_rhs_augmented(sys::HamiltonianSystem, n_x::Int, n_v::Int)
    h, backend = sys.h, sys.backend
    return function (du, u, λ, t)
        x  = u[1:n_x]
        p  = u[n_x+1:2*n_x]
        pv = u[end-n_v+1:end]
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, t, x, p, variable(λ), cache(λ))
        ∂v      = Differentiation.variable_gradient(backend, h, t, x, p, variable(λ), cache(λ))
        du[1:n_x]              .= ∂p          # ẋ = ∂H/∂p
        du[n_x+1:2*n_x]        .= .-∂x        # ṗ = -∂H/∂x
        du[end-n_v+1:end]      .= .-∂v        # ṗv = -∂H/∂v
        return nothing
    end
end
```

`n_x` and `n_v` are closed over as concrete integers, so the split is always exact
regardless of whether `N` is `nothing` or a static value.

Accessors `rhs`, `rhs_oop`, `state_dimension` follow the same pattern as
`HamiltonianVectorFieldSystem`. `build_rhs_augmented(sys, n_x, n_v)` is the new entry point
for augmented integration — called from `build_problem` (Step 22), not from constructors.

### Step 15 — `src/Systems/building.jl` (modified)

Add factory functions for `HamiltonianSystem`:

```julia
function build_system(h::Data.AbstractHamiltonian, backend::Differentiation.AbstractADBackend)
    return HamiltonianSystem(h, backend)
end

function build_system(h::Data.AbstractHamiltonian, state_dimension::Int, backend::Differentiation.AbstractADBackend)
    return HamiltonianSystem(h, backend, state_dimension)
end
```

### Step 16 — `src/Systems/Systems.jl` (modified)

Add `include("hamiltonian_system.jl")`. Export `HamiltonianSystem`.

### Step 17 — Test Checkpoint: `HamiltonianSystem`

- `@testset "Unit: Construction with/without state_dimension"`
- `@testset "Unit: ad_trait returns WithAD"`
- `@testset "Unit: build_rhs_augmented returns correct closure"` — dimensions `n_x`, `n_v` respected
- `@testset "Unit: build_rhs_augmented raises on Fixed system"` — contract error
- `@testset "Unit: build_system factory functions"`
- `@testset "Type Stability"` — `@inferred` on constructors

---

## Phase 5 — Extension `CTFlowsDifferentiationInterface`

### Step 18 — `ext/CTFlowsDifferentiationInterface.jl` (new file)

Define the concrete cache type:

```julia
struct DifferentiationInterfaceCache{PX, PP, PV} <: Common.AbstractCache
    prep_x::PX   # prepared gradient for ∂H/∂x
    prep_p::PP   # prepared gradient for ∂H/∂p
    prep_v::PV   # prepared gradient for ∂H/∂v (nothing if Fixed)
end
```

Implement `prepare_cache` using `DI.prepare_gradient` with `Constant` contexts:

```julia
function Differentiation.prepare_cache(
    backend::Differentiation.DifferentiationInterface,
    h::Data.AbstractHamiltonian,
    typical_x, typical_p, typical_v
)
    di_backend = CTSolvers.Strategies.options(backend)[:backend]   # e.g. AutoForwardDiff()
    typical_t  = zero(eltype(typical_x))
    prep_x = DI.prepare_gradient(h_x, di_backend, typical_x,
                 Constant(typical_p), Constant(typical_v), Constant(typical_t))
    prep_p = DI.prepare_gradient(h_p, di_backend, typical_p,
                 Constant(typical_x), Constant(typical_v), Constant(typical_t))
    prep_v = typical_v !== nothing ?
        DI.prepare_gradient(h_v, di_backend, typical_v,
            Constant(typical_x), Constant(typical_p), Constant(typical_t)) : nothing
    return DifferentiationInterfaceCache(prep_x, prep_p, prep_v)
end
```

Implement `hamiltonian_gradient` and `variable_gradient` using the prepared plans when
a cache is available, falling back to plain `DI.gradient` otherwise.

> **Note — `build_hamiltonian_vector_field` not included.** Converting a `Hamiltonian`
> to a `HamiltonianVectorField` via AD is a natural future utility but is not on the
> critical path of this plan. It can be added later in `Differentiation` as a public
> utility if a concrete use case arises (e.g. inspection, interoperability).

### Step 19 — `Project.toml` (modified)

`ADTypes.jl` is added as a **hard dependency** (`[deps]`) — it is ultra-lightweight
(type definitions only, no computation) and ensures `AutoForwardDiff` is always
available in core without any extension.

`DifferentiationInterface.jl` is added as a **weak dependency** (`[weakdeps]`) to
trigger the `CTFlowsDifferentiationInterface` extension (gradient computation).

```toml
[deps]
# add:
ADTypes = "<uuid>"

[weakdeps]
# add:
DifferentiationInterface = "a0c0ee7d-e4b9-4e03-894e-1c5f64a51d63"

[extensions]
# add:
CTFlowsDifferentiationInterface = ["DifferentiationInterface"]

[compat]
# add:
ADTypes = "1"
DifferentiationInterface = "1"

[extras]
# add:
DifferentiationInterface = "a0c0ee7d-e4b9-4e03-894e-1c5f64a51d63"

[targets]
# add to test list:
"DifferentiationInterface"
```

`CTFlowsForwardDiff.jl` is **not modified** in this feature.

### Step 20 — Test Checkpoint: Extension

- `@testset "Unit: DifferentiationInterfaceCache construction"`
- `@testset "Integration: prepare_cache with AutoForwardDiff()"` — correct preps
- `@testset "Integration: hamiltonian_gradient without cache"` — numerical verification
- `@testset "Integration: hamiltonian_gradient with cache"` — same result, optimised path
- `@testset "Integration: variable_gradient"` — numerical verification
- `@testset "Integration: default backend via CTFlowsForwardDiff"`

---

## Phase 6 — Cache Preparation in `Flows`

### Step 21 — `src/Flows/calling.jl` (modified)

Add `prepare_cache` using a three-layer trait-dispatch pattern:

```julia
# Front-end: extract trait, delegate
function prepare_cache(
    sys::Systems.AbstractHamiltonianSystem,
    config::Common.AbstractConfig; variable
)
    return prepare_cache(Common.ad_trait(sys), sys, config; variable=variable)
end

# WithoutAD: no preparation needed
function prepare_cache(
    ::Type{Common.WithoutAD},
    sys::Systems.AbstractHamiltonianSystem,
    config::Common.AbstractConfig; variable
)
    return nothing
end

# WithAD: extract x0, p0 via getters and delegate to the backend
function prepare_cache(
    ::Type{Common.WithAD},
    sys::Systems.HamiltonianSystem,
    config::Common.AbstractConfig; variable
)
    x0 = Common.initial_state(config)
    p0 = Common.initial_costate(config)
    return Differentiation.prepare_cache(sys.backend, sys.h, x0, p0, variable)
end
```

`config` is typed as `AbstractConfig` (not restricted to `AbstractHamiltonianConfig`) so that
the same `prepare_cache` works when `call` is invoked with an `AugmentedHamiltonianPointConfig`
(which defines `initial_state` and `initial_costate` via its own getters — see Step 24a).

Unified `call` for all `HamiltonianFlow`s — a single implementation, no duplication:

```julia
function call(flow::Flows.HamiltonianFlow, config::Common.AbstractConfig; variable, unsafe)
    sys    = system(flow)
    int    = integrator(flow)
    cache  = prepare_cache(sys, config; variable=variable)
    prob   = Integrators.build_problem(int, sys, config; variable=variable, cache=cache)
    opts   = Integrators.build_options(int, config)
    result = Integrators.solve_problem(int, prob, opts; unsafe=unsafe)
    return Solutions.build_solution(result, sys, config)
end
```

### Step 22 — `ext/CTFlowsSciML/build_and_solve.jl` (modified)

The existing `build_problem` overload gains a `cache=nothing` keyword:

```julia
function Integrators.build_problem(integ::SciML, sys, config; variable, cache=nothing)
    u0 = Common.initial_condition(config)
    p  = Common.ODEParameters(variable, cache)
    if ismutable(u0)
        f! = Systems.rhs(sys)
        prob = ODEProblem(f!, u0, Common.tspan(config), p)
    else
        f = Systems.rhs_oop(sys, false)
        prob = ODEProblem(f, u0, Common.tspan(config), p)
    end
    return prob
end
```

A new overload dispatching on `AugmentedHamiltonianPointConfig` builds the augmented RHS
**lazily** using concrete dimensions from the config, which solves the split ambiguity when
`N = nothing`:

```julia
function Integrators.build_problem(
    integ::SciML,
    sys::Systems.HamiltonianSystem,
    config::Common.AugmentedHamiltonianPointConfig;
    variable, cache=nothing
)
    u0  = Common.initial_condition(config)              # vcat(x0, p0, pv0)
    p   = Common.ODEParameters(variable, cache)
    n_x = length(Common.initial_state(config))          # concrete at call time
    n_v = length(Common.initial_variable_costate(config))
    f!  = Systems.build_rhs_augmented(sys, n_x, n_v)   # lazy — closes over n_x, n_v
    return ODEProblem(f!, u0, Common.tspan(config), p)
end
```

Corresponding stub in `src/Integrators/abstract_integrator.jl` (throws `NotImplemented`).

### Step 23 — Test Checkpoint: Cache in call pipeline

- `@testset "Integration: HamiltonianVectorFieldSystem (WithoutAD) — cache is nothing"`
- `@testset "Integration: HamiltonianSystem (WithAD) — cache prepared and used"`
- `@testset "Integration: p.cache accessible in RHS during solve"`
- `@testset "Regression: existing HamiltonianVectorFieldSystem path unchanged"`

---

## Phase 7 — `augment=true` Support

### Step 24a — `src/Common/configs.jl` (modified)

Add a dedicated config type for augmented Hamiltonian integration. Using a proper config
avoids any `augmented=true` boolean on `build_problem` and lets the entire existing
`call` pipeline work unchanged via dispatch.

**New config struct:**

```julia
struct AugmentedHamiltonianPointConfig{T0<:Real, X0, P0, PV0, TF<:Real} <:
    AbstractConfigWithMaC{X0, PointTrait, AugmentedHamiltonianTrait}
    t0::T0
    x0::X0
    p0::P0
    pv0::PV0   # initial variable costate (zeros at start)
    tf::TF
end
```

`tspan` is inherited from `AbstractPointConfig` (`(c.t0, c.tf)`).

**Getters** (add to `configs.jl`):

```julia
function initial_condition(c::AugmentedHamiltonianPointConfig)
    return vcat(c.x0, c.p0, c.pv0)   # feeds build_problem directly
end

function initial_state(c::AugmentedHamiltonianPointConfig)
    return c.x0
end

function initial_costate(c::AugmentedHamiltonianPointConfig)
    return c.p0   # enables prepare_cache (WithAD) to work unchanged
end

function initial_variable_costate(c::AugmentedHamiltonianPointConfig)
    return c.pv0
end
```

Export: `AugmentedHamiltonianPointConfig`, `initial_variable_costate`.

### Step 24 — `src/Flows/calling.jl` (modified)

Add `augment` keyword to the `HamiltonianFlow` callable:

```julia
function (f::HamiltonianFlow)(
    t0::Real, x0, p0, tf::Real;
    variable  = Common.__variable(),
    unsafe    = Common.__unsafe(),
    augment::Bool = false,
)
    config = Common.HamiltonianPointConfig(t0, x0, p0, tf)
    augment && return call_augmented(f, config; variable=variable, unsafe=unsafe)
    return call(f, config; variable=variable, unsafe=unsafe)
end
```

Implement `call_augmented` using trait dispatch — a front-end extracts both
`ad_trait` and `variable_dependence`, then delegates:

```julia
# Front-end: extract both traits, delegate
function call_augmented(
    flow::HamiltonianFlow,
    config::Common.HamiltonianPointConfig; variable, unsafe
)
    sys = system(flow)
    return call_augmented(
        Common.ad_trait(sys),
        Common.variable_dependence(sys),
        flow, config; variable=variable, unsafe=unsafe
    )
end

# WithoutAD — any VD: clear message
function call_augmented(
    ::Type{Common.WithoutAD}, ::Type{<:Common.VariableDependence},
    flow::HamiltonianFlow, config::Common.HamiltonianPointConfig; variable, unsafe
)
    throw(IncorrectArgument(
        "augment=true is not supported on this flow";
        reason     = "The flow was built from a HamiltonianVectorField, not a scalar Hamiltonian",
        suggestion = "Use Flow(h::Hamiltonian; ...) with is_variable=true to enable augmented integration",
        context    = "HamiltonianFlow call with augment=true",
    ))
end

# Any AT — Fixed: clear message
function call_augmented(
    ::Type{<:Common.AbstractADTrait}, ::Type{Common.Fixed},
    flow::HamiltonianFlow, config::Common.HamiltonianPointConfig; variable, unsafe
)
    throw(IncorrectArgument(
        "augment=true requires a variable-dependent Hamiltonian";
        reason     = "The system has Fixed variable dependence — there is no v to differentiate against",
        suggestion = "Define your Hamiltonian with is_variable=true and pass variable= at call time",
        context    = "HamiltonianFlow call with augment=true",
    ))
end

# WithAD + NonFixed: valid path
function call_augmented(
    ::Type{Common.WithAD}, ::Type{Common.NonFixed},
    flow::HamiltonianFlow, config::Common.HamiltonianPointConfig; variable, unsafe
)
    sys    = system(flow)
    x0     = Common.initial_state(config)
    pv0    = zeros(eltype(x0), length(variable))
    config_aug = Common.AugmentedHamiltonianPointConfig(
        config.t0, x0, Common.initial_costate(config), pv0, config.tf
    )
    return call(flow, config_aug; variable=variable, unsafe=unsafe)
end
```

**Key simplification**: `call(flow, config_aug; ...)` reuses the existing pipeline unchanged:

- `prepare_cache` uses `initial_state`/`initial_costate` on `AugmentedHamiltonianPointConfig` ✓
- `build_problem` dispatches on `AugmentedHamiltonianPointConfig` → calls `build_rhs_augmented(sys, n_x, n_v)` ✓
- `build_solution` dispatches on `AugmentedHamiltonianTrait` → returns `(xf, pf, pvf)` ✓

### Step 25 — `src/Solutions/building.jl` (modified)

Add an internal split helper and a `build_solution` overload dispatching on
`AugmentedHamiltonianTrait`. Correct splitting uses `length(x0)` and `length(pv0)`
from the config getters — no dimension arithmetic that would break when `n_x ≠ n_v`.

**Split helper** (parallel to `_ham_split_solution`):

```julia
_aug_split_solution(u, x0::AbstractVector, pv0::AbstractVector) = (
    u[1:length(x0)],
    u[length(x0)+1:end-length(pv0)],
    u[end-length(pv0)+1:end],
)
```

**New `build_solution` overload** (dispatches via `AugmentedHamiltonianTrait`):

```julia
function build_solution(
    result::Integrators.AbstractIntegrationResult,
    sys::Systems.AbstractHamiltonianSystem,
    config::Common.AbstractPointConfig{X0, Common.AugmentedHamiltonianTrait}
) where {X0}
    u = Integrators.final_state(result)
    return _aug_split_solution(
        u,
        Common.initial_state(config),
        Common.initial_variable_costate(config),
    )
end
```

Returns `(xf, pf, pvf)`. `build_augmented_solution` from the original draft is **dropped**.

### Step 26 — Test Checkpoint: `augment=true`

- `@testset "Unit: AugmentedHamiltonianPointConfig construction"` — fields, `initial_condition`, getters
- `@testset "Unit: prepare_cache on AugmentedHamiltonianPointConfig"` — same result as on `HamiltonianPointConfig`
- `@testset "Error: augment=true on WithoutAD flow"` — `IncorrectArgument` with message
- `@testset "Error: augment=true on Fixed system"` — `IncorrectArgument` with message
- `@testset "Integration: augment=true returns (xf, pf, pvf)"`
- `@testset "Integration: pvf = -∫ ∂H/∂v dt"` — numerical verification against finite differences
- `@testset "Regression: augment=false unchanged"`

---

## Phase 8 — High-Level `Flow(h::Hamiltonian; ...)` Constructor

### Step 27 — `src/Flows/building.jl` (modified)

```julia
function Flow(h::Data.AbstractHamiltonian; ad_backend=nothing, opts...)
    backend = _resolve_ad_backend(ad_backend)
    sys     = Systems.build_system(h, backend)
    integ   = Integrators.build_integrator(; opts...)
    return build_flow(sys, integ)
end

function Flow(h::Data.AbstractHamiltonian, state_dimension::Int; ad_backend=nothing, opts...)
    backend = _resolve_ad_backend(ad_backend)
    sys     = Systems.build_system(h, state_dimension, backend)
    integ   = Integrators.build_integrator(; opts...)
    return build_flow(sys, integ)
end
```

`_resolve_ad_backend` falls back to the default registered by `CTFlowsForwardDiff`:

```julia
function _resolve_ad_backend(ad_backend)
    ad_backend !== nothing && return ad_backend
    default = Differentiation.__default_ad_backend()
    default === missing && throw(IncorrectArgument(
        "No AD backend available";
        suggestion = "Load ForwardDiff (or another supported backend) before calling Flow(h::Hamiltonian).",
    ))
    return Differentiation.build_ad_backend(; backend=default)
end
```

### Step 28 — Test Checkpoint: High-level constructor

- `@testset "Unit: Flow(H) with explicit backend"`
- `@testset "Unit: Flow(H, n) with dimension"`
- `@testset "Integration: Flow(H) → call — end-to-end"`
- `@testset "Integration: Flow(H) → augment=true — end-to-end"`
- `@testset "Integration: default backend when ForwardDiff loaded"`
- `@testset "Error: no backend available"` — clear message

---

## Phase 9 — Documentation

### Step 29 — Docstrings

Write docstrings for all new and modified public-facing items:

- `src/Data/hamiltonian.jl` — `AbstractHamiltonian`, `Hamiltonian`, constructor, call signatures
- `src/Common/abstract_trait.jl` — `AbstractADTrait`, `WithAD`, `WithoutAD`, `AbstractCache`
- `src/Common/ode_parameters.jl` — updated `ODEParameters` with cache field
- `src/Differentiation/abstract_ad_backend.jl` — `AbstractADBackend`, all three stubs
- `src/Differentiation/differentiation_interface.jl` — `DifferentiationInterface` strategy
- `src/Differentiation/building.jl` — `build_ad_backend`
- `src/Systems/hamiltonian_system.jl` — `HamiltonianSystem`, constructors, accessors
- `src/Systems/building.jl` — new `build_system` overloads
- `src/Common/configs.jl` — `AugmentedHamiltonianPointConfig`, `initial_variable_costate`
- `src/Flows/calling.jl` — `prepare_cache`, `call_augmented`, `augment` parameter
- `src/Flows/building.jl` — `Flow(h::AbstractHamiltonian; ...)`
- `src/Solutions/building.jl` — `_aug_split_solution`, `build_solution` augmented overload
- `ext/CTFlowsDifferentiationInterface.jl` — `DifferentiationInterfaceCache`, implementations

### Step 30 — Final Test Run

```bash
julia --project -e 'using Pkg; Pkg.test()' 2>&1 | tee /tmp/hamiltonian_feature.log
grep -E "Error|Fail|Test Summary" /tmp/hamiltonian_feature.log
```

Expected: all suites pass, zero failures, zero errors.

---

## Files Summary

### New
- `src/Data/hamiltonian.jl`
- `src/Differentiation/Differentiation.jl`
- `src/Differentiation/abstract_ad_backend.jl`
- `src/Differentiation/differentiation_interface.jl`
- `src/Differentiation/building.jl`
- `src/Systems/hamiltonian_system.jl`
- `ext/CTFlowsDifferentiationInterface.jl`
- `test/suite/data/test_hamiltonian.jl`
- `test/suite/differentiation/test_ad_backend.jl`
- `test/suite/systems/test_hamiltonian_system.jl`
- `test/suite/flows/test_cache_pipeline.jl`
- `test/suite/flows/test_hamiltonian_augmented.jl`
- `test/suite/flows/test_flow_from_hamiltonian.jl`

### Modified
- `src/Common/abstract_trait.jl` — `AbstractADTrait`, `WithAD`, `WithoutAD`, `AbstractCache`, `AugmentedHamiltonianTrait`
- `src/Common/ode_parameters.jl` — `cache` field in `ODEParameters`
- `src/Common/configs.jl` — `AugmentedHamiltonianPointConfig`, `initial_variable_costate` getter
- `src/Data/Data.jl` — include and export `Hamiltonian`
- `src/CTFlows.jl` — add `Differentiation` module
- `src/Systems/abstract_system.jl` — `AT` parameter on `AbstractHamiltonianSystem`
- `src/Systems/building.jl` — `build_system` overloads for `Hamiltonian`
- `src/Systems/Systems.jl` — include `hamiltonian_system.jl`
- `src/Flows/calling.jl` — `prepare_cache` (three-layer dispatch), unified `call`, `call_augmented` (trait dispatch)
- `src/Flows/building.jl` — `Flow(h::AbstractHamiltonian; ...)`
- `src/Solutions/building.jl` — `_aug_split_solution`, `build_solution` overload for `AugmentedHamiltonianTrait`
- `ext/CTFlowsSciML/build_and_solve.jl` — `cache` kwarg on `build_problem`; new overload for `AugmentedHamiltonianPointConfig`
- `Project.toml` — add `ADTypes` hard dep, `DifferentiationInterface` weakdep, `CTFlowsDifferentiationInterface` extension

### Deleted
None.
