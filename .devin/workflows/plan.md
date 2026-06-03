# Differential Geometry Integration in CTFlows

Integrate the V2 differential geometry module into CTFlows as a new `DifferentialGeometry` submodule — with deep type integration (`AbstractVectorField`, `AbstractHamiltonian`), a new `AbstractHamiltonianVectorField` abstract type, `gradient`/`derivative` contract methods on `AbstractADBackend`, a lazy global backend `Ref` with `NotProvided` dispatch, and consistent `is_autonomous`/`is_variable` kwargs throughout.

---

## What Changes and Why

### What is added

- `src/Data/abstract_hamiltonian_vector_field.jl` — new abstract type `AbstractHamiltonianVectorField`
- Typed constructors `VectorField(f, ::Type{TD}, ::Type{VD})` and `Hamiltonian(f, ::Type{TD}, ::Type{VD})` in Data
- `gradient` and `derivative` contract stubs on `AbstractADBackend` in `Differentiation`
- `src/DifferentialGeometry/` — new submodule (8 source files + manifest)
- `test/suite/differential_geometry/` — 5 new test files

### What is modified

- `src/Common/default.jl` — move `__ad_backend()` here (from `Differentiation/building.jl`); export it from `Common.jl`
- `src/Data/hamiltonian_vector_field.jl` — parent type → `AbstractHamiltonianVectorField`
- `src/Data/vector_field.jl` — add typed constructor `VectorField(f, ::Type{TD}, ::Type{VD})`
- `src/Data/hamiltonian.jl` — add typed constructor `Hamiltonian(f, ::Type{TD}, ::Type{VD})`
- `src/Data/Data.jl` — new include + export
- `src/Differentiation/abstract_ad_backend.jl` — add `gradient`/`derivative` stubs; annotate `h::Data.AbstractHamiltonian` and `cache::Union{Common.AbstractCache,Nothing}` in existing stubs; remove `__ad_backend()` redirection
- `src/Differentiation/building.jl` — remove `__ad_backend()` (moved to Common)
- `src/Differentiation/Differentiation.jl` — add `import ..Data: Data`; export `gradient`, `derivative`
- `ext/CTFlowsDifferentiationInterface.jl` — implement `gradient` and `derivative`
- `src/CTFlows.jl` — wire `DifferentialGeometry` submodule

### What disappears

- `__ad_backend()` moves from `Differentiation/building.jl` → `Common/default.jl` (same semantics, no API break)
- V1/V2 report files remain untouched

### Key design decisions

- **`Lift(::Function)::Function`** — pure closure, no wrapper
- **`Lift(::AbstractVectorField{TD,VD})::Data.Hamiltonian{TD,VD}`** — no `HamiltonianLift` type
- **`ad(::AbstractVectorField, ::AbstractHamiltonianVectorField)`** — throws `NotImplemented` (HVF takes `(x,p)` not `x`)
- **`ad(::AbstractVectorField{InPlace})`** — throws `NotImplemented` (only OutOfPlace supported)
- **kwargs** are `is_autonomous`/`is_variable` (consistent with `VectorField`/`Hamiltonian` constructors)
- **`ad_backend` kwarg** defaults to `Common.NotProvided()` → dispatched to global `DG_AD_BACKEND[]`
- **`gradient`/`derivative`** are methods on `AbstractADBackend` (not free functions taking `ADTypes.AbstractADType`)
- **TD/VD mismatch** between two typed arguments → `IncorrectArgument`

---

## Dependency Graph After the Change

```text
Traits
  ↓
Configs
  ↓
Common                 (adds __ad_backend)
  ↓
Data                   (adds AbstractHamiltonianVectorField; typed constructors)
  ↓
Differentiation        (imports Data; adds gradient/derivative stubs)
  ↓
DifferentialGeometry   ← NEW
  ↓
Systems
  ↓
Integrators → Solutions → Flows → MultiPhase
```

Extension `CTFlowsDifferentiationInterface` implements `gradient` + `derivative` on `DifferentiationInterface`.

---

## Step 0 — Branch

Use MCP git commands when available:

- `mcp1_git_checkout` to switch to `develop`
- Pull latest changes (bash: `git pull`)
- `mcp1_git_create_branch` to create the new branch from `develop`
- `mcp1_git_checkout` to switch to the new branch

Fallback to bash commands if MCP is unavailable:

```bash
git checkout develop && git pull
git checkout -b feat/differential-geometry
```

---

## Phase 1 — Common: move `__ad_backend`

### Step 1 — `src/Common/default.jl` and `src/Common/Common.jl` (modified)

> 🏗️ Follow `modules` workflow — moving a default helper to the right module

