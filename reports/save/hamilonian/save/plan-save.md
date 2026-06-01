<!-- File: /Users/ocots/.windsurf/plans/hamiltonian-type-feature-28b051 -->
# Hamiltonian Type Feature Implementation Plan

This plan adds a `Hamiltonian` type that wraps a scalar Hamiltonian function `H([t,], x, p[, v])` with traits (mutability, time dependence, variable dependence), enables automatic construction of `HamiltonianVectorField` via DifferentiationInterface.jl backends, supports manual `HamiltonianVectorField` specification, and provides augmented flow integration to compute variable costates without adding zero dynamics.

## What Changes and Why

**New types:**
- `Hamiltonian{F, TD, VD, MD}` in `Data` module - wrapper for scalar Hamiltonian functions
- `HamiltonianAugmentedPointConfig` and `HamiltonianAugmentedTrajectoryConfig` in `Common` - configs for augmented integration

**Modified types:**
- `HamiltonianSystem` - add optional `rhs_augmented` field and `hamiltonian_source` field to support augmented integration
- `HamiltonianFlow` callable methods - add `augment` keyword argument

**New functions:**
- `hamiltonian_vector_field(h::Hamiltonian, backend)` - converts Hamiltonian to HamiltonianVectorField via DifferentiationInterface
- `gradient_hamiltonian(backend, h, t, x, p, v)` - computes (∂H/∂p, -∂H/∂x) using DifferentiationInterface backends
- `gradient_hamiltonian_variable(backend, h, t, x, p, v)` - computes -∂H/∂v for augmented integration
- `build_system(h::Hamiltonian, backend)` - builds HamiltonianSystem from Hamiltonian
- `build_system(h::Hamiltonian, state_dimension::Int, backend)` - builds with known dimension
- `Flow(h::Hamiltonian; backend=AutoForwardDiff(), ...)` - high-level constructor for Hamiltonian flows
- `build_augmented_solution(result, sys, config)` - extracts (xf, pf, pvf) from augmented integration

**Why:**
- Provides user-friendly scalar Hamiltonian interface (H instead of manually writing vector field)
- Uses DifferentiationInterface.jl for unified AD backend support (ForwardDiff, Zygote, etc.)
- Enables augmented costate computation without inefficient zero-dynamics integration
- Maintains flexibility: users can provide either Hamiltonian (with AD) or direct HamiltonianVectorField

**What disappears:** None

## Dependency Graph After Changes

```
Common (traits, configs)
    ↓
Data (Hamiltonian, VectorField, HamiltonianVectorField)
    ↓
Differentiation (AbstractADBackend, gradient functions)
    ↓
Integrators (AbstractIntegrator)
    ↓
Systems (HamiltonianSystem with rhs_augmented)
    ↓
Flows (HamiltonianFlow with augment support)
    ↓
Solutions (augmented solution builders)
    ↓
Extensions (CTFlowsDifferentiationInterface, CTFlowsForwardDiff)
```

## Step 0 — Branch

```bash
git checkout develop && git pull
git checkout -b feature/hamiltonian-type
```

## Phase 1 — Core Hamiltonian Type

### Step 1 — `src/Data/hamiltonian.jl` (new file)

> 📋 Applying Architecture Rule — Single Responsibility: Hamiltonian type only wraps scalar functions with traits, no gradient logic
> 🏗️ Applying Modules Rule — Follow VectorField/HamiltonianVectorField pattern for consistency

- Define `abstract type AbstractHamiltonian{TD<:Common.TimeDependence, VD<:Common.VariableDependence, MD<:Common.AbstractMutabilityTrait} <: AbstractVectorField{TD, VD, MD}`
- Define `struct Hamiltonian{F<:Function, TD<:Common.TimeDependence, VD<:Common.VariableDependence, MD<:Common.AbstractMutabilityTrait} <: AbstractHamiltonian{TD, VD, MD}`
- Add field `f::F` - the scalar Hamiltonian function
- Implement internal helpers `_oop_arity_h` for each trait combination (2, 3, 3, 4)
- Implement `_detect_mutability_h` with PreconditionError for multiple methods, IncorrectArgument for invalid arity
- Implement constructor `Hamiltonian(f; is_autonomous, is_variable, is_inplace)` with auto-detection
- Implement 8 natural call signatures (OutOfPlace + InPlace × 4 trait combos)
  - For in-place signatures: `h!(du, t, x, p)` where `du` is a scalar buffer (size 1 mutable variable)
- Implement 4 uniform call signatures `(t, x, p, v)` that forward to natural signatures
- Implement `Base.show` methods

> ⛔ Do NOT write docstrings in this step. Leave TODO comments only.

### Step 2 — `src/Data/Data.jl` (modified)

> 🏗️ Applying Modules Rule — Add include and export in correct load order

- Add `include(joinpath(@__DIR__, "hamiltonian.jl"))` after `hamiltonian_vector_field.jl`
- Add `export AbstractHamiltonian, Hamiltonian` to exports list

