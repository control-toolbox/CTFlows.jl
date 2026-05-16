# Hamiltonian Type — Implementation Plan

## Context

CTFlows.jl currently supports two entry points for constructing Hamiltonian flows:

- `HamiltonianVectorField` — the user provides the vector field `(ẋ, ṗ) = F(t, x, p[, v])` directly.
- `HamiltonianSystem` — wraps a `HamiltonianVectorField` and pre-builds in-place and out-of-place RHS closures.
- `HamiltonianFlow` — wraps a `HamiltonianSystem` and an `AbstractIntegrator`.

The existing architecture is well-structured around three orthogonal traits (`TimeDependence`, `VariableDependence`, `AbstractMutabilityTrait`), a strategy pattern for integrators (`AbstractIntegrator <: CTSolvers.Strategies.AbstractStrategy`), and a clear module dependency graph (`Common → Data → Systems → Flows → Solutions → ext`).

However, there is no way today to provide a **scalar Hamiltonian function** `H(t, x, p[, v]) → ℝ` and have the vector field derived automatically via automatic differentiation. The user must compute `∂H/∂p` and `∂H/∂x` manually.

## Objectives

1. Add a `Hamiltonian` scalar type in `Data`, parallel to `HamiltonianVectorField`.
2. Add a `Differentiation` module with an `AbstractADBackend` strategy and its contract.
3. Add an `AbstractADTrait` in `Common` to encode whether a system carries an AD backend.
4. Add a second concrete Hamiltonian system type (`HamiltonianCachedSystem`) built from a `Hamiltonian` + backend, with RHS closures that use the AD backend and a runtime cache passed through `ODEParameters`.
5. Keep `HamiltonianFlow` structurally unchanged; route the cache preparation via a `_prepare_cache` internal function that dispatches on the AD trait.
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
Systems  (HamiltonianSystem [WithoutAD], HamiltonianCachedSystem [WithAD])
    ↓
Flows  (HamiltonianFlow, _prepare_cache dispatch, augment=true)
    ↓
Solutions
    ↓
ext/CTFlowsDifferentiationInterface  (concrete cache, gradient implementations)
ext/CTFlowsForwardDiff               (default backend resolution)
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

Export: `AbstractADTrait`, `WithAD`, `WithoutAD`, `AbstractCache`.

### Step 2 — `src/Common/ode_parameters.jl` (modified)

Extend `ODEParameters` with an optional cache field:

```julia
struct ODEParameters{V, C<:Union{AbstractCache, Nothing}}
    variable::V
    cache::C
end
```

Add a convenience constructor `ODEParameters(variable) = ODEParameters(variable, nothing)` to keep existing call sites unchanged.

### Step 3 — Test Checkpoint: Common traits and ODEParameters

- `@testset "Unit: WithAD / WithoutAD construction"` — trait values exist and are subtypes of `AbstractADTrait`
- `@testset "Unit: AbstractCache abstract type"` — cannot be instantiated
- `@testset "Unit: ODEParameters with cache"` — both constructors work, cache field accessible
- `@testset "Unit: ODEParameters backward compat"` — single-arg constructor gives `cache=nothing`
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
- Trait accessors `time_dependence`, `variable_dependence` implemented at abstract level.
- Internal helper `_oop_arity_h` for each trait combination (2, 3, 3, 4).
- Internal helper `_detect_td_vd_h` with `PreconditionError` for multiple methods, `IncorrectArgument` for invalid arity.
- Constructor `Hamiltonian(f; is_autonomous, is_variable)` with auto-detection.
- Natural call signatures: 4 combinations (Autonomous/NonAutonomous × Fixed/NonFixed).
- Uniform call signature `(t, x, p, v)` forwarding to the natural signature.
- `Base.show`.

### Step 5 — `src/Data/Data.jl` (modified)

- Add `include("hamiltonian.jl")` after `hamiltonian_vector_field.jl`.
- Export `AbstractHamiltonian`, `Hamiltonian`.

### Step 6 — Test Checkpoint: `Data.Hamiltonian`

- `@testset "Unit: Construction with all trait combinations"`
- `@testset "Unit: Auto-detection of traits from arity"`
- `@testset "Unit: Natural call signatures"` — all 4 combinations
- `@testset "Unit: Uniform call signature"` — (t, x, p, v) forwarding
- `@testset "Error: Multiple methods"` — `PreconditionError`
- `@testset "Error: Invalid arity"` — `IncorrectArgument`
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
# Returns (∂H/∂x, ∂H/∂p) — raw partial derivatives, not negated
# Negation (ṗ = -∂H/∂x) is the RHS's responsibility, not the backend's
function hamiltonian_gradient(backend::AbstractADBackend, h, t, x, p, v, cache=nothing)
    throw(NotImplemented(...))