- Move `__ad_backend() = ADTypes.AutoForwardDiff()` from `Differentiation/building.jl` → `Common/default.jl`
- Add `using ADTypes: ADTypes` import to `Common.jl` (if not already present; `ADTypes` is a hard dep)
- Add `export __ad_backend` to `Common.jl` exports
- In `Differentiation/building.jl`: remove the `__ad_backend()` definition; add `import ..Common: Common` if not already present and use `Common.__ad_backend()` where needed (check `DifferentiationInterface` metadata default)

> ⛔ Do NOT write docstrings in this step.

---

## Phase 2 — Data: new abstract type + typed constructors

### Step 2 — `src/Data/abstract_hamiltonian_vector_field.jl` (new file)

> 📐 Follow `architecture` workflow — carves out subhierarchy for Hamiltonian vector fields
> 🔬 Follow `type-stability` workflow — same 3 type parameters as `AbstractVectorField`

```julia
# TODO: docstring
abstract type AbstractHamiltonianVectorField{
    TD <: Traits.TimeDependence,
    VD <: Traits.VariableDependence,
    MD <: Traits.AbstractMutabilityTrait
} <: AbstractVectorField{TD, VD, MD} end
```

> ⛔ Do NOT write docstrings in this step.

---

### Step 3 — `src/Data/hamiltonian_vector_field.jl` (modified)

- Change struct declaration parent: `<: AbstractHamiltonianVectorField{TD, VD, MD}` (was `AbstractVectorField`)

> ⛔ Do NOT write docstrings in this step.

---

### Step 4 — `src/Data/vector_field.jl` and `src/Data/hamiltonian.jl` (modified)

> 🔬 Follow `type-stability` workflow — typed constructors call the struct inner constructor directly, bypassing the bool→type factory path

Add to `vector_field.jl`:

```julia
function VectorField(
    f,
    ::Type{TD}, ::Type{VD}, ::Type{MD} = Traits.OutOfPlace,
) where {
    TD <: Traits.TimeDependence,
    VD <: Traits.VariableDependence,
    MD <: Traits.AbstractMutabilityTrait,
}
    return VectorField{typeof(f), TD, VD, MD}(f)
end
```

Add to `hamiltonian.jl` (`Hamiltonian` has no mutability parameter):

```julia
function Hamiltonian(
    f,
    ::Type{TD}, ::Type{VD},
) where {
    TD <: Traits.TimeDependence,
    VD <: Traits.VariableDependence,
}
    return Hamiltonian{typeof(f), TD, VD}(f)
end
```

Add to `hamiltonian_vector_field.jl` (same pattern, `MD` required — no default since HVF callers always know the mutability):

```julia
function HamiltonianVectorField(
    f,
    ::Type{TD}, ::Type{VD}, ::Type{MD},
) where {
    TD <: Traits.TimeDependence,
    VD <: Traits.VariableDependence,
    MD <: Traits.AbstractMutabilityTrait,
}
    return HamiltonianVectorField{typeof(f), TD, VD, MD}(f)
end
```

Callers in DifferentialGeometry pass `Traits.OutOfPlace` (or `Traits.InPlace`) explicitly:

```julia
Data.VectorField(closure, TD, VD, Traits.OutOfPlace)              # ad_types.jl, time_derivative.jl
Data.HamiltonianVectorField(closure, NonAutonomous, VD, OutOfPlace) # time_derivative.jl
Data.Hamiltonian(closure, TD, VD)                                   # lift.jl, poisson.jl, time_derivative.jl
```

> ⛔ Do NOT write docstrings in this step.

---

### Step 5 — `src/Data/Data.jl` (modified)

> 🏗️ Follow `modules` workflow — include order matters; export new symbol

- Add `include(joinpath(@__DIR__, "abstract_hamiltonian_vector_field.jl"))` **before** `hamiltonian_vector_field.jl`
- Add `export AbstractHamiltonianVectorField`

> ⛔ Do NOT write docstrings in this step.

---

### Checkpoint A — Data tests

Run `test/suite/data/`. Verify:

- `HamiltonianVectorField <: AbstractHamiltonianVectorField <: AbstractVectorField`
- All existing data tests pass unchanged

---

## Phase 3 — Differentiation: gradient/derivative contract

### Step 6 — `src/Differentiation/abstract_ad_backend.jl` (modified)

> 📐 Follow `architecture` workflow — extend contract with two new methods
> ⚠️ Follow `exceptions` workflow — `NotImplemented` stubs with `required_method` + `suggestion`

Add import `import ..Data: Data` to `Differentiation.jl` manifest (see Step 7).

Annotate existing stubs (type-precision improvement):

```julia
function hamiltonian_gradient(
    backend::AbstractADBackend,
    h::Data.AbstractHamiltonian,
    t, x, p, v,
    cache::Union{Common.AbstractCache, Nothing}
)
```

Same annotation for `variable_gradient`, `prepare_cache` (h), and `update!` (cache).

Add two new contract stubs:

```julia
# TODO: docstring
function gradient(backend::AbstractADBackend, f::Function, x)
    throw(Exceptions.NotImplemented(
        "gradient not implemented for $(typeof(backend))",
        required_method = "gradient(backend::$(typeof(backend)), f::Function, x)",
        suggestion = "Load CTFlowsDifferentiationInterface (load DifferentiationInterface)",
        context = "AD backend contract",
    ))
end

# TODO: docstring
function derivative(backend::AbstractADBackend, g::Function, t::Real)
    throw(Exceptions.NotImplemented(
        "derivative not implemented for $(typeof(backend))",
        required_method = "derivative(backend::$(typeof(backend)), g::Function, t::Real)",
        suggestion = "Load CTFlowsDifferentiationInterface (load DifferentiationInterface)",
        context = "AD backend contract",
    ))
end
```

> ⛔ Do NOT write docstrings in this step.

---

### Step 7 — `src/Differentiation/Differentiation.jl` (modified)

> 🏗️ Follow `modules` workflow — Differentiation now imports Data; new exports added

- Add `import ..Data: Data` after `import ..Common: Common`
- Add `export gradient` and `export derivative`

New DAG: `Common → Data → Differentiation` (Data does not import Differentiation — no cycle).

> ⛔ Do NOT write docstrings in this step.

---

### Step 8 — `ext/CTFlowsDifferentiationInterface.jl` (modified)

> 🏗️ Follow `modules` workflow — extension methods follow existing `hamiltonian_gradient` pattern

Add implementations:

```julia
function Differentiation.gradient(
    backend::Differentiation.DifferentiationInterface,
    f::Function,
    x::AbstractArray,
)
    ad = Differentiation.ad_backend(backend)
    return DI.gradient(f, ad, x)
end

function Differentiation.gradient(
    backend::Differentiation.DifferentiationInterface,
    f::Function,
    x::Real,              # scalar case
)
    ad = Differentiation.ad_backend(backend)
    return DI.derivative(f, ad, x)
end

function Differentiation.derivative(
    backend::Differentiation.DifferentiationInterface,
    g::Function,
    t::Real,
)
    ad = Differentiation.ad_backend(backend)
    return DI.derivative(g, ad, t)
end
```

> ⛔ Do NOT write docstrings in this step.

---

### Checkpoint B — Differentiation tests

Run `test/suite/differentiation/`. All existing tests pass. New stubs throw `NotImplemented` without extension; with extension, `gradient` and `derivative` return correct values.

---

## Phase 4 — DifferentialGeometry Submodule

### Step 9 — `src/DifferentialGeometry/default.jl` (new file)

> 🏗️ Follow `modules` workflow — module-level defaults; no new backend type, use existing infrastructure

```julia
# Default AD backend sentinel — uses global DG_AD_BACKEND when not overridden
__dg_ad_backend()::Common.NotProvided = Common.NotProvided()

# Global default backend ref — built once at module load
const DG_AD_BACKEND = Ref{Differentiation.AbstractADBackend}(
    Differentiation.build_ad_backend()   # AutoForwardDiff via Common.__ad_backend()
)

# Getter
dg_ad_backend() = DG_AD_BACKEND[]

# Setter — rebuilds the backend from an ADTypes backend
function dg_ad_backend!(ad_backend::ADTypes.AbstractADType)
    DG_AD_BACKEND[] = Differentiation.build_ad_backend(; ad_backend = ad_backend)
    return nothing
end

# Resolution: NotProvided → global ref; ADTypes.AbstractADType → build fresh backend
_resolve_backend(::Common.NotProvided)              = DG_AD_BACKEND[]
_resolve_backend(ad_backend::ADTypes.AbstractADType) = Differentiation.build_ad_backend(; ad_backend = ad_backend)
```

Note: `is_autonomous` and `is_variable` defaults come from `Common.__is_autonomous()` and `Common.__is_variable()` — no local aliases needed.

> ⛔ Do NOT write docstrings in this step.

---

### Step 10 — `src/DifferentialGeometry/prefix.jl` (new file)

> 🏗️ Follow `modules` workflow — module-level `const Ref`

```julia
const DIFFGEO_PREFIX = Ref{Symbol}(:CTFlows)
diffgeo_prefix()::Symbol      = DIFFGEO_PREFIX[]
diffgeo_prefix!(p::Symbol)    = (DIFFGEO_PREFIX[] = p; nothing)
```

> ⛔ Do NOT write docstrings in this step.

---

### Step 11 — `src/DifferentialGeometry/ad.jl` (new file)

> 📐 Follow `architecture` workflow — pure-function layer; internal `_ad` uses `Any` for `X`/`foo` to support both `Function` and `AbstractVectorField` callables
> 🔬 Follow `type-stability` workflow — 4 specialised `_ad` variants; `_ad_result` dispatches on `Number` vs `AbstractVector`