### Step 3 — Test Checkpoint: Data.Hamiltonian

> 🧪 Applying Testing Rule — Define fake types at module top-level, separate unit/integration/error tests
> 🔬 Applying Type-Stability Rule — Test @inferred for constructors

- Create `test/suite/data/test_hamiltonian.jl`
- Define fake types for testing
- Test sections:
  - `@testset "Contract: NotImplemented errors"` - verify stubs throw correctly
  - `@testset "Unit: Construction with all trait combinations"` - test all 4×2 combos
  - `@testset "Unit: Mutability auto-detection"` - test arity detection
  - `@testset "Unit: Natural call signatures"` - test all 8 signatures
  - `@testset "Unit: Uniform call signatures"` - test (t, x, p, v) forwarding
  - `@testset "Error: Multiple methods"` - verify PreconditionError
  - `@testset "Error: Invalid arity"` - verify IncorrectArgument
  - `@testset "Type Stability"` - @inferred on constructors
  - `@testset "Exports"` - verify Hamiltonian is exported

Run tests:
```bash
julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["suite/data/test_hamiltonian"])' 2>&1 | tee /tmp/phase1.log
grep -E "Error|Fail|Test Summary" /tmp/phase1.log
```

## Phase 2 — AD Backend Strategy Pattern

### Step 4 — `src/Differentiation/Differentiation.jl` (new file)

> 🏗️ Applying Modules Rule — Module manifest following Integrators pattern

- Define module docstring
- Import external packages: `import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES`, `import CTSolvers.Strategies`
- Include files in order: `abstract_ad_backend.jl`, `differentiation_interface.jl`, `building.jl`
- Export: `AbstractADBackend, DifferentiationInterface, build_ad_backend, AbstractCache, ADCache, gradient_hamiltonian_x, gradient_hamiltonian_x!, gradient_hamiltonian_p, gradient_hamiltonian_p!, gradient_hamiltonian_v, gradient_hamiltonian_v!, prepare_cache`

> ⛔ Do NOT write docstrings in this step. Leave TODO comments only.

### Step 5 — `src/Differentiation/abstract_ad_backend.jl` (new file)

> 📋 Applying Architecture Rule — Abstract type defines AD backend strategy contract with separated gradients and cache preparation
> 🏗️ Applying Modules Rule — Follow Integrators/abstract_integrator.jl pattern with stubs on abstract type

- Define `abstract type AbstractADBackend <: CTSolvers.Strategies.AbstractStrategy end`
- Define `struct DifferentiationInterfaceTag <: Common.AbstractTag end`
- Define `abstract type AbstractCache end`
- Define `struct ADCache{PX, PP, PV} <: AbstractCache` with fields `prep_x::PX`, `prep_p::PP`, `prep_v::PV`
- Implement `function __default_ad_backend(::Type{<:Common.AbstractTag})` returning missing (for default backend resolution)
- **Contract stubs (all throw NotImplemented):**
  - `gradient_hamiltonian_x(ad::AbstractADBackend, h::Data.AbstractHamiltonian, t, x, p, v)` → returns ∂H/∂x
  - `gradient_hamiltonian_x!(grad_x, ad::AbstractADBackend, h::Data.AbstractHamiltonian, t, x, p, v)` → in-place ∂H/∂x
  - `gradient_hamiltonian_p(ad::AbstractADBackend, h::Data.AbstractHamiltonian, t, x, p, v)` → returns ∂H/∂p
  - `gradient_hamiltonian_p!(grad_p, ad::AbstractADBackend, h::Data.AbstractHamiltonian, t, x, p, v)` → in-place ∂H/∂p
  - `gradient_hamiltonian_v(ad::AbstractADBackend, h::Data.AbstractHamiltonian, t, x, p, v)` → returns ∂H/∂v
  - `gradient_hamiltonian_v!(grad_v, ad::AbstractADBackend, h::Data.AbstractHamiltonian, t, x, p, v)` → in-place ∂H/∂v
  - `prepare_cache(ad::AbstractADBackend, h::Data.AbstractHamiltonian, typical_x, typical_p, typical_v)` → returns ADCache
- Note: Contract does NOT know about Constant context types (extension detail)
- Note: Gradients are SEPARATED by variable (x, p, v), not combined

> ⛔ Do NOT write docstrings in this step. Leave TODO comments only.

### Step 6 — `src/Differentiation/differentiation_interface.jl` (new file)

> 📋 Applying Architecture Rule — Concrete DifferentiationInterface strategy wraps DifferentiationInterface.jl backends
> 🏗️ Applying Modules Rule — Follow Integrators/sciml.jl pattern

- Define `struct DifferentiationInterface{O<:CTSolvers.Strategies.StrategyOptions} <: AbstractADBackend` with field `options::O`
- Implement `CTSolvers.Strategies.id(::Type{<:DifferentiationInterface}) = :di`
- Implement `CTSolvers.Strategies.description(::Type{<:DifferentiationInterface})`
- Implement `CTSolvers.Strategies.metadata(::Type{<:DifferentiationInterface})` with options (backend, prepare)

