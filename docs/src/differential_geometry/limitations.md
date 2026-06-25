# Limitations & configuration

```@meta
CurrentModule = CTFlows
```

This page collects the constraints of the [`CTFlows.DifferentialGeometry`](@ref
CTFlows.DifferentialGeometry) operators and the knobs available to configure them.

```@setup limits
using CTFlows
using CTFlows.DifferentialGeometry
using CTBase.Data
using CTBase.Traits
import DifferentiationInterface
```

## Limitations

### No in-place support

The operators are defined for **out-of-place** objects only. A field built with
`is_inplace=true` (mutability [`InPlace`](@ref CTBase.Traits.InPlace)) is rejected by
[`ad`](@ref CTFlows.DifferentialGeometry.ad) and [`∂ₜ`](@ref
CTFlows.DifferentialGeometry.∂ₜ) with a [`CTBase.Exceptions.NotImplemented`](@extref
CTBase) error. Reconstruct the field out-of-place before taking brackets or time
derivatives:

```julia
Xip = VectorField(x -> [x[2], -x[1]]; is_inplace=true)
ad(Xip, Xip)        # ❌ NotImplemented — ad is not defined for in-place fields
```

### No Lie operations on a Hamiltonian vector field

A [`HamiltonianVectorField`](@ref CTBase.Data.HamiltonianVectorField) lives on phase
space with signature `(x, p)`, not `(x)`, so it is **not** a valid operand for the Lie
bracket / Lie derivative, nor for the [`Lift`](@ref CTFlows.DifferentialGeometry.Lift).
Both raise [`CTBase.Exceptions.NotImplemented`](@extref CTBase):

```julia
Z = HamiltonianVectorField((x, p) -> [x[1], -p[1]]; is_autonomous=true)
ad(Z, Z)            # ❌ NotImplemented — signature is (x, p), not (x)
Lift(Z)             # ❌ NotImplemented — Z already lives on phase space
```

Use the underlying plain [`VectorField`](@ref CTBase.Data.VectorField) instead.

### Operands must share traits

[`ad`](@ref CTFlows.DifferentialGeometry.ad) (on two vector fields) and
[`Poisson`](@ref CTFlows.DifferentialGeometry.Poisson) (on two Hamiltonians) require their
operands to have the **same** time- and variable-dependence. A mismatch raises
[`CTBase.Exceptions.IncorrectArgument`](@extref CTBase):

```julia
Xa = VectorField(x -> [x[2], -x[1]];      is_autonomous=true)
Xt = VectorField((t, x) -> [x[2], -x[1]]; is_autonomous=false)
ad(Xa, Xt)          # ❌ IncorrectArgument — TD/VD mismatch between X and Y
```

The same rule is enforced by [`@Lie`](@ref CTFlows.DifferentialGeometry.@Lie); see
[The `@Lie` macro](lie_macro.md#Error-cases).

### Plain functions default to autonomous & fixed

A bare Julia `Function` carries no traits, so the operators assume it is autonomous and
fixed unless told otherwise via `is_autonomous` / `is_variable` (for `ad`, `Poisson`,
`Lift`) or the matching keywords of `@Lie`. When in doubt, wrap the function in a typed
[`VectorField`](@ref CTBase.Data.VectorField) / [`Hamiltonian`](@ref
CTBase.Data.Hamiltonian) so the traits are explicit and checked.

### Qualified access

`CTFlows` exports nothing at the package level. Reach the operators through the submodule,
either fully qualified or via `using`:

```@example limits
using CTFlows.DifferentialGeometry        # ad, Poisson, Lift, ∂ₜ, @Lie
CTFlows.DifferentialGeometry.ad           # also reachable fully qualified
```

## Configuration

### AD backend

`ad`, `Poisson` and `∂ₜ` differentiate through a pluggable backend. The default is built
on `DifferentiationInterface.jl` (with `ForwardDiff` under the hood) and **must be
loaded** for gradients/derivatives to be available:

```julia
import DifferentiationInterface   # activates the CTFlowsDifferentiationInterface extension
```

The global default backend is read and set with
[`dg_ad_backend`](@ref CTFlows.DifferentialGeometry.dg_ad_backend) /
[`dg_ad_backend!`](@ref CTFlows.DifferentialGeometry.dg_ad_backend!):

```julia
using ADTypes
DifferentialGeometry.dg_ad_backend!(AutoForwardDiff())   # set global default
DifferentialGeometry.dg_ad_backend()                     # query it
```

Every operator also accepts a per-call `ad_backend` keyword that overrides the global
default for that call only — including [`@Lie`](@ref CTFlows.DifferentialGeometry.@Lie)
via `ad_backend=…`:

```julia
ad(X, Y; ad_backend=AutoForwardDiff())
@Lie [X, Y] ad_backend=AutoForwardDiff()
```

### Code-generation prefixes

The [`@Lie`](@ref CTFlows.DifferentialGeometry.@Lie) macro expands to **fully qualified**
calls so that the generated code resolves regardless of the caller's module. Two prefixes
control this qualification:

- [`diffgeo_prefix`](@ref CTFlows.DifferentialGeometry.diffgeo_prefix) /
  [`diffgeo_prefix!`](@ref CTFlows.DifferentialGeometry.diffgeo_prefix!) — the module
  prefix used to reach `DifferentialGeometry` and `Traits` in expanded code (default
  `:CTFlows`).
- [`e_prefix`](@ref CTFlows.DifferentialGeometry.e_prefix) /
  [`e_prefix!`](@ref CTFlows.DifferentialGeometry.e_prefix!) — the module prefix used to
  reach the exception type thrown by the macro (default `:CTBase`).

These only matter when CTFlows is re-exported under a different name (for example by an
umbrella package): point the prefixes at the name under which the symbols are visible at
the macro call site.

```julia
DifferentialGeometry.diffgeo_prefix!(:OptimalControl)   # if reached via OptimalControl.*
DifferentialGeometry.e_prefix!(:OptimalControl)         # if exceptions are re-exported too
```

## See also

- [Differential geometry overview](index.md)
- [`ad`](@ref CTFlows.DifferentialGeometry.ad), [`Poisson`](@ref
  CTFlows.DifferentialGeometry.Poisson), [`Lift`](@ref
  CTFlows.DifferentialGeometry.Lift), [`∂ₜ`](@ref CTFlows.DifferentialGeometry.∂ₜ),
  [`@Lie`](@ref CTFlows.DifferentialGeometry.@Lie)