end

# Returns ∂H/∂v — raw partial derivative, not negated
function variable_gradient(backend::AbstractADBackend, h, t, x, p, v, cache=nothing)
    throw(NotImplemented(...))
end

# Returns a concrete AbstractCache from typical values
function prepare_cache(backend::AbstractADBackend, h, typical_x, typical_p, typical_v)
    throw(NotImplemented(...))
end
```

Notes on the contract design:
- `cache` defaults to `nothing` so that calls without a prepared cache still work (simpler paths, or backends that do not support preparation).
- Gradients are returned **non-negated**; the RHS closures apply signs.
- `prepare_cache` returns a `Common.AbstractCache` subtype; the concrete type is extension-specific.

### Step 8 — `src/Differentiation/differentiation_interface.jl` (new file)

Concrete strategy wrapping DifferentiationInterface.jl backends:

```julia
struct DifferentiationInterface{O<:CTSolvers.Strategies.StrategyOptions} <: AbstractADBackend
    options::O
end
```

Implements `CTSolvers.Strategies.id`, `description`, `metadata` for the strategy contract.

### Step 9 — `src/Differentiation/building.jl` (new file)

```julia
function build_ad_backend(; kwargs...)
    return DifferentiationInterface(; kwargs...)
end
```

Parallel to `Integrators.build_integrator`.

### Step 10 — `src/Differentiation/Differentiation.jl` (new file)

Module manifest: imports, includes in order, exports.

Exports: `AbstractADBackend`, `DifferentiationInterface`, `build_ad_backend`, `hamiltonian_gradient`, `variable_gradient`, `prepare_cache`.

### Step 11 — `src/CTFlows.jl` (modified)

Add `include("Differentiation/Differentiation.jl")` and `using .Differentiation` after `Data`, before `Systems`.

### Step 12 — Test Checkpoint: `Differentiation` module

- `@testset "Unit: DifferentiationInterface construction"`
- `@testset "Unit: CTSolvers.Strategies contract"` — `id`, `description`, `metadata`
- `@testset "Unit: build_ad_backend"`
- `@testset "Error: hamiltonian_gradient stub throws NotImplemented"`
- `@testset "Error: variable_gradient stub throws NotImplemented"`
- `@testset "Error: prepare_cache stub throws NotImplemented"`
- `@testset "Exports"` — all names exported

---

## Phase 4 — `HamiltonianCachedSystem` in `Systems`

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

Update `HamiltonianSystem` parent type to `AbstractHamiltonianSystem{TD, VD, WithoutAD}`.

### Step 14 — `src/Systems/scalar_hamiltonian_system.jl` (new file)

The name `ScalarHamiltonianSystem` reflects the mathematical origin (a scalar function `H → ℝ`) rather than an implementation detail. This pairs cleanly with the existing `HamiltonianSystem` (from HVF) and `Data.Hamiltonian` (scalar) vs `Data.HamiltonianVectorField`.

```julia
struct ScalarHamiltonianSystem{
    N,
    F <: Function,
    TD <: Common.TimeDependence,
    VD <: Common.VariableDependence,
    BACKEND <: Differentiation.AbstractADBackend,
    RHS <: Function,
    OOPROHS <: Function,
    AUGRHS  # Function or Nothing
} <: AbstractHamiltonianSystem{TD, VD, WithAD}
    h::Data.Hamiltonian{F, TD, VD}
    backend::BACKEND
    rhs::RHS
    rhs_oop::OOPROHS
    rhs_augmented::AUGRHS   # Nothing when VD = Fixed
end
```

**RHS construction** — the RHS closures capture `h` and `backend`, and read `λ.cache` at each ODE step:

```julia
function _build_rhs_cached(h, backend, ::Val{N}) where N
    return function (du, u, λ, t)
        x, p  = _ham_split(u, N)
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, t, x, p, λ.variable, λ.cache)
        _ham_assign!(du, ∂p, -∂x, N)  # ẋ = ∂H/∂p, ṗ = -∂H/∂x
        return nothing
    end