> ⛔ Do NOT write docstrings in this step. Leave TODO comments only.

### Step 7 — `src/Differentiation/building.jl` (new file)

> 📋 Applying Architecture Rule — Builder function constructs AD backend strategy from user options
> 🏗️ Applying Modules Rule — Follow Integrators/building.jl pattern

- Implement `function build_ad_backend(ad_backend)` that constructs DifferentiationInterface strategy from backend option
  - If ad_backend is already an AbstractADBackend, return it
  - If ad_backend is a DifferentiationInterface backend (e.g., AutoForwardDiff()), wrap it in DifferentiationInterface strategy
  - If ad_backend is missing or nothing, use default DifferentiationInterface() which resolves via __default_ad_backend

> ⛔ Do NOT write docstrings in this step. Leave TODO comments only.

### Step 8 — `src/CTFlows.jl` (modified)

> 🏗️ Applying Modules Rule — Add Differentiation module to load order

- Add `include(joinpath(@__DIR__, "Differentiation", "Differentiation.jl"))` after Data, before Integrators
- Add `using .Differentiation`

### Step 9 — `ext/CTFlowsDifferentiationInterface.jl` (new file)

> 🏗️ Applying Modules Rule — Extension implements AD strategy with separated gradients and Constant contexts (extension detail)

- Check for DifferentiationInterface availability with `@require DifferentiationInterface`
- Implement `gradient_hamiltonian_x(ad::DifferentiationInterface, h::Data.AbstractHamiltonian{..., OutOfPlace}, t, x, p, v, cache::Union{ADCache, Nothing}=nothing)`
  - If cache provided and cache.prep_x not nothing: `gradient(h_x, cache.prep_x, ad, x, Constant(p), Constant(v), Constant(t))`
  - Otherwise: `gradient(h_x, ad, x, Constant(p), Constant(v), Constant(t))` where `h_x(x, p, v, t) = h(t, x, p, v)`
  - Returns ∂H/∂x
- Implement `gradient_hamiltonian_x!(grad_x, ad::DifferentiationInterface, h::Data.AbstractHamiltonian{..., InPlace}, t, x, p, v, cache::Union{ADCache, Nothing}=nothing)`
  - Similar to OutOfPlace but in-place with gradient!
- Implement `gradient_hamiltonian_p(ad::DifferentiationInterface, h::Data.AbstractHamiltonian{..., OutOfPlace}, t, x, p, v, cache::Union{ADCache, Nothing}=nothing)`
  - If cache provided and cache.prep_p not nothing: `gradient(h_p, cache.prep_p, ad, p, Constant(x), Constant(v), Constant(t))`
  - Otherwise: `gradient(h_p, ad, p, Constant(x), Constant(v), Constant(t))` where `h_p(p, x, v, t) = h(t, x, p, v)`
  - Returns ∂H/∂p
- Implement `gradient_hamiltonian_p!(grad_p, ad::DifferentiationInterface, h::Data.AbstractHamiltonian{..., InPlace}, t, x, p, v, cache::Union{ADCache, Nothing}=nothing)`
  - Similar in-place version
- Implement `gradient_hamiltonian_v(ad::DifferentiationInterface, h::Data.AbstractHamiltonian{..., OutOfPlace}, t, x, p, v, cache::Union{ADCache, Nothing}=nothing)`
  - If cache provided and cache.prep_v not nothing: `gradient(h_v, cache.prep_v, ad, v, Constant(x), Constant(p), Constant(t))`
  - Otherwise: `gradient(h_v, ad, v, Constant(x), Constant(p), Constant(t))` where `h_v(v, x, p, t) = h(t, x, p, v)`
  - Returns ∂H/∂v
- Implement `gradient_hamiltonian_v!(grad_v, ad::DifferentiationInterface, h::Data.AbstractHamiltonian{..., InPlace}, t, x, p, v, cache::Union{ADCache, Nothing}=nothing)`
  - Similar in-place version
- Implement `prepare_cache(ad::DifferentiationInterface, h::Data.AbstractHamiltonian, typical_x, typical_p, typical_v)`
  - Use `prepare_gradient` with Constant contexts for inactive arguments
  - For ∂H/∂x: `prepare_gradient(h_x, ad, typical_x, Constant(typical_p), Constant(typical_v), Constant(t))` → prep_x
  - For ∂H/∂p: `prepare_gradient(h_p, ad, typical_p, Constant(typical_x), Constant(typical_v), Constant(t))` → prep_p
  - For ∂H/∂v: `prepare_gradient(h_v, ad, typical_v, Constant(typical_x), Constant(typical_p), Constant(t))` → prep_v
  - Return `ADCache(prep_x, prep_p, prep_v)`

> ⛔ Do NOT write docstrings in this step. Leave TODO comments only.

### Step 10 — `ext/CTFlowsForwardDiff.jl` (modified)

> 🏗️ Applying Modules Rule — Existing extension adds default backend resolution

