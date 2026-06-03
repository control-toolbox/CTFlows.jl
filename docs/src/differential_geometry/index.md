# Differential geometry

```@meta
CurrentModule = CTFlows
```

The [`CTFlows.DifferentialGeometry`](@ref CTFlows.DifferentialGeometry) submodule provides the
differential-geometric operators used in geometric optimal control: the Hamiltonian
**lift**, the **Lie derivative** and **Lie bracket** of vector fields, the **Poisson
bracket** of Hamiltonians, and the **partial time derivative**. All of these are also
available through a single convenience macro, [`@Lie`](@ref).

This guide is aimed at advanced users and developers. Each operator is presented first
with its mathematical definition, then with runnable examples — both on plain Julia
`Function`s and on the typed objects ([`VectorField`](@ref CTFlows.Data.VectorField),
[`Hamiltonian`](@ref CTFlows.Data.Hamiltonian)) — across the various trait combinations
(autonomous or not, fixed or not).

## Reading order

| Page | Operator | Mathematical object |
|---|---|---|
| [Hamiltonian lift](lift.md) | [`Lift`](@ref CTFlows.DifferentialGeometry.Lift) | ``H(x,p) = \langle p, X(x)\rangle`` |
| [Lie derivative & bracket](lie_derivative_bracket.md) | [`ad`](@ref CTFlows.DifferentialGeometry.ad) | ``X\cdot f`` and ``[X,Y]`` |
| [Poisson bracket](poisson.md) | [`Poisson`](@ref CTFlows.DifferentialGeometry.Poisson) | ``\{H,G\}`` |
| [Partial time derivative](time_derivative.md) | [`∂ₜ`](@ref CTFlows.DifferentialGeometry.∂ₜ) | ``\partial_t`` |
| [The `@Lie` macro](lie_macro.md) | [`@Lie`](@ref CTFlows.DifferentialGeometry.@Lie) | ``[\,\cdot\,]`` and ``\{\,\cdot\,\}`` |
| [Limitations & configuration](limitations.md) | — | constraints, AD backend, prefixes |

## Mathematical setting

We work on a state space ``\mathcal{X} \subseteq \mathbb{R}^n`` and its cotangent bundle
``T^*\mathcal{X}`` with canonical coordinates ``(x, p) \in \mathbb{R}^n \times \mathbb{R}^n``.

- A **vector field** is a map ``X : \mathcal{X} \to \mathbb{R}^n``.
- A **Hamiltonian** is a scalar map ``H : T^*\mathcal{X} \to \mathbb{R}``, ``(x,p) \mapsto H(x,p)``.

The operators may additionally depend on **time** ``t`` and on a **variable parameter**
``v`` (a decision variable, e.g. a free final time or a design parameter). Which of these
extra arguments appear is encoded by the trait system below.

## Traits and call signatures

Every typed object carries up to three traits that determine its **call signature**:

| Trait | Values | Meaning |
|---|---|---|
| Time dependence | `Autonomous` / `NonAutonomous` | does the object depend on time ``t``? |
| Variable dependence | [`Fixed`](@ref CTFlows.Traits.Fixed) / [`NonFixed`](@ref CTFlows.Traits.NonFixed) | does it depend on a variable ``v``? |
| Mutability | [`OutOfPlace`](@ref CTFlows.Traits.OutOfPlace) / [`InPlace`](@ref CTFlows.Traits.InPlace) | does it allocate, or write into a buffer? |

The time/variable traits give four call signatures. For a **vector field** ``X``:

| Time dependence | Variable dependence | Signature |
|---|---|---|
| `Autonomous` | `Fixed` | `X(x)` |
| `NonAutonomous` | `Fixed` | `X(t, x)` |
| `Autonomous` | `NonFixed` | `X(x, v)` |
| `NonAutonomous` | `NonFixed` | `X(t, x, v)` |

For a **Hamiltonian** ``H`` the costate `p` follows the state `x`:

| Time dependence | Variable dependence | Signature |
|---|---|---|
| `Autonomous` | `Fixed` | `H(x, p)` |
| `NonAutonomous` | `Fixed` | `H(t, x, p)` |
| `Autonomous` | `NonFixed` | `H(x, p, v)` |
| `NonAutonomous` | `NonFixed` | `H(t, x, p, v)` |

!!! warning "Out-of-place only"

    The differential-geometry operators are defined for `OutOfPlace` objects only.
    Passing an `InPlace` vector field raises an error — see
    [Limitations & configuration](limitations.md).

## Qualified access

`CTFlows` exports nothing at the package level: every symbol lives in a submodule and must
be reached through a qualified path. Throughout this guide we bring the relevant
submodules into scope:

```@example dg
using CTFlows
using CTFlows.DifferentialGeometry   # Lift, ad, Poisson, ∂ₜ, @Lie
using CTFlows.Data                   # VectorField, Hamiltonian, HamiltonianVectorField
using CTFlows.Traits                 # Autonomous, NonAutonomous, Fixed, NonFixed, OutOfPlace
nothing # hide
```

Automatic differentiation is provided by a pluggable backend. The default relies on
`DifferentiationInterface.jl`, which must be loaded for [`ad`](@ref
CTFlows.DifferentialGeometry.ad), [`Poisson`](@ref CTFlows.DifferentialGeometry.Poisson)
and [`∂ₜ`](@ref CTFlows.DifferentialGeometry.∂ₜ) to compute gradients and derivatives:

```@example dg
import DifferentiationInterface   # activates the AD backend extension
nothing # hide
```

See [Limitations & configuration](limitations.md) for how to select another backend.

## Notation summary

| Mathematics | Julia |
|---|---|
| Hamiltonian lift ``H = \langle p, X\rangle`` | [`Lift(X)`](@ref CTFlows.DifferentialGeometry.Lift) |
| Lie derivative ``X\cdot f = \nabla f \cdot X`` | [`ad(X, f)`](@ref CTFlows.DifferentialGeometry.ad) |
| Lie bracket ``[X, Y]`` | [`ad(X, Y)`](@ref CTFlows.DifferentialGeometry.ad), `@Lie [X, Y]` |
| Poisson bracket ``\{H, G\}`` | [`Poisson(H, G)`](@ref CTFlows.DifferentialGeometry.Poisson), `@Lie {H, G}` |
| Partial time derivative ``\partial_t`` | [`∂ₜ(·)`](@ref CTFlows.DifferentialGeometry.∂ₜ) |