Public API (kwargs renamed `is_autonomous`/`is_variable`):

```julia
# kwargs entry point — resolves backend, then calls _ad directly
function ad(
    X::Function, foo::Function;
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
    is_autonomous::Bool = Common.__is_autonomous(),
    is_variable::Bool   = Common.__is_variable(),
)
    TD      = is_autonomous ? Traits.Autonomous    : Traits.NonAutonomous
    VD      = is_variable   ? Traits.NonFixed       : Traits.Fixed
    backend = _resolve_backend(ad_backend)
    return _ad(X, foo, backend, TD, VD)   # ← call internal directly; no re-dispatch
end

# typed entry point (used by @Lie macro) — also resolves, then calls _ad directly
function ad(
    X::Function, foo::Function,
    ::Type{TD}, ::Type{VD};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD <: Traits.TimeDependence, VD <: Traits.VariableDependence}
    backend = _resolve_backend(ad_backend)
    return _ad(X, foo, backend, TD, VD)
end
```

Internal (note: `X` and `foo` typed as `Any` so `AbstractVectorField` callables work):

```julia
function _ad(X, foo, backend, ::Type{Traits.Autonomous}, ::Type{Traits.Fixed})
    return function (x)
        X_x  = X(x)
        g(t) = foo(x + t * X_x)
        dfoo = Differentiation.derivative(backend, g, 0.0)
        return _ad_result(X, foo, dfoo, x, X_x, backend)
    end
end
# ... 3 more variants for (NonAutonomous,Fixed), (Autonomous,NonFixed), (NonAutonomous,NonFixed)

# Lie derivative (scalar output): just return the directional derivative
_ad_result(X, foo, dfoo::Number, x, X_x, backend, args...) = dfoo

# Lie bracket (vector output): subtract J_X * Y
function _ad_result(X, foo, dfoo::AbstractVector, x, X_x, backend, args...)
    Y_x  = foo(x, args...)
    h(t) = X(x + t * Y_x, args...)
    dX   = Differentiation.derivative(backend, h, 0.0)
    return dfoo - dX
end
```

> ⛔ Do NOT write docstrings in this step.

---

### Step 12 — `src/DifferentialGeometry/ad_types.jl` (new file)

> 📐 Follow `architecture` workflow — typed overloads dispatch on `AbstractVectorField`
> ⚠️ Follow `exceptions` workflow — guards for HVF and InPlace throw `NotImplemented`; TD/VD mismatch throws `IncorrectArgument`
> 🔬 Follow `type-stability` workflow — returns `Data.VectorField(closure, TD, VD)` using typed constructor

Guard helpers:

```julia
# InPlace guard: dispatches on the MD *type* (captured from the where clause — fully static)
_check_outofplace(::Type{Traits.OutOfPlace}) = nothing
function _check_outofplace(::Type{MD}) where {MD <: Traits.AbstractMutabilityTrait}
    throw(Exceptions.NotImplemented(
        "ad is not implemented for InPlace vector fields",
        required_method = "Use an OutOfPlace VectorField",
        suggestion      = "Reconstruct the VectorField without in-place flag",
        context         = "ad on AbstractVectorField",
    ))
end

# HVF guard: dispatch on type hierarchy (runtime — MD params don't encode HVF vs plain VF)
_check_not_hvf(::Data.AbstractVectorField)            = nothing
function _check_not_hvf(X::Data.AbstractHamiltonianVectorField)
    throw(Exceptions.NotImplemented(
        "ad on AbstractHamiltonianVectorField is not implemented (signature is (x,p), not (x))",
        suggestion = "Use ad on a plain VectorField",
        context    = "ad on AbstractVectorField",
    ))
end
```

Typed methods (matching TD/VD, returning `Data.VectorField`):

```julia
function ad(
    X::Data.AbstractVectorField{TD, VD, MDX},
    Y::Data.AbstractVectorField{TD, VD, MDY};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD, VD, MDX, MDY}
    _check_not_hvf(X); _check_not_hvf(Y)
    _check_outofplace(MDX)    # static dispatch on type parameter — no runtime call
    _check_outofplace(MDY)
    backend  = _resolve_backend(ad_backend)
    closure  = _ad(X, Y, backend, TD, VD)
    return Data.VectorField(closure, TD, VD, Traits.OutOfPlace)  # typed constructor, explicit mutability
end

# Lie derivative: VectorField + scalar Function → Function
function ad(
    X::Data.AbstractVectorField{TD, VD, MDX},
    f::Function;
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD, VD, MDX}
    _check_not_hvf(X)
    _check_outofplace(MDX)    # static dispatch
    backend = _resolve_backend(ad_backend)
    return _ad(X, f, backend, TD, VD)  # scalar output → returns a plain Function
end

# TD/VD mismatch → IncorrectArgument
function ad(
    X::Data.AbstractVectorField{TD1, VD1, MDX},
    Y::Data.AbstractVectorField{TD2, VD2, MDY};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD1, VD1, MDX, TD2, VD2, MDY}
    throw(Exceptions.IncorrectArgument(
        "ad: TD/VD mismatch between X and Y",
        got      = "X: $(TD1)/$(VD1), Y: $(TD2)/$(VD2)",
        expected = "Both arguments must share the same TimeDependence and VariableDependence",
        context  = "ad on AbstractVectorField",
    ))
end
```