- Add `function __default_ad_backend(::Type{DifferentiationInterfaceTag})` returning AutoForwardDiff()
- This provides the default AD backend when ForwardDiff is loaded (like CTFlowsOrdinaryDiffEqTsit5 provides default Tsit5 algorithm)

> ⛔ Do NOT write docstrings in this step. Leave TODO comments only.

### Step 11 — Test Checkpoint: AD Backend Strategy

> 🧪 Applying Testing Rule - Test strategy contract and extension pattern

- Create `test/suite/differentiation/test_ad_backend.jl`
- Test sections:
  - `@testset "Contract: CTSolvers.Strategies methods"` - id, description, metadata
  - `@testset "Unit: DifferentiationInterface construction"` - with options
  - `@testset "Unit: build_ad_backend"` - wrapping raw backends, returning existing strategies
  - `@testset "Error: NotImplemented without extension"` - stub throws correctly
  - `@testset "Integration: gradient_hamiltonian_x with DifferentiationInterface"` - numerical verification
  - `@testset "Integration: gradient_hamiltonian_p with DifferentiationInterface"` - numerical verification
  - `@testset "Integration: gradient_hamiltonian_v with DifferentiationInterface"` - numerical verification
  - `@testset "Integration: prepare_cache with DifferentiationInterface"` - cache creations AutoForwardDiff()
  - `@testset "Exports"` - verify AD backend types and functions exported

Run tests:
```bash
julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["suite/differentiation/test_ad_backend"])' 2>&1 | tee /tmp/phase2.log
grep -E "Error|Fail|Test Summary" /tmp/phase2.log
```

## Phase 3 — Hamiltonian to VectorField Conversion (in Differentiation module)

### Step 12 — `src/Differentiation/Differentiation.jl` (modified)

> 🏗️ Applying Modules Rule — Add include for conversion file

- Add `include(joinpath(@__DIR__, "conversions.jl"))` after `building.jl`
- Add `export build_hamiltonian_vector_field, hamiltonian_vector_field` to exports list

> ⛔ Do NOT write docstrings in this step. Leave TODO comments only.

### Step 13 — `src/Differentiation/conversions.jl` (new file)

> 📋 Applying Architecture Rule — Generic conversion functions use AD backend contract to build HamiltonianVectorField
> 🏗️ Applying Modules Rule — Moved from Data to Differentiation to respect dependency order

- Implement `function build_hamiltonian_vector_field(h::Data.AbstractHamiltonian{..., OutOfPlace}, ad::AbstractADBackend, cache::Union{ADCache, Nothing}=nothing)`
  - Call `gradient_hamiltonian_x(ad, h, t, x, p, v, cache)` for ∂H/∂x
  - Call `gradient_hamiltonian_p(ad, h, t, x, p, v, cache)` for ∂H/∂p
  - Return `HamiltonianVectorField{..., OutOfPlace}` with function `(t, x, p, v) -> (-gradient_hamiltonian_x(...), gradient_hamiltonian_p(...))`
- Implement `function build_hamiltonian_vector_field(h::Data.AbstractHamiltonian{..., InPlace}, ad::AbstractADBackend, cache::Union{ADCache, Nothing}=nothing)`
  - Similar to OutOfPlace but with in-place gradient calls
  - Return `HamiltonianVectorField{..., InPlace}` with in-place gradient calls
- Implement user-friendly wrapper `function hamiltonian_vector_field(h::Data.AbstractHamiltonian; ad_backend=nothing, cache=nothing)`
  - Build AD backend from ad_backend option using `build_ad_backend(ad_backend)`
  - Call internal `build_hamiltonian_vector_field(h, ad, cache)`
  - Returns HamiltonianVectorField
- Note: This is internal API, analogous to `build_flow(system, integrator)`
- Note: cache argument defaults to nothing, can be provided if pre-computed

> ⛔ Do NOT write docstrings in this step. Leave TODO comments only.

### Step 14 — Test Checkpoint: Hamiltonian Conversions

> 🧪 Applying Testing Rule - Test conversion from Hamiltonian to HamiltonianVectorField using AD backend contract

- Create `test/suite/differentiation/test_hamiltonian_conversions.jl`
- Test sections:
  - `@testset "Unit: build_hamiltonian_vector_field (OutOfPlace)"` - returns OutOfPlace HamiltonianVectorField
  - `@testset "Unit: build_hamiltonian_vector_field (InPlace)"` - returns InPlace HamiltonianVectorField
  - `@testset "Unit: hamiltonian_vector_field user-friendly wrapper"` - with ad_backend kwarg
  - `@testset "Integration: H -> Hv -> call (OutOfPlace)"` - end-to-end with simple Hamiltonian
  - `@testset "Integration: H -> Hv -> call (InPlace)"` - end-to-end with in-place Hamiltonian
  - `@testset "Integration: Separated gradients correctness"` - verify ∂H/∂x and ∂H/∂p separately
  - `@testset "Integration: Cache usage"` - verify cache passed through to gradient calls
  - `@testset "Integration: Multiple backends"` - test with DifferentiationInterface

