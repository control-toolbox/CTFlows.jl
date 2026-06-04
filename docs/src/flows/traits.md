# Traits

```@meta
CurrentModule = CTFlows
```

Every object in CTFlows — data wrappers, systems, flows — carries up to three
**compile-time traits** encoded as type parameters. These traits determine the
**call signature** of the object and enable static dispatch without runtime
type checks.

The traits are provided by [`CTFlows.Traits`](@ref CTFlows.Traits).

```@example flows_traits
using CTFlows
using CTFlows.Traits
nothing # hide
```

## The three trait axes

### 1. Time dependence

Does the object depend on time ``t``?

| Value | Type | Meaning |
|---|---|---|
| `Autonomous` | `Traits.Autonomous` | ``t`` is not an argument |
| `NonAutonomous` | `Traits.NonAutonomous` | ``t`` must be supplied |

`Autonomous` and `NonAutonomous` are re-exported from `CTModels.OCP`. They are
available directly from `CTFlows.Traits`.

```@example flows_traits
Traits.Autonomous    # the singleton type
Traits.NonAutonomous
```

Predicates: `is_autonomous(obj)`, `is_nonautonomous(obj)`.

### 2. Variable dependence

Does the object depend on an extra parameter ``v`` (e.g. a free final time or a
design variable)?

| Value | Type | Meaning |
|---|---|---|
| `Fixed` | [`CTFlows.Traits.Fixed`](@ref) | no ``v`` argument |
| `NonFixed` | [`CTFlows.Traits.NonFixed`](@ref) | ``v`` must be supplied |

```@example flows_traits
Traits.Fixed
Traits.NonFixed
```

Predicates: `is_variable(obj)`, `is_nonvariable(obj)`, `has_variable(obj)`.

### 3. Mutability

Does the function allocate a new output, or write into a pre-allocated buffer?

| Value | Type | Meaning |
|---|---|---|
| `OutOfPlace` | [`CTFlows.Traits.OutOfPlace`](@ref) | returns a new value |
| `InPlace` | [`CTFlows.Traits.InPlace`](@ref) | writes into `dx` (first arg) |

```@example flows_traits
Traits.OutOfPlace
Traits.InPlace
```

Predicates: `is_outofplace(obj)`, `is_inplace(obj)`.

!!! note "Default"
    When you construct a `VectorField` without specifying `is_inplace`, the
    mutability is **auto-detected** from the function's arity. Prefer out-of-place
    for simplicity; use in-place only when avoiding allocations matters.

## Call signatures

The combination of time dependence and variable dependence gives four natural call
signatures. For a **vector field** ``X``:

| Time | Variable | Natural signature | Buffer (in-place) |
|---|---|---|---|
| `Autonomous` | `Fixed` | `X(x)` | `X(dx, x)` |
| `NonAutonomous` | `Fixed` | `X(t, x)` | `X(dx, t, x)` |
| `Autonomous` | `NonFixed` | `X(x, v)` | `X(dx, x, v)` |
| `NonAutonomous` | `NonFixed` | `X(t, x, v)` | `X(dx, t, x, v)` |

For a **Hamiltonian** ``H`` the costate `p` follows `x`:

| Time | Variable | Natural signature |
|---|---|---|
| `Autonomous` | `Fixed` | `H(x, p)` |
| `NonAutonomous` | `Fixed` | `H(t, x, p)` |
| `Autonomous` | `NonFixed` | `H(x, p, v)` |
| `NonAutonomous` | `NonFixed` | `H(t, x, p, v)` |

For a **Hamiltonian vector field** ``\vec{H}`` (returns `(dx, dp)`):

| Time | Variable | Natural signature |
|---|---|---|
| `Autonomous` | `Fixed` | `HVF(x, p)` |
| `NonAutonomous` | `Fixed` | `HVF(t, x, p)` |
| `Autonomous` | `NonFixed` | `HVF(x, p, v)` |
| `NonAutonomous` | `NonFixed` | `HVF(t, x, p, v)` |

## Trait accessors

All typed objects expose the same accessor API:

```@example flows_traits
using CTFlows.Data

vf = Data.VectorField((t, x, v) -> x .* v; is_autonomous=false, is_variable=true)

Traits.time_dependence(vf)      # NonAutonomous
Traits.variable_dependence(vf)  # NonFixed
Traits.mutability(vf)           # OutOfPlace (auto-detected)

Traits.is_autonomous(vf)        # false
Traits.is_variable(vf)          # true
Traits.is_outofplace(vf)        # true
```

The same accessors work on systems, flows, and configuration objects — the
trait is always extracted from the type parameter, so there is **no runtime cost**.

## Uniform call signature

Internally, every `VectorField` also responds to a **uniform** call `(t, x, v)`
that ignores unused arguments. This lets system builders write trait-agnostic code:

```julia
# Works regardless of the VectorField's traits:
dx = vf(t, x, v)
```

The uniform signature is used by `VectorFieldSystem.rhs` to build the ODE
right-hand side without trait branches. Users normally never call it directly.

## See also

- [`CTFlows.Traits.Fixed`](@ref), [`CTFlows.Traits.NonFixed`](@ref) — variable-dependence trait values.
- [`CTFlows.Traits.InPlace`](@ref), [`CTFlows.Traits.OutOfPlace`](@ref) — mutability trait values.
- [`CTFlows.Traits.time_dependence`](@ref), [`CTFlows.Traits.variable_dependence`](@ref), [`CTFlows.Traits.mutability`](@ref) — trait accessor functions.
- [`CTFlows.Traits.is_inplace`](@ref), [`CTFlows.Traits.is_outofplace`](@ref) — mutability predicates.