> ⛔ Do NOT write docstrings in this step.

---

### Step 13 — `src/DifferentialGeometry/lift.jl` (new file)

> 📐 Follow `architecture` workflow — two distinct public API entry points
> 🔬 Follow `type-stability` workflow — typed variant returns `Data.Hamiltonian{TD,VD}`

```julia
# Function → Function (pure closure)
function Lift(
    f::Function;
    is_autonomous::Bool = Common.__is_autonomous(),
    is_variable::Bool   = Common.__is_variable(),
)  # no ad_backend: Lift is purely algebraic
    TD = is_autonomous ? Traits.Autonomous : Traits.NonAutonomous
    VD = is_variable   ? Traits.NonFixed   : Traits.Fixed
    return Lift(f, TD, VD)
end

function Lift(f::Function, ::Type{TD}, ::Type{VD}) where {TD, VD}
    return _Lift(f, TD, VD)
end

_Lift(f, ::Type{Traits.Autonomous},    ::Type{Traits.Fixed})    = (x, p)       -> p' * f(x)
_Lift(f, ::Type{Traits.Autonomous},    ::Type{Traits.NonFixed}) = (x, p, v)    -> p' * f(x, v)
_Lift(f, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})    = (t, x, p)    -> p' * f(t, x)
_Lift(f, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed}) = (t, x, p, v) -> p' * f(t, x, v)

# AbstractVectorField → Data.Hamiltonian
function Lift(X::Data.AbstractVectorField{TD, VD}) where {TD, VD}
    _check_not_hvf(X)   # HVF guard from ad_types.jl
    closure = _Lift(X, TD, VD)   # reuse the same 4 _Lift methods (X is callable)
    return Data.Hamiltonian(closure, TD, VD)   # typed Hamiltonian constructor (no MD)
end
```

> ⛔ Do NOT write docstrings in this step.

---

### Step 14 — `src/DifferentialGeometry/poisson.jl` (new file)

> 📐 Follow `architecture` workflow — Function-only + typed API
> ⚠️ Follow `exceptions` workflow — TD/VD mismatch → `IncorrectArgument`
> 🔬 Follow `type-stability` workflow — typed returns `Data.Hamiltonian{TD,VD}`

```julia
# kwargs entry point — resolves backend, then calls _Poisson directly
function Poisson(
    H::Function, G::Function;
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
    is_autonomous::Bool = Common.__is_autonomous(),
    is_variable::Bool   = Common.__is_variable(),
)
    TD      = is_autonomous ? Traits.Autonomous : Traits.NonAutonomous
    VD      = is_variable   ? Traits.NonFixed   : Traits.Fixed
    backend = _resolve_backend(ad_backend)
    return _Poisson(H, G, backend, TD, VD)  # ← call internal directly
end

# typed entry point (used by @Lie macro)
function Poisson(
    H::Function, G::Function,
    ::Type{TD}, ::Type{VD};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD, VD}
    backend = _resolve_backend(ad_backend)
    return _Poisson(H, G, backend, TD, VD)
end

# Internal: uses Differentiation.gradient
function _Poisson(H, G, backend, ::Type{Traits.Autonomous}, ::Type{Traits.Fixed})
    return function (x, p)
        gxH = Differentiation.gradient(backend, y -> H(y, p), x)
        gpH = Differentiation.gradient(backend, q -> H(x, q), p)
        gxG = Differentiation.gradient(backend, y -> G(y, p), x)
        gpG = Differentiation.gradient(backend, q -> G(x, q), p)
        return gpH' * gxG - gxH' * gpG
    end
end
# ... 3 more variants (NonAutonomous/Fixed, Autonomous/NonFixed, NonAutonomous/NonFixed)

# Typed overload: AbstractHamiltonian → Data.Hamiltonian
function Poisson(
    H::Data.AbstractHamiltonian{TD, VD},
    G::Data.AbstractHamiltonian{TD, VD};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD, VD}
    backend = _resolve_backend(ad_backend)
    closure = _Poisson(H, G, backend, TD, VD)
    return Data.Hamiltonian(closure, TD, VD)  # typed constructor
end

# TD/VD mismatch → IncorrectArgument
function Poisson(
    H::Data.AbstractHamiltonian{TD1, VD1},
    G::Data.AbstractHamiltonian{TD2, VD2};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD1, VD1, TD2, VD2}
    throw(Exceptions.IncorrectArgument(
        "Poisson: TD/VD mismatch between H and G",
        got      = "H: $(TD1)/$(VD1), G: $(TD2)/$(VD2)",
        expected = "Both Hamiltonians must share the same TimeDependence and VariableDependence",
        context  = "Poisson on AbstractHamiltonian",
    ))
end
```