Run tests:
```bash
julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["suite/differentiation/test_hamiltonian_conversions"])' 2>&1 | tee /tmp/phase3.log
grep -E "Error|Fail|Test Summary" /tmp/phase3.log
```

## Phase 4 — HamiltonianSystem Cache Field

### Step 16 — `src/Systems/hamiltonian_system.jl` (modified)

> 📋 Applying Architecture Rule — Add cache field for gradient preparation (Systems decoupled from AD)
> 🏗️ Applying Modules Rule — Add new type parameter at end for type stability

- Add type parameter `CACHE` to `HamiltonianSystem` struct definition (after FINRHS)
- Add field `cache::CACHE` (opaque cache object containing prep_x, prep_p, prep_v, can be Nothing)
- Modify all 4 constructors to accept `cache=nothing`
- Update `Base.show` to display cache status

> ⛔ Do NOT write docstrings in this step. Leave existing docstrings untouched.

### Step 17 — Test Checkpoint: HamiltonianSystem Cache Field

> 🧪 Applying Testing Rule - Test cache field construction

- Create `test/suite/systems/test_hamiltonian_system_cache.jl`
- Test sections:
  - `@testset "Unit: HamiltonianSystem with cache=nothing"` - default construction
  - `@testset "Unit: HamiltonianSystem with cache object"` - with opaque cache
  - `@testset "Type Stability"` - verify CACHE parameter is type-stable

Run tests:
```bash
julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["suite/systems/test_hamiltonian_system_cache"])' 2>&1 | tee /tmp/phase4.log
grep -E "Error|Fail|Test Summary" /tmp/phase4.log
```

## Phase 5 — Hamiltonian to System (without augmentation)

### Step 18 — `src/Systems/building.jl` (modified)

> 📋 Applying Architecture Rule — Build system from Hamiltonian with AD backend (cache=nothing initially)
> 🏗️ Applying Modules Rule — Factory functions follow existing build_system pattern

- Add `function build_system(h::Data.Hamiltonian, ad::Differentiation.AbstractADBackend)`
  - Call `build_hamiltonian_vector_field(h, ad)` to get HamiltonianVectorField
  - Call `HamiltonianSystem(hvf)` with `cache=nothing`
  - Return HamiltonianSystem
- Add `function build_system(h::Data.Hamiltonian, state_dimension::Int, ad::Differentiation.AbstractADBackend)`
  - Call `build_hamiltonian_vector_field(h, ad)` to get HamiltonianVectorField
  - Call `HamiltonianSystem(hvf, state_dimension)` with `cache=nothing`
  - Return HamiltonianSystem

> ⛔ Do NOT write docstrings in this step. Leave TODO comments only.

### Step 19 — Test Checkpoint: Hamiltonian to System

> 🧪 Applying Testing Rule - Test Hamiltonian -> System conversion

- Create `test/suite/systems/test_hamiltonian_to_system.jl`
- Test sections:
  - `@testset "Unit: build_system from Hamiltonian"` - with and without state_dimension
  - `@testset "Integration: H -> Hv -> System"` - end-to-end with simple Hamiltonian
  - `@testset "Integration: H -> System -> RHS"` - verify RHS works without cache

Run tests:
```bash
julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["suite/systems/test_hamiltonian_to_system"])' 2>&1 | tee /tmp/phase5.log
grep -E "Error|Fail|Test Summary" /tmp/phase5.log
```

## Phase 6 — Cache Preparation in Call Pipeline

### Step 20 — `src/Differentiation/preparation.jl` (new file)

> 📋 Applying Architecture Rule — prepare_cache creates ADCache with prep_x, prep_p, prep_v for gradient optimization
> 🏗️ Applying Modules Rule — Two surcharges: from Hamiltonian and from System

- Implement `function prepare_cache(h::Data.AbstractHamiltonian, ad::AbstractADBackend, typical_x, typical_p, typical_v)`
  - Calls contract method `prepare_cache(ad, h, typical_x, typical_p, typical_v)`
  - Returns ADCache
- Implement `function prepare_cache(sys::Systems.HamiltonianSystem, ad::AbstractADBackend, config::Common.AbstractConfig; variable)`
  - Extract `typical_x`, `typical_p` from config initial conditions
  - Extract `typical_v` from config variable if NonFixed
  - Extract `h` from `sys.hvf` (the original Hamiltonian)
  - Call `prepare_cache(h, ad, typical_x, typical_p, typical_v)`
  - Returns ADCache
- Note: These functions are internal, used by Flows.call pipeline
- Note: Contract method is implemented in extension (e.g., CTFlowsDifferentiationInterface)
- Note: Extension uses Constant contexts for inactive arguments during preparation (extension detail)

> ⛔ Do NOT write docstrings in this step. Leave TODO comments only.

### Step 21 — `src/Differentiation/Differentiation.jl` (modified)

> 🏗️ Applying Modules Rule — Add include for preparation

