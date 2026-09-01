# SciML flows

```@meta
CurrentModule = CTFlows
```

The `CTFlowsSciMLFlows` extension (activated by loading `SciMLBase`, e.g. through
any OrdinaryDiffEq solver package) lets `Flows.Flow` consume SciML objects
directly:

- `Flow(f::SciMLBase.AbstractODEFunction)` — wraps the function in a
  `SciMLFunctionSystem` and runs the standard pipeline, producing a `StateFlow`.
- `Flow(prob::SciMLBase.AbstractODEProblem)` — wraps the fully-assembled problem
  in a `SciMLProblemFlow`, bypassing the system-building pipeline (the problem
  already carries `u0`, `tspan` and `p`).

This is the bridge for users who already have SciML code and want the CTFlows call
interface (point/trajectory styles, configs, multi-phase concatenation).

```@setup flows_sciml
using CTFlows
using CTFlows: Flows
using CTFlows: Integrators
using SciMLBase
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5
```

---

## From an `ODEFunction`

```@example flows_sciml
f = SciMLBase.ODEFunction((du, u, p, t) -> du .= -p .* u)
flow = Flows.Flow(f; reltol=1e-10)
```

The resulting flow behaves like any `StateFlow`. SciML functions receive their
parameter through `p`, which CTFlows maps to the `variable` keyword:

```@repl flows_sciml
xf = flow(0.0, [1.0], 1.0; variable=2.0)   # ≈ exp(-2)
```

Trajectory calls work the same way, returning a `VectorFieldTrajectory` — plot it
directly once `Plots` is loaded:

```@example flows_sciml
sol = flow((0.0, 1.0), [1.0]; variable=2.0)
```

```@setup flows_sciml
using Plots
```

```@example flows_sciml
plot(sol)
```

!!! note "Traits of SciML-backed flows"
    A SciML function has the uniform `(du, u, p, t)` signature, so the wrapped
    flow is always `NonAutonomous` / `NonFixed`: pass the parameter via
    `variable` at call time.

---

## From an `ODEProblem`

A problem already bundles the dynamics, initial condition, time span, and
parameter. `Flows.Flow` wraps it in a `SciMLProblemFlow`:

```@example flows_sciml
prob = SciMLBase.ODEProblem((du, u, p, t) -> du .= -p .* u, [1.0], (0.0, 1.0), 2.0)
pflow = Flows.Flow(prob; reltol=1e-10)
```

`SciMLProblemFlow` supports three call modes:

```@repl flows_sciml
result = pflow();                       # no-arg: solve the problem as-is
Integrators.final_state(result)
xf = pflow(0.5, [2.0], 2.0; variable=3.0)   # point call: remake, final state
result = pflow((0.5, 2.0), [2.0]; variable=3.0);  # trajectory call: remake, full result
Integrators.times(result)[end]
```

Point and trajectory calls go through `SciMLBase.remake`, replacing `u0`, `tspan`
and (when `variable` is given) `p` before solving. The no-arg and trajectory calls
return an `AbstractIntegrationResult` — use `Integrators.times`,
`Integrators.evaluate_at` and `Integrators.final_state` to inspect it (see
[Trajectories](trajectories.md#low-level-integration-result)).

---

## See also

- [`CTFlowsSciMLFlows.SciMLProblemFlow`](@ref), [`CTFlowsSciMLFlows.SciMLFunctionSystem`](@ref) — the extension types.
- [`CTFlows.Flows.Flow`](@ref) — the constructor family.
- [`CTSolvers.Integrators.times`](@extref), [`CTSolvers.Integrators.evaluate_at`](@extref), [`CTSolvers.Integrators.final_state`](@extref) — result accessors.
- [Integrating](integrating.md) — call styles and integrator options.