> ⛔ Do NOT write docstrings in this step.

---

### Step 15 — `src/DifferentialGeometry/time_derivative.jl` (new file)

> 🔬 `∂ₜ` works for all TD: Autonomous inputs return a zero-valued NonAutonomous result (derivative of a constant = 0).
> Call signatures differ between Autonomous (no t) and NonAutonomous (t), so internal helpers dispatch on both TD and VD.
> `AbstractHamiltonianVectorField` needs its own overload (call signature `(x,p)` vs `(x)` for plain VF).

```julia
# Function → Function  (caller must ensure f takes t as first argument)
function ∂ₜ(
    f::Function;
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
)
    backend = _resolve_backend(ad_backend)
    return (t, args...) -> Differentiation.derivative(backend, s -> f(s, args...), t)
end

# AbstractHamiltonianVectorField{TD,VD} → HamiltonianVectorField{NonAutonomous,VD}
# (more specific than AbstractVectorField — must appear first or Julia will prefer VF overload)
function ∂ₜ(
    X::Data.AbstractHamiltonianVectorField{TD, VD, MD};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD, VD, MD}
    _check_outofplace(MD)
    backend = _resolve_backend(ad_backend)
    closure = _∂ₜ_hvf(X, backend, TD, VD)
    return Data.HamiltonianVectorField(closure, Traits.NonAutonomous, VD, Traits.OutOfPlace)
end

# Autonomous HVF: X has natural call (x,p) or (x,p,v) — s is ignored → derivative = 0
_∂ₜ_hvf(X, b, ::Type{Traits.Autonomous},    ::Type{Traits.Fixed})    = (t, x, p)    -> Differentiation.derivative(b, s -> X(x, p),    t)
_∂ₜ_hvf(X, b, ::Type{Traits.Autonomous},    ::Type{Traits.NonFixed}) = (t, x, p, v) -> Differentiation.derivative(b, s -> X(x, p, v), t)
# NonAutonomous HVF: X has natural call (t,x,p) or (t,x,p,v)
_∂ₜ_hvf(X, b, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})    = (t, x, p)    -> Differentiation.derivative(b, s -> X(s, x, p),    t)
_∂ₜ_hvf(X, b, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed}) = (t, x, p, v) -> Differentiation.derivative(b, s -> X(s, x, p, v), t)

# AbstractVectorField{TD,VD} → VectorField{NonAutonomous,VD}
# (catches plain VF; HVF handled above)
function ∂ₜ(
    X::Data.AbstractVectorField{TD, VD, MD};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD, VD, MD}
    _check_outofplace(MD)
    backend = _resolve_backend(ad_backend)
    closure = _∂ₜ_vf(X, backend, TD, VD)
    return Data.VectorField(closure, Traits.NonAutonomous, VD, Traits.OutOfPlace)
end

# Autonomous VF: X has natural call (x) or (x,v) — s is ignored → derivative = 0
_∂ₜ_vf(X, b, ::Type{Traits.Autonomous},    ::Type{Traits.Fixed})    = (t, x)    -> Differentiation.derivative(b, s -> X(x),    t)
_∂ₜ_vf(X, b, ::Type{Traits.Autonomous},    ::Type{Traits.NonFixed}) = (t, x, v) -> Differentiation.derivative(b, s -> X(x, v), t)
# NonAutonomous VF: X has natural call (t,x) or (t,x,v)
_∂ₜ_vf(X, b, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})    = (t, x)    -> Differentiation.derivative(b, s -> X(s, x),    t)
_∂ₜ_vf(X, b, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed}) = (t, x, v) -> Differentiation.derivative(b, s -> X(s, x, v), t)

# AbstractHamiltonian{TD,VD} → Hamiltonian{NonAutonomous,VD}
function ∂ₜ(
    H::Data.AbstractHamiltonian{TD, VD};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD, VD}
    backend = _resolve_backend(ad_backend)
    closure = _∂ₜ_ham(H, backend, TD, VD)
    return Data.Hamiltonian(closure, Traits.NonAutonomous, VD)
end

# Autonomous Ham: natural call (x,p) or (x,p,v) — derivative = 0
_∂ₜ_ham(H, b, ::Type{Traits.Autonomous},    ::Type{Traits.Fixed})    = (t, x, p)    -> Differentiation.derivative(b, s -> H(x, p),    t)
_∂ₜ_ham(H, b, ::Type{Traits.Autonomous},    ::Type{Traits.NonFixed}) = (t, x, p, v) -> Differentiation.derivative(b, s -> H(x, p, v), t)
# NonAutonomous Ham: natural call (t,x,p) or (t,x,p,v)
_∂ₜ_ham(H, b, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})    = (t, x, p)    -> Differentiation.derivative(b, s -> H(s, x, p),    t)
_∂ₜ_ham(H, b, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed}) = (t, x, p, v) -> Differentiation.derivative(b, s -> H(s, x, p, v), t)
```