- Add `include(joinpath(@__DIR__, "preparation.jl"))` after `conversions.jl`
- Add `export prepare_cache` to exports list (already exported from abstract_ad_backend.jl)

### Step 22 — `src/Flows/flow.jl` (modified)

> 📋 Applying Architecture Rule — HamiltonianFlow stores AD backend for cache preparation

- Add field `ad_backend::Union{Differentiation.AbstractADBackend, Nothing}` to `HamiltonianFlow` struct
- Modify `HamiltonianFlow` constructors to accept optional `ad_backend=nothing`
- Update `Base.show` to display AD backend status

> ⛔ Do NOT write docstrings in this step. Leave existing docstrings untouched.

### Step 23 — `src/Flows/calling.jl` (modified)

> 📋 Applying Architecture Rule — Prepare cache in call pipeline when AD backend present

- Modify `call` function for HamiltonianFlow to add cache preparation:
  ```julia
  function call(flow::HamiltonianFlow, config::Common.AbstractConfig; variable, unsafe)
      sys = system(flow)
      int = integrator(flow)
      ad = ad_backend(flow)
      
      # Prepare cache if AD backend present
      cache = !isnothing(ad) ? Differentiation.prepare_cache(sys, ad, config; variable=variable) : nothing
      
      # Build problem with cache in parameters
      prob = Integrators.build_problem(int, sys, config; variable=variable, cache=cache)
      opts = Integrators.build_options(int, config)
      result = Integrators.solve_problem(int, prob, opts; unsafe=unsafe)
      flow_sol = Solutions.build_solution(result, config)
      return flow_sol
  end
  ```

> ⛔ Do NOT write docstrings in this step. Leave TODO comments only.

### Step 24 — `src/Systems/hamiltonian_system.jl` (modified)

> 📋 Applying Architecture Rule — RHS functions use ADCache with separated gradients when available
> 🏗️ Applying Modules Rule — Modify _build_rhs to check cache and use gradient with prep

- Modify `_build_rhs` for OutOfPlace to check `λ.cache`:
  - If `!isnothing(λ.cache)`: use `gradient_hamiltonian_x(ad, h, t, x, p, v, λ.cache)` and similarly for ∂H/∂p
  - If `isnothing(λ.cache)`: use gradient without cache (fallback)
- Modify `_build_rhs` for InPlace similarly
- Modify `_build_oop_rhs` similarly for out-of-place versions
- Note: Cache is ADCache with prep_x, prep_p, prep_v fields
- Note: RHS uses separated gradient methods (gradient_hamiltonian_x, gradient_hamiltonian_p)

> ⛔ Do NOT write docstrings in this step. Leave TODO comments only.

### Step 25 — `ext/CTFlowsSciML.jl` (modified)

> 🏗️ Applying Modules Rule — Pass ADCache through ODE parameters

- Modify `ODEParameters` struct to include `cache::Union{Differentiation.ADCache, Nothing}` field
- Modify `ode_problem` construction to accept and pass `cache` parameter
- Ensure cache is accessible in RHS via `p.cache`

> ⛔ Do NOT write docstrings in this step. Leave TODO comments only.

### Step 26 — Test Checkpoint: Cache Preparation Pipeline

> 🧪 Applying Testing Rule - Test cache preparation with ADCache and usage in call pipeline

- Create `test/suite/differentiation/test_cache_preparation.jl`
- Test sections:
  - `@testset "Unit: prepare_cache from Hamiltonian"` - verify ADCache structure
  - `@testset "Unit: prepare_cache from System"` - extracts typical values correctly
  - `@testset "Integration: cache preparation in call"` - full pipeline with cache
  - `@testset "Integration: RHS uses ADCache when available"` - verify optimized gradient calls
  - `@testset "Integration: fallback without cache"` - verify non-cached path works
  - `@testset "Integration: cache passed through ODE parameters"` - verify p.cache accessibility

Run tests:
```bash
julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["suite/differentiation/test_cache_preparation"])' 2>&1 | tee /tmp/phase6.log
grep -E "Error|Fail|Test Summary" /tmp/phase6.log
```

## Phase 7 — Augmented Configs and Solutions

### Step 27 — `src/Common/configs.jl` (modified)

> 🏗️ Applying Modules Rule — Add new config types following existing pattern

- Add `struct HamiltonianAugmentedPointConfig{T0<:Real, X0, P0, TF<:Real} <: AbstractConfigWithMaC{X0, PointTrait, HamiltonianTrait}`
- Add `struct HamiltonianAugmentedTrajectoryConfig{TS<:Tuple{<:Real,<:Real}, X0, P0} <: AbstractConfigWithMaC{X0, TrajectoryTrait, HamiltonianTrait}`
- Implement `Base.show` methods for both configs
- Implement `initial_condition` to return `vcat(x0, p0, zeros(m))` (m inferred at runtime)

> ⛔ Do NOT write docstrings in this step. Leave TODO comments only.

### Step 28 — `src/Solutions/building.jl` (modified)

