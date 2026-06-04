# Data structures

```@meta
CurrentModule = CTFlows
```

The [`CTFlows.Data`](@ref CTFlows.Data) submodule provides the typed wrappers
that carry your Julia functions along with their **trait metadata**. These wrappers
are the input layer of the CTFlows pipeline.

```@setup flows_data
using CTFlows
using CTFlows.Data
using CTFlows.Traits
import OrdinaryDiffEqTsit5
```

## Overview

| Type | Mathematical object | Natural signature (autonomous/fixed) |
|---|---|---|
| [`VectorField`](@ref CTFlows.Data.VectorField) | ``X : \mathcal{X} \to \mathbb{R}^n`` | `X(x)` |
| [`Hamiltonian`](@ref CTFlows.Data.Hamiltonian) | ``H : T^*\mathcal{X} \to \mathbb{R}`` | `H(x, p)` |
| [`HamiltonianVectorField`](@ref CTFlows.Data.HamiltonianVectorField) | ``\vec{H} : T^*\mathcal{X} \to \mathbb{R}^{2n}`` | `HVF(x, p)` |

All three share the same trait axes: time dependence, variable dependence,
and mutability. See [Traits](traits.md) for the full call-signature tables.

---

## VectorField

A `VectorField` wraps a Julia function representing ``\dot{x} = X(\cdots)``.

### Construction

```@example flows_data
# Autonomous, fixed (default): X(x)
vf1 = Data.VectorField(x -> -x)

# Non-autonomous, fixed: X(t, x)
vf2 = Data.VectorField((t, x) -> t .* x; is_autonomous=false)

# Autonomous, non-fixed: X(x, v)
vf3 = Data.VectorField((x, v) -> x .* v; is_variable=true)

# Non-autonomous, non-fixed: X(t, x, v)
vf4 = Data.VectorField((t, x, v) -> t .* x .+ v; is_autonomous=false, is_variable=true)

vf1
```

The `show` output summarises the traits and both call signatures (natural and
uniform) for the object.

### In-place construction

Prefer out-of-place for clarity. Use in-place when avoiding allocations matters:

```@example flows_data
# In-place Autonomous/Fixed: f(dx, x) — mutability auto-detected
vf_ip = Data.VectorField((dx, x) -> (dx .= -x; nothing))
Traits.mutability(vf_ip)
```

If the function has multiple methods, auto-detection fails. Pass `is_inplace`
explicitly:

```@example flows_data
f_multi(x) = -x
f_multi(dx, x) = (dx .= -x; nothing)

vf_explicit = Data.VectorField(f_multi; is_inplace=true)
```

### Calling

```@example flows_data
x0 = [1.0, 0.5]

vf1(x0)                    # natural call
vf1(0.0, x0, nothing)      # uniform call (ignores t and v)
vf2(0.5, x0)               # non-autonomous natural call
```

---

## Hamiltonian

A `Hamiltonian` wraps a scalar function ``H(x, p) \in \mathbb{R}``.

```math
H : T^*\mathcal{X} \to \mathbb{R}, \quad (x, p) \mapsto H(x, p).
```

### Construction

```@example flows_data
using LinearAlgebra

# Autonomous, fixed (default): H(x, p)
h1 = Data.Hamiltonian((x, p) -> dot(p, x))

# Non-autonomous, fixed: H(t, x, p)
h2 = Data.Hamiltonian((t, x, p) -> t * dot(p, x); is_autonomous=false)

# Autonomous, non-fixed: H(x, p, v)
h3 = Data.Hamiltonian((x, p, v) -> dot(p, x) * v[1]; is_variable=true)

h1
```

### Calling

```@example flows_data
x0, p0 = [1.0, 0.5], [0.3, 0.7]

h1(x0, p0)              # natural call
h1(0.0, x0, p0, nothing)  # uniform call
h2(0.5, x0, p0)         # non-autonomous
```

---

## HamiltonianVectorField

A `HamiltonianVectorField` wraps the map
``(x, p) \mapsto (\dot{x}, \dot{p}) = (\partial_p H, -\partial_x H)``
when the derivatives are provided **explicitly** (no AD required).

```math
\vec{H}(x, p) = \bigl(\partial_p H(x,p),\; -\partial_x H(x,p)\bigr).
```

Use this when you know the Hamiltonian equations analytically. For the case where
only the scalar Hamiltonian is known and the derivatives must be computed by AD,
use [`Data.Hamiltonian`](@ref CTFlows.Data.Hamiltonian) instead and build the flow
with `Flows.Flow(h; ...)`.

### Construction

```@example flows_data
# Harmonic oscillator: H = (x²+p²)/2
# ẋ = p, ṗ = -x
hvf = Data.HamiltonianVectorField((x, p) -> (p, -x))

# With time dependence
hvf_na = Data.HamiltonianVectorField((t, x, p) -> (p, -x .* t); is_autonomous=false)

hvf
```

### Calling

```@example flows_data
dx, dp = hvf(x0, p0)   # natural call: returns (ẋ, ṗ)
(dx, dp)
```

---

## Typed constructors

A lower-level constructor takes trait types directly (no keyword inference):

```@example flows_data
vf_typed = Data.VectorField(x -> 2x, Traits.Autonomous, Traits.Fixed, Traits.OutOfPlace)
Traits.time_dependence(vf_typed)
```

This form is used internally by operators like
[`Lift`](@ref CTFlows.DifferentialGeometry.Lift) that produce typed data objects
programmatically.

---

## See also

- [`CTFlows.Data.VectorField`](@ref), [`CTFlows.Data.Hamiltonian`](@ref), [`CTFlows.Data.HamiltonianVectorField`](@ref) — concrete data types.
- [`CTFlows.Data.AbstractVectorField`](@ref), [`CTFlows.Data.AbstractHamiltonian`](@ref), [`CTFlows.Data.AbstractHamiltonianVectorField`](@ref) — abstract supertypes.
- [Traits](traits.md) — the three trait axes and call-signature tables.