end
```

**Augmented RHS** — built only when `VD = NonFixed`:

```julia
function _build_rhs_augmented(h, backend, ::Val{N}) where N
    return function (du, u, λ, t)
        x, p, pv = _aug_split(u, N)
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, t, x, p, λ.variable, λ.cache)
        ∂v     = Differentiation.variable_gradient(backend, h, t, x, p, λ.variable, λ.cache)
        _aug_assign!(du, ∂p, -∂x, -∂v, N)  # ṗv = -∂H/∂v
        return nothing
    end
end
```

Accessors `rhs`, `rhs_oop`, `rhs_augmented`, `state_dimension` follow the same pattern as `HamiltonianSystem`.

Constructors: with and without known dimension `n_state`.

### Step 15 — `src/Systems/building.jl` (modified)

Add factory functions for `ScalarHamiltonianSystem`:

```julia
function build_system(h::Data.AbstractHamiltonian, backend::Differentiation.AbstractADBackend)
    return ScalarHamiltonianSystem(h, backend)
end

function build_system(h::Data.AbstractHamiltonian, n_state::Int, backend::Differentiation.AbstractADBackend)
    return ScalarHamiltonianSystem(h, backend, n_state)
end
```

### Step 16 — `src/Systems/Systems.jl` (modified)

Add `include("scalar_hamiltonian_system.jl")`.

### Step 17 — Test Checkpoint: `ScalarHamiltonianSystem`

- `@testset "Unit: Construction with/without n_state"`
- `@testset "Unit: ad_trait returns WithAD"`
- `@testset "Unit: rhs_augmented is Nothing for Fixed"`
- `@testset "Unit: rhs_augmented is a Function for NonFixed"`
- `@testset "Unit: build_system factory functions"`
- `@testset "Type Stability"` — `@inferred` on constructors

---

## Phase 5 — Extension `CTFlowsDifferentiationInterface`

### Step 18 — `ext/CTFlowsDifferentiationInterface.jl` (new file)

Define concrete cache type:

```julia
struct DifferentiationInterfaceCache{PX, PP, PV} <: Common.AbstractCache
    prep_x::PX   # prepared gradient for ∂H/∂x
    prep_p::PP   # prepared gradient for ∂H/∂p
    prep_v::PV   # prepared gradient for ∂H/∂v (nothing if Fixed)
end
```

Implement `prepare_cache` using `DifferentiationInterface.prepare_gradient` with `Constant` contexts:

```julia
function Differentiation.prepare_cache(
    backend::Differentiation.DifferentiationInterface,
    h::Data.AbstractHamiltonian,
    typical_x, typical_p, typical_v
)
    di_backend = backend.options[:backend]  # e.g. AutoForwardDiff()
    typical_t  = zero(eltype(typical_x))
    prep_x = DI.prepare_gradient(h_x, di_backend, typical_x,
                 Constant(typical_p), Constant(typical_v), Constant(typical_t))
    prep_p = DI.prepare_gradient(h_p, di_backend, typical_p,
                 Constant(typical_x), Constant(typical_v), Constant(typical_t))
    prep_v = if typical_v !== nothing
        DI.prepare_gradient(h_v, di_backend, typical_v,
                 Constant(typical_x), Constant(typical_p), Constant(typical_t))
    else
        nothing
    end
    return DifferentiationInterfaceCache(prep_x, prep_p, prep_v)
end
```

Implement `hamiltonian_gradient` and `variable_gradient` using the prepared plans when cache is available, falling back to plain `DI.gradient` otherwise.

> **Note — `build_hamiltonian_vector_field` not included.** Converting a `Hamiltonian` to a `HamiltonianVectorField` via AD is a natural future utility but is not needed in this plan: the main path goes directly `Hamiltonian + backend → ScalarHamiltonianSystem`. This function can be added later in `Differentiation` as a public utility if a concrete use case arises (e.g. inspection, interoperability with other libraries).

### Step 19 — `ext/CTFlowsForwardDiff.jl` (modified)

Add default backend resolution — when ForwardDiff is loaded, the default AD backend is `AutoForwardDiff()`:

```julia
function Differentiation.__default_ad_backend()
    return AutoForwardDiff()