> 📋 Applying Architecture Rule — Augmented solution builder handles result extraction for augmented flows

- Implement `_aug_split_solution(u, x0, p0, m)` helper (splits [x; p; pv] into components)
- Implement `function build_augmented_solution(result, sys::HamiltonianSystem, config::HamiltonianAugmentedPointConfig)`
- Return tuple `(xf, pf, pvf)` with appropriate types (scalar/vector based on dimensions)
- Implement `function build_augmented_solution(result, sys::HamiltonianSystem, config::HamiltonianAugmentedTrajectoryConfig)`
- Return wrapped result with augmented accessor methods

> ⛔ Do NOT write docstrings in this step. Leave TODO comments only.

### Step 29 — Test Checkpoint: Augmented Configs and Solutions

> 🧪 Applying Testing Rule - Test config construction and solution extraction

- Create `test/suite/common/test_augmented_configs.jl`
- Test sections:
  - `@testset "Unit: HamiltonianAugmentedPointConfig construction"` - with scalar/vector dimensions
  - `@testset "Unit: HamiltonianAugmentedTrajectoryConfig construction"` - with scalar/vector dimensions
  - `@testset "Unit: initial_condition for augmented configs"` - correct zero-padding
  - `@testset "Unit: build_augmented_solution point"` - correct splitting
  - `@testset "Unit: build_augmented_solution trajectory"` - correct wrapping

Run tests:
```bash
julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["suite/common/test_augmented_configs"])' 2>&1 | tee /tmp/phase7.log
grep -E "Error|Fail|Test Summary" /tmp/phase7.log
```

## Phase 8 — Flow-Level Augment Support

### Step 30 — `src/Flows/flow.jl` (modified)

> 📋 Applying Architecture Rule — augment parameter on flow call is most coherent with existing variable/unsafe pattern

- Modify `HamiltonianFlow` callable methods to add `augment::Bool=false` keyword argument
- In both point and trajectory callables: if `augment=true`, build `HamiltonianAugmentedPointConfig` or `HamiltonianAugmentedTrajectoryConfig`
- Add validation: if `augment=true` and system is Fixed, throw IncorrectArgument
- Add validation: if `augment=true` and `rhs_augmented===nothing`, throw PreconditionError

> ⛔ Do NOT write docstrings in this step. Leave existing docstrings untouched.

### Step 31 — `src/Flows/calling.jl` (modified)

> 🏗️ Applying Modules Rule — Add dispatch for augmented configs

- Add method `function call(flow::HamiltonianFlow, config::HamiltonianAugmentedPointConfig; variable, unsafe)`
- Build augmented initial condition `u0 = vcat(x0, p0, zeros(m))`
- Use `rhs_augmented` from system instead of `rhs`
- Call `build_augmented_solution` instead of `build_solution`
- Add similar method for `HamiltonianAugmentedTrajectoryConfig`

> ⛔ Do NOT write docstrings in this step. Leave TODO comments only.

### Step 32 — Test Checkpoint: Augmented Flow Integration

> 🧪 Applying Testing Rule - Test augment=true flow calls with numerical verification

- Create `test/suite/flows/test_hamiltonian_augmented.jl`
- Test sections:
  - `@testset "Error: augment=true on Fixed system"` - IncorrectArgument
  - `@testset "Error: augment=true without Hamiltonian source"` - PreconditionError
  - `@testset "Integration: augment=true point call"` - verify pvf = -∫∂H/∂v dt numerically
  - `@testset "Integration: augment=true trajectory call"` - verify augmented solution structure
  - `@testset "Integration: Scalar/vector dimensions"` - correct return types
  - `@testset "Regression: augment=false still works"` - ensure non-augmented path unchanged

Run tests:
```bash
julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["suite/flows/test_hamiltonian_augmented"])' 2>&1 | tee /tmp/phase8.log
grep -E "Error|Fail|Test Summary" /tmp/phase8.log
```

## Phase 9 — High-Level Flow Constructor

### Step 33 — `src/Flows/building.jl` (modified)

> 📋 Applying Architecture Rule — User-friendly Flow constructor builds strategy internally, follows Flow(data::Data.VectorField; opts...) pattern
> 🏗️ Applying Modules Rule — Two-level API: internal build functions + user-friendly constructors

- Implement `function Flow(h::AbstractHamiltonian; ad_backend=DifferentiationInterface(), integrator_opts...)`
  - Build AD backend strategy from ad_backend option using `Differentiation.build_ad_backend(ad_backend)`
  - Build HamiltonianVectorField via internal `build_hamiltonian_vector_field(h, ad_backend)`
  - Build HamiltonianSystem via `Systems.build_system(hvf)`
  - Build integrator via `Integrators.build_integrator(; integrator_opts...)`
  - Return `build_flow(system, integrator, ad_backend)` (pass ad_backend to flow)
  - Note: If ad_backend is not provided, uses default DifferentiationInterface() which resolves to AutoForwardDiff() via CTFlowsForwardDiff extension
  - Note: This is user-friendly API that hides strategy construction details, analogous to `Flow(data::Data.VectorField; opts...)`