> ⛔ Do NOT write docstrings in this step.

---

### Step 16 — `src/DifferentialGeometry/lie_macro.jl` (new file)

> 🏗️ Follow `modules` workflow — uses `MacroTools` (verify presence in `Project.toml`)

Two kinds of options are handled differently:

- **Compile-time** (`is_autonomous`, `is_variable`): evaluated at macro-expansion, converted to `TD`/`VD` type symbols → enable typed dispatch
- **Runtime** (`ad_backend`): captured as an AST expression and spliced as a kwarg into the generated call

```julia
macro Lie(expr::Expr, args...)
    is_autonomous = Common.__is_autonomous()
    is_variable   = Common.__is_variable()
    ad_backend_kw = nothing   # nothing → no ad_backend kwarg in generated call

    for arg in args
        if @capture(arg, is_autonomous = val_)
            is_autonomous = val
        elseif @capture(arg, is_variable = val_)
            is_variable = val
        elseif @capture(arg, ad_backend = val_)
            ad_backend_kw = :(ad_backend = $val)   # splice as runtime kwarg
        end
    end

    TD = is_autonomous ? :Autonomous : :NonAutonomous
    VD = is_variable   ? :NonFixed   : :Fixed
    prefix = diffgeo_prefix()
    extra_kws = ad_backend_kw === nothing ? [] : [ad_backend_kw]

    function fun(x)
        is_lie, is_poisson = @capture(x, [a_, b_]), @capture(x, {c_, d_})
        if is_lie
            return :($prefix.ad($a, $b, $prefix.$TD, $prefix.$VD; $(extra_kws...)))
        elseif is_poisson
            return :($prefix.Poisson($c, $d, $prefix.$TD, $prefix.$VD; $(extra_kws...)))
        else
            return x
        end
    end
    return esc(postwalk(fun, expr))
end
```

Examples:

- `@Lie [X, Y]` → `ad(X, Y, Autonomous, Fixed)`
- `@Lie {H, G}` → `Poisson(H, G, Autonomous, Fixed)`
- `@Lie [X, Y] ad_backend=b` → `ad(X, Y, Autonomous, Fixed; ad_backend=b)`
- `@Lie {H, G} is_autonomous=false ad_backend=b` → `Poisson(H, G, NonAutonomous, Fixed; ad_backend=b)`

> ⛔ Do NOT write docstrings in this step.

---

### Step 17 — `src/DifferentialGeometry/DifferentialGeometry.jl` (new manifest)

> 🏗️ Follow `modules` workflow — manifest pattern: imports → includes (dependency order) → exports

```julia
module DifferentialGeometry

import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import MacroTools: postwalk, @capture
import CTBase.Exceptions

import ..Traits: Traits
import ..Common: Common
import ..Data: Data
import ..Differentiation: Differentiation

include("default.jl")
include("prefix.jl")
include("ad.jl")
include("ad_types.jl")
include("lift.jl")
include("poisson.jl")
include("time_derivative.jl")
include("lie_macro.jl")

export ad
export Lift
export Poisson
export ∂ₜ
export dg_ad_backend, dg_ad_backend!
export diffgeo_prefix, diffgeo_prefix!
export var"@Lie"

end
```

> ⛔ Do NOT write docstrings in this step.

---

### Step 18 — `src/CTFlows.jl` (modified)

> 🏗️ Follow `modules` workflow — insert after `Differentiation`, before `Systems`

```julia
include(joinpath(@__DIR__, "DifferentialGeometry", "DifferentialGeometry.jl"))
using .DifferentialGeometry
```

> ⛔ Do NOT write docstrings in this step.

---

### Checkpoint C — Smoke test

```julia
using CTFlows
X(x) = [x[2], -x[1]]
Y(x) = [x[1], x[2]]
Z = CTFlows.DifferentialGeometry.ad(X, Y)
Z([1.0, 2.0])   # expected: [-1.0, 2.0]

H(x, p) = 0.5 * sum(p.^2)
G(x, p) = x[1]
PB = CTFlows.DifferentialGeometry.Poisson(H, G)
PB([1.0, 2.0], [3.0, 4.0])   # expected: 3.0
```

---

## Phase 5 — Tests

### Step 19 — `test/suite/differential_geometry/test_ad.jl` (new file)

