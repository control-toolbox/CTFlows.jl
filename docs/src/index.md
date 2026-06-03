# CTFlows.jl

```@meta
CurrentModule = CTFlows
```

The `CTFlows.jl` package is part of the [control-toolbox ecosystem](https://github.com/control-toolbox).
It provides the **flow integration layer** for systems and optimal control problems:

- **abstract types** describing systems, flows, and the strategy families that build and integrate them;
- **pipeline functions** (`build_system`, `build_flow`, `integrate`, `build_solution`, `solve`) operating uniformly on the abstractions;
- a concrete [`Flow`](@ref) wrapper combining an [`AbstractSystem`](@ref) with an [`AbstractIntegrator`](@ref).

!!! info "CTFlows in the ecosystem"

    **CTFlows** focuses on **integrating** systems (vector fields, OCP-derived Hamiltonian flows, …)
    via pluggable strategies (modelers, integrators, AD backends).
    For **modelling** optimal control problems, see [CTModels.jl](https://github.com/control-toolbox/CTModels.jl);
    for **solving NLPs**, see [CTSolvers.jl](https://github.com/control-toolbox/CTSolvers.jl);
    the umbrella package is [OptimalControl.jl](https://github.com/control-toolbox/OptimalControl.jl).

!!! warning "Qualified API access"

    CTFlows exports nothing at the package level. All public symbols live in submodules and must
    be accessed via qualified paths.

    ```julia
    using CTFlows
    sys      = CTFlows.Systems.AbstractSystem      # abstract type
    flow     = CTFlows.Flows.Flow(system, integ)    # concrete flow
    sol      = CTFlows.Flows._invoke_flow(flow, config)     # integrate
    ```

    Or bring a single submodule into scope with `using CTFlows.Submodule`:

    ```julia
    using CTFlows.Flows
    sol = _invoke_flow(flow, config)
    ```

## Architecture overview

CTFlows organises its code into specialised submodules:

| Layer | Submodule | Purpose |
|---|---|---|
| **Utilities** | [`Common`](@ref CTFlows.Common) | shared types, traits, and configuration |
| **Data** | [`Data`](@ref CTFlows.Data) | vector field data structures with traits |
| **Objects** | [`Systems`](@ref CTFlows.Systems), [`Flows`](@ref CTFlows.Flows) | what is acted upon (a fully-assembled system, or a callable flow) |
| **Strategy families** | [`Integrators`](@ref CTFlows.Integrators) | `<: CTSolvers.Strategies.AbstractStrategy` |
| **Solutions** | [`Solutions`](@ref CTFlows.Solutions) | solution types and solution building |

## Contracts at a glance

### AbstractSystem contract

A fully-assembled object that can be integrated. Required methods:

- `rhs!(system) → (du, u, p, t) -> nothing` — returns the ODE right-hand side function

Traits (automatically supported):

- `time_dependence(system)` — returns `Autonomous` or `NonAutonomous`
- `variable_dependence(system)` — returns `Fixed` or `NonFixed`

### `AbstractFlow`

A callable combining a system and an integrator. Required methods:

- `system(flow)` — returns the associated `AbstractSystem`
- `integrator(flow)` — returns the associated `AbstractIntegrator`

Traits (delegated to system):

- `time_dependence(flow)`, `variable_dependence(flow)` — forwarded to the system

### Strategy families

All inherit from `CTSolvers.Strategies.AbstractStrategy` and gain its full contract
(`id`, `metadata`, `options`, `Base.show`, `describe`, …).

- [`AbstractIntegrator`](@ref CTFlows.Integrators.AbstractIntegrator):
  callable `(integrator)(system, config; variable=nothing) → ode_problem`

## API at a glance

```julia
# Build a flow from vector field data
using CTFlows.Data, CTFlows.Flows, CTFlows.Common

vf = Data.VectorField((t, x, v) -> x, Autonomous(), Fixed())
flow = Flows.Flow(vf; reltol=1e-8)

# Integrate using a configuration
config = Common.StateTrajectoryConfig((0.0, 1.0), [1.0, 0.0])
sol = Flows._invoke_flow(flow, config)

# Or point-to-point integration
config = Common.StatePointConfig((0.0, 1.0), [1.0, 0.0])
final_state = Flows._invoke_flow(flow, config)
```

## Status

The current implementation provides:

- Abstract types with traits (`AbstractSystem`, `AbstractFlow`, `AbstractIntegrator`)
- Concrete implementations (`VectorField`, `VectorFieldSystem`, `Flow`, `VectorFieldSolution`)
- Integration pipeline via `Flows.call` with configuration objects
- SciML integrator strategy

Future phases will add additional integrator strategies and solution types
(see the [roadmap](https://github.com/control-toolbox/CTFlows.jl/blob/main/reports/roadmap.md)).
