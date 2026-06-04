# CTFlows.jl

```@meta
CurrentModule = CTFlows
```

`CTFlows.jl` is the **flow integration layer** of the
[control-toolbox ecosystem](https://github.com/control-toolbox). Given a dynamical
system — a vector field, a Hamiltonian, or a Hamiltonian vector field — it builds a
callable **flow** that integrates the system from any initial condition to any final
time, with a pluggable ODE solver and optional automatic differentiation.

!!! info "CTFlows in the ecosystem"
    **CTFlows** handles **integration**. For **modelling** optimal control problems see
    [CTModels.jl](https://github.com/control-toolbox/CTModels.jl); for **solving NLPs**
    see [CTSolvers.jl](https://github.com/control-toolbox/CTSolvers.jl); the umbrella
    package is [OptimalControl.jl](https://github.com/control-toolbox/OptimalControl.jl).

## Quick start

```julia
using CTFlows
using CTFlows.Data, CTFlows.Flows, CTFlows.Solutions
import OrdinaryDiffEqTsit5   # activates the SciML integrator extension

# 1. Wrap the dynamics
vf = Data.VectorField(x -> -x)          # autonomous, fixed, out-of-place

# 2. Build the flow
flow = Flows.Flow(vf; reltol=1e-8)

# 3. Integrate — point form (final state)
xf = flow(0.0, [1.0, 0.0], 1.0)

# 4. Integrate — trajectory form (full history)
sol = flow((0.0, 1.0), [1.0, 0.0])
t   = Solutions.time_grid(sol)
x   = Solutions.state(sol)              # callable: x(t) → state at time t
x(0.5)                                  # interpolate
```

!!! note "Qualified access"
    CTFlows exports nothing at the package level. Every symbol lives in a submodule
    (`CTFlows.Data`, `CTFlows.Flows`, …) and is reached via a qualified path or a
    `using CTFlows.SubModule` import.

## Architecture

CTFlows is organised as a four-layer pipeline:

```
Data → Systems → Integrators → Flows → Solutions
```

| Layer | Submodule | Key types |
|---|---|---|
| Data | [`CTFlows.Data`](@ref CTFlows.Data) | `VectorField`, `Hamiltonian`, `HamiltonianVectorField` |
| Systems | [`CTFlows.Systems`](@ref CTFlows.Systems) | `VectorFieldSystem`, `HamiltonianSystem` |
| Integrators | [`CTFlows.Integrators`](@ref CTFlows.Integrators) | `SciML` |
| Flows | [`CTFlows.Flows`](@ref CTFlows.Flows) | `StateFlow`, `HamiltonianFlow` |
| Solutions | [`CTFlows.Solutions`](@ref CTFlows.Solutions) | `VectorFieldSolution`, `HamiltonianVectorFieldSolution` |
| Multi-phase | [`CTFlows.MultiPhase`](@ref CTFlows.MultiPhase) | `MultiPhaseStateFlow` |
| Traits | [`CTFlows.Traits`](@ref CTFlows.Traits) | `Autonomous`, `Fixed`, `InPlace`, … |

The shortcut `Flows.Flow(data; opts...)` collapses all pipeline steps into a single
call. The explicit pipeline (`build_system` → `build_integrator` → `build_flow`)
gives full control over each step.

## Guides

| Guide | Contents |
|---|---|
| [Flows](flows/index.md) | End-to-end pipeline: data → systems → flows → solutions, traits, multi-phase |
| [Differential Geometry](differential_geometry/index.md) | Hamiltonian lift, Lie bracket, Poisson bracket, `@Lie` macro |