> 🔬 Follow `testing-creation` workflow — module wrapper; fake types at top-level; `test_ad()` function

Test groups:

- `Function/Function — Lie derivative` — all 4 (TD,VD) combos; check correctness
- `Function/Function — Lie bracket` — all 4 combos; Jacobi identity; intrinsic `[X,Y]·f = X·(Yf) - Y·(Xf)`
- `VectorField/VectorField` — return type is `Data.VectorField`; traits match; correctness
- `VectorField/Function (Lie derivative)` — returns `Function`
- `Errors: HVF guard` — `ad(hvf, ...)` throws `NotImplemented`
- `Errors: InPlace guard` — `ad(ip_vf, ...)` throws `NotImplemented`
- `Errors: TD/VD mismatch` — throws `IncorrectArgument`
- `Backend: custom ad_backend kwarg` — override global; result unchanged
- `Backend: dg_ad_backend!` — set global; verify used

---

### Step 20 — `test/suite/differential_geometry/test_lift.jl` (new file)

> 🔬 Follow `testing-creation` workflow

Test groups:

- `Lift(Function)` — all 4 (TD,VD); return type is `Function`; correctness
- `Lift(Function, TD, VD)` — typed dispatch matches kwargs version
- `Lift(VectorField)` — return type is `Data.Hamiltonian`; traits preserved; correctness
- `Lift(HamiltonianVectorField)` — guard throws `NotImplemented`

---

### Step 21 — `test/suite/differential_geometry/test_poisson.jl` (new file)

> 🔬 Follow `testing-creation` workflow

Test groups:

- `Poisson(Function, Function)` — all 4 combos; anticommutativity; Jacobi; Leibniz rule
- `Poisson(AbstractHamiltonian, AbstractHamiltonian)` — return type `Data.Hamiltonian`; traits match
- `Errors: TD/VD mismatch` — throws `IncorrectArgument`
- `Composition: Poisson(Lift(f), Lift(g))`

---

### Step 22 — `test/suite/differential_geometry/test_macro.jl` (new file)

> 🔬 Follow `testing-creation` workflow

Test groups:

- `@Lie [X, Y]` — correctness; nested `@Lie [X, [Y, Z]]`
- `@Lie {H, G}` — Poisson correctness
- `@Lie` with `is_autonomous=false`, `is_variable=true`
- Prefix system get/set

---

### Step 23 — `test/suite/differential_geometry/test_time_derivative.jl` (new file)

> 🔬 Follow `testing-creation` workflow

Test groups:

- `∂ₜ(Function)` — correctness with vector `x`
- `∂ₜ(VectorField{NonAutonomous})` — returns `VectorField{NonAutonomous}`; traits preserved; correctness
- `∂ₜ(Hamiltonian{NonAutonomous})` — returns `Hamiltonian{NonAutonomous}`; correctness
- `Errors: ∂ₜ(VectorField{Autonomous})` → `IncorrectArgument`
- `Errors: ∂ₜ(Hamiltonian{Autonomous})` → `IncorrectArgument`

---

### Checkpoint D — Full test suite

> 🔬 Follow `testing-execution` workflow

```bash
julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["suite/differential_geometry"])'
julia --project -e 'using Pkg; Pkg.test("CTFlows")'  # full regression check
```

---

## Phase 6 — Docstrings

### Step 24 — Docstrings for all new symbols

> 📝 Follow `docstrings` workflow — `$(TYPEDEF)` for types, `$(TYPEDSIGNATURES)` for functions

Symbols to document:

- `Data.AbstractHamiltonianVectorField`
- `Differentiation.gradient`, `Differentiation.derivative` (contract stubs)
- `DifferentialGeometry.ad` (Function variant + typed variant + AbstractVectorField overloads)
- `DifferentialGeometry.Lift` (Function variant + AbstractVectorField variant)
- `DifferentialGeometry.Poisson` (Function + AbstractHamiltonian + typed variants)
- `DifferentialGeometry.∂ₜ` (all overloads)
- `DifferentialGeometry.@Lie`
- `DifferentialGeometry.diffgeo_prefix`, `diffgeo_prefix!`, `dg_ad_backend`, `dg_ad_backend!`

---

## Notes

- **`MacroTools`**: check `Project.toml` before Step 16 — add as dependency if absent.
- **`Systems/vector_field_system.jl`**: uses concrete `Data.VectorField{F,TD,VD,MD}` — no change in this PR; abstract dispatch in Systems is future work.
- **Typed `_Lift` reuse**: `_Lift(X::AbstractVectorField, TD, VD)` works because `VectorField` is callable with the natural signature; the 4 `_Lift` methods accept `Any` as first arg.
- **`_ad` accepts `Any`**: removing `::Function` annotation from `_ad` parameters allows passing `VectorField` and `Hamiltonian` callables without subtyping `Function`.
- **Never commit without explicit user instruction.**
