# CTFlows.jl

```@meta
CurrentModule = CTFlows
```

The `CTFlows.jl` package is part of the [control-toolbox ecosystem](https://github.com/control-toolbox).
It provides the **flow integration layer** for systems and optimal control problems:

- **abstract types** describing systems, flows, and the strategy families that build and integrate them;
- **pipeline functions** (`build_system`, `build_flow`, `integrate`, `build_solution`, `solve`) operating uniformly on the abstractions;
- a concrete [`Flow`](@ref) wrapper combining an [`AbstractSystem`](@ref) with an [`AbstractODEIntegrator`](@ref).

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
    sol      = CTFlows.Pipelines.solve(flow, (0.0, 1.0), x0)
    ```

    Or bring a single submodule into scope with `using CTFlows.Submodule`:

    ```julia
    using CTFlows.Pipelines
    sol = solve(flow, (0.0, 1.0), x0)
    ```

## Architecture overview

CTFlows organises its code along three concerns, mirroring the CTSolvers three-layer pattern:

| Layer | Submodule | Purpose |
|---|---|---|
| **Objects** | [`Systems`](@ref CTFlows.Systems), [`Flows`](@ref CTFlows.Flows) | what is acted upon (a fully-assembled system, or a callable flow) |
| **Strategy families** | [`Modelers`](@ref CTFlows.Modelers), [`Integrators`](@ref CTFlows.Integrators), [`ADBackends`](@ref CTFlows.ADBackends) | each `<: CTSolvers.Strategies.AbstractStrategy` |
| **Actions / pipelines** | [`Pipelines`](@ref CTFlows.Pipelines) | `build_system`, `build_flow`, `integrate`, `build_solution`, `solve` |

The shared [`Core`](@ref CTFlows.Core) submodule is reserved for cross-submodule utilities.

## Contracts at a glance

### `AbstractSystem`

A fully-assembled object that can be integrated. Required methods:

- `rhs!(system) → (du, u, p, t) -> nothing`
- `dimensions(system) → NamedTuple` (e.g. `(n_x=…, n_p=…, n_u=…, n_v=…)`)
- `build_solution(system, ode_sol)` — packages the raw ODE trajectory

### `AbstractFlow`

A callable combining a system and an integrator. Required methods:

- `(flow)(t0, x0, tf)` — state integration
- `(flow)(t0, x0, p0, tf)` — state + costate integration
- `system(flow)`, `integrator(flow)` — accessors

### Strategy families

All inherit from `CTSolvers.Strategies.AbstractStrategy` and gain its full contract
(`id`, `metadata`, `options`, `Base.show`, `describe`, …).

- [`AbstractFlowModeler`](@ref CTFlows.Modelers.AbstractFlowModeler):
  callable `(modeler)(input, ad_backend) → AbstractSystem`
- [`AbstractODEIntegrator`](@ref CTFlows.Integrators.AbstractODEIntegrator):
  callable `(integrator)(ode_problem, tspan) → ode_sol`
- [`AbstractADBackend`](@ref CTFlows.ADBackends.AbstractADBackend):
  `ctgradient(backend, f, x)`, `ctjacobian(backend, f, x)`

## Pipelines at a glance

```julia
# atomic
system = build_system(input, modeler, ad_backend)
flow   = build_flow(system, integrator)

# pipeline alias
flow   = build_flow(input, modeler, integrator, ad_backend)

# integration
traj   = integrate(flow, t0, x0, tf)             # state-only
traj   = integrate(flow, t0, x0, p0, tf)         # state + costate

# solve = integrate + build_solution
sol    = solve(flow, (t0, tf), x0)
sol    = solve(flow, (t0, tf), x0, p0)
```

## Status

The current scaffold provides abstract types, contracts with `NotImplemented`
defaults, the concrete `Flow` wrapper, and the pipeline functions. Concrete
modelers, integrators, and AD backends are introduced incrementally in
later phases (see the [roadmap](https://github.com/control-toolbox/CTFlows.jl/blob/main/reports/roadmap.md)).