end
```

Parallel to `CTFlowsOrdinaryDiffEqTsit5` providing the default integrator algorithm.

### Step 20 — Test Checkpoint: Extension

- `@testset "Unit: DifferentiationInterfaceCache construction"`
- `@testset "Integration: prepare_cache with AutoForwardDiff()"` — correct preps
- `@testset "Integration: hamiltonian_gradient without cache"` — numerical verification
- `@testset "Integration: hamiltonian_gradient with cache"` — same result, faster path
- `@testset "Integration: variable_gradient"` — numerical verification
- `@testset "Integration: default backend via CTFlowsForwardDiff"`

---

## Phase 6 — Cache Preparation in `Flows`

### Step 21 — `src/Flows/calling.jl` (modified)

Add the internal `_prepare_cache` function that dispatches on the AD trait:

```julia
# WithoutAD: no preparation, returns nothing
function _prepare_cache(
    sys::Systems.AbstractHamiltonianSystem{TD, VD, Common.WithoutAD},
    config;
    variable
) where {TD, VD}
    return nothing
end

# WithAD: extract typical x0, p0 from config and delegate to backend
function _prepare_cache(
    sys::Systems.HamiltonianCachedSystem{N},
    config;
    variable
) where N
    u0     = Common.initial_condition(config)
    x0, p0 = Systems._ham_split(u0, N === nothing ? length(u0) ÷ 2 : N)
    return Differentiation.prepare_cache(sys.backend, sys.h, x0, p0, variable)
end
```

Unified `call` for all `HamiltonianFlow`s — a single implementation, no duplication:

```julia
function call(flow::Flows.HamiltonianFlow, config::Common.AbstractConfig; variable, unsafe)
    sys    = system(flow)
    int    = integrator(flow)
    cache  = _prepare_cache(sys, config; variable=variable)
    prob   = Integrators.build_problem(int, sys, config; variable=variable, cache=cache)
    opts   = Integrators.build_options(int, config)
    result = Integrators.solve_problem(int, prob, opts; unsafe=unsafe)
    return Solutions.build_solution(result, sys, config)
end
```

### Step 22 — `ext/CTFlowsSciML.jl` (modified)

`build_problem` accepts an optional `cache` keyword and passes it through `ODEParameters`:

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

### Step 23 — Test Checkpoint: Cache in call pipeline

- `@testset "Integration: HamiltonianSystem (WithoutAD) — cache is nothing"`
- `@testset "Integration: HamiltonianCachedSystem (WithAD) — cache prepared and used"`
- `@testset "Integration: p.cache accessible in RHS during solve"`
- `@testset "Regression: existing HamiltonianVectorField path unchanged"`

---

## Phase 7 — `augment=true` Support

### Step 24 — `src/Flows/calling.jl` (modified)

Add callable method on `HamiltonianFlow` with `augment` keyword:

```julia
function (f::HamiltonianFlow)(
    t0::Real, x0, p0, tf::Real;
    variable  = Common.__variable(),
    unsafe    = Common.__unsafe(),
    augment::Bool = false,
)
    if augment
        return call_augmented(f, Common.HamiltonianPointConfig(t0, x0, p0, tf);
                              variable=variable, unsafe=unsafe)
    else
        return call(f, Common.HamiltonianPointConfig(t0, x0, p0, tf);
                    variable=variable, unsafe=unsafe)
    end
end
```

Implement `call_augmented` — only valid for `HamiltonianCachedSystem` with `NonFixed`:

```julia
function call_augmented(
    flow::HamiltonianFlow{TD, NonFixed, S},
    config::Common.HamiltonianPointConfig;
    variable, unsafe
) where {TD, S<:Systems.HamiltonianCachedSystem}
    sys   = system(flow)
    int   = integrator(flow)
    cache = _prepare_cache(sys, config; variable=variable)

    # Augmented initial condition: [x0; p0; zeros(size(variable))]
    x0, p0 = config.x0, config.p0
    pv0    = zero_pv(variable)
    u0_aug = vcat(x0, p0, pv0)

    # Build augmented config and problem
    config_aug = Common.HamiltonianPointConfig(config.t0, u0_aug, config.tf)
    prob = Integrators.build_problem(int, sys, config_aug;
                                     variable=variable, cache=cache, augmented=true)
    opts   = Integrators.build_options(int, config)
    result = Integrators.solve_problem(int, prob, opts; unsafe=unsafe)

    return Solutions.build_augmented_solution(result, sys, config)
end
```

For invalid combinations, throw `IncorrectArgument` at call time with an explicit, actionable message:

```julia
# WithoutAD flow
throw(IncorrectArgument(
    "augment=true is not supported on this flow";
    reason  = "The flow was built from a HamiltonianVectorField, not a scalar Hamiltonian",
    suggestion = "Use Flow(h::Hamiltonian; ...) with a NonFixed variable dependence to enable augmented integration",
    context = "HamiltonianFlow call with augment=true",
))