- Implement overload with `state_dimension::Int` parameter
- Modify `build_flow` to accept optional `ad_backend` argument

> ⛔ Do NOT write docstrings in this step. Leave TODO comments only.

### Step 34 — Test Checkpoint: High-Level Flow Constructor

> 🧪 Applying Testing Rule - Test Flow(H) convenience constructor

- Create `test/suite/flows/test_flow_from_hamiltonian.jl`
- Test sections:
  - `@testset "Unit: Flow(H) construction"` - with ad_backend option
  - `@testset "Unit: Flow(H, n) construction"` - with dimension
  - `@testset "Integration: Full pipeline H -> Flow -> call"` - end-to-end
  - `@testset "Integration: Flow(H) with augment=true"` - complete workflow
  - `@testset "Integration: Default backend resolution"` - uses AutoForwardDiff() when ForwardDiff loaded

Run tests:
```bash
julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["suite/flows/test_flow_from_hamiltonian"])' 2>&1 | tee /tmp/phase9.log
grep -E "Error|Fail|Test Summary" /tmp/phase9.log
```

## Phase 10 — Documentation

### Step 35 — Docstrings (all modified files)

> 📚 Applying Documentation Rule — Use $(TYPEDEF)/$(TYPEDSIGNATURES), full sections, [@ref]/[@extref] cross-references, safe examples

Write docstrings for:
- `src/Data/hamiltonian.jl` - Hamiltonian struct, constructor, call signatures, helpers
- `src/Differentiation/abstract_ad_backend.jl` - AbstractADBackend, DifferentiationInterfaceTag
- `src/Differentiation/differentiation_interface.jl` - DifferentiationInterface strategy
- `src/Differentiation/gradient_functions.jl` - gradient function stubs
- `src/Differentiation/building.jl` - build_ad_backend
- `src/Differentiation/preparation.jl` - prepare_cache with Constant contexts
- `ext/CTFlowsDifferentiationInterface.jl` - extension implementations
- `src/Data/hamiltonian_conversions.jl` - build_hamiltonian_vector_field with Context types and separated gradients
- `src/Systems/building.jl` - build_system overloads for Hamiltonian
- `src/Systems/hamiltonian_system.jl` - cache field documentation
- `src/Common/configs.jl` - augmented config types
- `src/Flows/building.jl` - Flow(H) constructors
- `src/Flows/flow.jl` - ad_backend field documentation
- `src/Flows/calling.jl` - cache preparation and augment parameter documentation
- `src/Solutions/building.jl` - build_augmented_solution

> 📖 Applying Documentation Rule — Update docs/api_reference.jl and docs/make.jl if new submodules introduced

## Step 36 — Final Test Run

> ▶️ Applying Testing Execution Rule - Standard test command

```bash
julia --project -e 'using Pkg; Pkg.test()' 2>&1 | tee /tmp/hamiltonian_feature.log
grep -E "Error|Fail|Test Summary" /tmp/hamiltonian_feature.log
```

Expected: all test suites pass, zero failures, zero errors.

## Files Summary

**New**:
- `src/Data/hamiltonian.jl`
- `src/Differentiation/Differentiation.jl`
- `src/Differentiation/abstract_ad_backend.jl`
- `src/Differentiation/differentiation_interface.jl`
- `src/Differentiation/building.jl`
- `src/Differentiation/conversions.jl`
- `src/Differentiation/preparation.jl`
- `ext/CTFlowsDifferentiationInterface.jl`
- `test/suite/data/test_hamiltonian.jl`
- `test/suite/differentiation/test_ad_backend.jl`
- `test/suite/differentiation/test_hamiltonian_conversions.jl`
- `test/suite/differentiation/test_cache_preparation.jl`
- `test/suite/systems/test_hamiltonian_system_cache.jl`
- `test/suite/systems/test_hamiltonian_to_system.jl`
- `test/suite/common/test_augmented_configs.jl`
- `test/suite/flows/test_hamiltonian_augmented.jl`
- `test/suite/flows/test_flow_from_hamiltonian.jl`

**Modified**:
- `src/Data/Data.jl` - includes and exports (Hamiltonian only)
- `src/CTFlows.jl` - add Differentiation module to load order
- `ext/CTFlowsForwardDiff.jl` - add default backend resolution
- `src/Systems/hamiltonian_system.jl` - cache field and constructors
- `src/Systems/building.jl` - build_system overloads for Hamiltonian
- `src/Common/configs.jl` - augmented config types
- `src/Flows/flow.jl` - ad_backend field, augment parameter
- `src/Flows/calling.jl` - cache preparation, augmented config dispatch
- `src/Solutions/building.jl` - augmented solution builder
- `src/Flows/building.jl` - Flow(H) constructors
- `ext/CTFlowsSciML.jl` - ADCache field in ODEParameters

**Deleted**: None

**Dependencies**:
- Add DifferentiationInterface to Project.toml dependencies