# Fixed system
throw(IncorrectArgument(
    "augment=true requires a variable-dependent Hamiltonian";
    reason  = "The system has Fixed variable dependence — there is no variable v to differentiate against",
    suggestion = "Define your Hamiltonian with is_variable=true and pass variable= at call time",
    context = "HamiltonianFlow call with augment=true",
))
```

### Step 25 — `src/Solutions/building.jl` (modified)

Add `build_augmented_solution` that splits the final state `[xf; pf; pvf]`:

```julia
function build_augmented_solution(result, sys::ScalarHamiltonianSystem{N}, config) where N
    uf = Solutions.final_state(result)
    n  = N === nothing ? length(uf) ÷ 3 : N
    xf  = uf[1:n]
    pf  = uf[n+1:2n]
    pvf = uf[2n+1:end]
    return (xf, pf, pvf)
end
```

### Step 26 — Test Checkpoint: `augment=true`

- `@testset "Error: augment=true on WithoutAD flow"` — `IncorrectArgument`
- `@testset "Error: augment=true on Fixed system"` — `IncorrectArgument`
- `@testset "Integration: augment=true returns (xf, pf, pvf)"`
- `@testset "Integration: pvf = -∫ ∂H/∂v dt"` — numerical verification against finite differences
- `@testset "Regression: augment=false unchanged"`

---

## Phase 8 — High-Level `Flow(h::Hamiltonian; ...)` Constructor

### Step 27 — `src/Flows/building.jl` (modified)

```julia
function Flow(h::Data.AbstractHamiltonian; ad_backend=nothing, opts...)
    backend = _resolve_ad_backend(ad_backend)
    system  = Systems.build_system(h, backend)
    integ   = Integrators.build_integrator(; opts...)
    return build_flow(system, integ)
end

function Flow(h::Data.AbstractHamiltonian, n_state::Int; ad_backend=nothing, opts...)
    backend = _resolve_ad_backend(ad_backend)
    system  = Systems.build_system(h, n_state, backend)
    integ   = Integrators.build_integrator(; opts...)
    return build_flow(system, integ)
end
```

`_resolve_ad_backend` falls back to the default backend registered by `CTFlowsForwardDiff` when no backend is specified:

```julia
function _resolve_ad_backend(ad_backend)
    ad_backend !== nothing && return ad_backend
    default = Differentiation.__default_ad_backend()
    default === missing && throw(IncorrectArgument(
        "No AD backend available";
        suggestion = "Load ForwardDiff (or another supported backend) before calling Flow(h).",
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
- `src/Systems/scalar_hamiltonian_system.jl` — `HamiltonianCachedSystem`, all constructors and accessors
- `src/Systems/building.jl` — new `build_system` overloads
- `src/Flows/calling.jl` — `_prepare_cache`, `call_augmented`, `augment` parameter
- `src/Flows/building.jl` — `Flow(h::AbstractHamiltonian; ...)`
- `src/Solutions/building.jl` — `build_augmented_solution`
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
- `src/Systems/hamiltonian_cached_system.jl`
- `ext/CTFlowsDifferentiationInterface.jl`
- `test/suite/data/test_hamiltonian.jl`
- `test/suite/differentiation/test_ad_backend.jl`
- `test/suite/systems/test_scalar_hamiltonian_system.jl`
- `test/suite/flows/test_cache_pipeline.jl`
- `test/suite/flows/test_hamiltonian_augmented.jl`
- `test/suite/flows/test_flow_from_hamiltonian.jl`

### Modified
- `src/Common/abstract_trait.jl` — `AbstractADTrait`, `WithAD`, `WithoutAD`, `AbstractCache`
- `src/Common/ode_parameters.jl` — `cache` field in `ODEParameters`
- `src/Data/Data.jl` — include and export `Hamiltonian`
- `src/CTFlows.jl` — add `Differentiation` module
- `src/Systems/abstract_system.jl` — `AT` parameter on `AbstractHamiltonianSystem`
- `src/Systems/building.jl` — `build_system` overloads for `Hamiltonian`
- `src/Systems/Systems.jl` — include `hamiltonian_cached_system.jl`
- `src/Flows/calling.jl` — `_prepare_cache`, unified `call`, `call_augmented`
- `src/Flows/building.jl` — `Flow(h::AbstractHamiltonian; ...)`
- `src/Solutions/building.jl` — `build_augmented_solution`
- `ext/CTFlowsSciML.jl` — `cache` keyword in `build_problem`
- `ext/CTFlowsForwardDiff.jl` — `__default_ad_backend` registration

### Deleted
None.
