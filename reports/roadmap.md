# Roadmap

A major refactoring is planned. The simplest approach is to start from scratch, setting aside the existing code and tests, and then rebuild everything following the roadmap below.

## API and Accessors

- **Getters for `H` and `\vec{H}`**: provide accessors to retrieve the Hamiltonian $H$ and the Hamiltonian vector field $\vec{H}$ from a flow. See [issue #185](https://github.com/control-toolbox/CTFlows.jl/issues/185).
- **Mandatory named variable argument**: for a flow built on an OCP with a variable, the variable must be supplied via a keyword argument when calling the flow. See [issue #183](https://github.com/control-toolbox/CTFlows.jl/issues/183).
- **Input validation at flow call**: at the beginning of a flow call, check that user-provided functions (e.g. the control) define the expected methods on the intended arguments. This should verify the autonomous vs. non-autonomous and variable vs. non-variable cases.

## Integrators and Solvers

- **Pluggable integrator backends**: the flow should be usable by simply loading a basic integrator such as `OrdinaryDiffEqTsit5.jl`. `Tsit5` will be the default solver, and the solver should be switchable via a keyword argument together with an additional `using`.
- **GPU support**: ensure the flow works on GPU, and add dedicated tests.

## Flow Construction

- **Multi-phase flows for concatenation**: to concatenate flows, introduce a multi-phase flow concept. The concatenation is restricted to flows built from the same OCP. **Note**: Multi-phase design is deferred to a later phase. The current implementation focuses on single-phase flows with abstract types and contract testing. Multi-phase flows will require additional types (e.g., `MultiPhaseSystem`, `MultiPhaseFlow`) and concatenation logic. See the [design document](./design.md) for the planned multi-phase architecture.
- **Closed- and open-loop encapsulation**: support flows built by encapsulating `DynClosedLoop`, `ClosedLoop`, and `OpenLoop`. See [issue #134](https://github.com/control-toolbox/CTFlows.jl/issues/134), [discussion #144](https://github.com/control-toolbox/CTFlows.jl/discussions/144), and the [review document](https://github.com/control-toolbox/CTFlows.jl/blob/134-dev-add-flow-for-open-closed-loop-control/review.md).
- **Flows on generic objects**: consider whether to support creating a flow directly from a `Hamiltonian`, an `ODEProblem`, or an `ODEFunction`.
- **Flow on a control-free OCP**: keep the ability to build a flow on an OCP that has no control (a `ControlFreeModel`). See `ext/optimal_control_problem.jl`.
- **Augmented flow**: keep the notion of augmented Hamiltonian flow, i.e. the system extended with the costate equation $dp_v/dt = -\partial H/\partial v$ for the dual variable associated with the OCP variable $v$. See `rhs_augmented` in `ext/hamiltonian.jl`.
- **Implicit control and DAE**: support implicit control formulations and DAE systems. See [issue #46](https://github.com/control-toolbox/CTFlows.jl/issues/46).

## Outputs

- **Return the dual variable**: when available, the flow should return the dual variable. See [issue #103](https://github.com/control-toolbox/CTFlows.jl/issues/103).
- **Correct handling of the flow derivative**: See [issue #93](https://github.com/control-toolbox/CTFlows.jl/issues/93).

## Differential Geometry

- **Introduce `ad`**: restructure the differential geometry code by introducing `ad`, which will replace work already started. Care is required because other modifications have already been made in `differential_geometry.jl`. The code should probably be organized as a module with several files, following the structure of [`CTSolvers.jl`](https://github.com/control-toolbox/CTSolvers.jl/blob/main/src/CTSolvers.jl) and its submodules. Relevant references:
  - [Differential geometry guide (v0.9.0)](https://github.com/control-toolbox/CTFlows.jl/blob/release/v0.9.0/docs/src/differential-geometry-guide.md)
  - [`differential_geometry.jl` (v0.9.0)](https://github.com/control-toolbox/CTFlows.jl/blob/release/v0.9.0/src/differential_geometry.jl)
  - [`test_differential_geometry.jl` (v0.9.0)](https://github.com/control-toolbox/CTFlows.jl/blob/release/v0.9.0/test/test_differential_geometry.jl)
  - [`utils.jl` (v0.9.0)](https://github.com/control-toolbox/CTFlows.jl/blob/release/v0.9.0/src/utils.jl)
- **`Lift` must return a function**: the `Lift` of a function must itself return a function. See [issue #99](https://github.com/control-toolbox/CTFlows.jl/issues/99).
- **Exception handling in `@Lie`**: ensure proper exception handling inside the `@Lie` macro. See [issue #94](https://github.com/control-toolbox/CTFlows.jl/issues/94).

## Strategies Architecture

- **Strategy families**: create strategy families (in the CTSolvers sense) and strategies for modeling and solving a flow or a system. This will require defining a contract for strategy families. References:
  - [Implementing a strategy](https://control-toolbox.org/CTSolvers.jl/stable/guides/implementing_a_strategy.html)
  - [Strategy parameters](https://control-toolbox.org/CTSolvers.jl/stable/guides/strategy_parameters.html)
  - [Implementing a solver](https://control-toolbox.org/CTSolvers.jl/stable/guides/implementing_a_solver.html)
  - [Implementing a modeler](https://control-toolbox.org/CTSolvers.jl/stable/guides/implementing_a_modeler.html)
- **High-level vs. atomic API**: either provide a single `solve` method, or follow the CTSolvers approach with atomic methods that amount to calling a strategy on the object itself (e.g. solving an NLP with a solver, see [`common_solve_api.jl`](https://github.com/control-toolbox/CTSolvers.jl/blob/main/src/Solvers/common_solve_api.jl)). The same pattern can be applied to retrieving a model or discretizing a problem. There is always a functional level and an object level: at the functional level, when several strategies must be combined, a high-level "recipe" is exposed, which progressively drops down to atomic calls. See [high-level API](https://github.com/control-toolbox/CTSolvers.jl/blob/ff6e57d3dd598a4143b8f2bf0a85d5fa4c264c92/src/Solvers/common_solve_api.jl#L45-L62) and [low-level API](https://github.com/control-toolbox/CTSolvers.jl/blob/ff6e57d3dd598a4143b8f2bf0a85d5fa4c264c92/src/Solvers/common_solve_api.jl#L87-L91).

## Tests and Documentation

- **Revamp tests and documentation** following the CTBase guides:
  - [Test runner guide](https://control-toolbox.org/CTBase.jl/stable/guide/test-runner.html)
  - [API documentation guide](https://control-toolbox.org/CTBase.jl/stable/guide/api-documentation.html)

---

April 29th, 2026

Actually, we need only one strategy family which will be `AbstractIntegrator`. We will use it to model and solve flows. When calling a flow, we have two possibilities:

- `xf[, pf] = f(t0, x0[, p0], tf)`
- `sol = f((t0, tf), x0[, p0])`

where `sol` is a solution object that contains the trajectory and possibly the costate as functions of time. We will call `config` either `(t0, x0[, p0], tf)` or `((t0, tf), x0[, p0])`. We could imagine having a struct representing these two different config to dispatch the calls.

So, we will have:

```julia
function solve(system, config, integrator)
  f = build_flow(system, integrator)
  return f(config)
end
```

where `integrator` is a strategy, `(system, config)` is the object and `solve` is the action, according to the pattern:

```julia
action(object, strategies...) → result
```

- The **object** is the thing being acted upon — a problem, a system, a model.
- The **strategies** are the configured descriptors that control *how* the action is carried out.
- The **result** is a new object: a solution, a flow, a trajectory, …

We will have:

```julia
function (flow::AbstractFlow)(config)
    r = integrate(system(flow), config, integrator(flow))
    s = build_solution(r, flow, config)
    return s
end
```

To build a system from a VectorField, a Hamiltonian, an OCP with a control law, etc, we will have a function `build_system` that takes the object and returns a system.

```julia
system = build_system(object)
```

When needed, we will have to pass the AD backend to `build_system`:

```julia
system = build_system(object, ad_backend)
```

but it is not always needed. For instance, for a VectorField, the AD backend is not needed. Here, there is no strategy involved.

So we need:

- `build_system(object)` for objects that do not need an AD backend
- `build_system(object, ad_backend)` for objects that need an AD backend
- we need an abstract type for the system
- we need an abstract type for the flow
- we need an abstract type for the solution. We have also CTModels.Solution for a solution of an optimal control problem.
- we need to define the family `AbstractIntegrator` for the integrator strategy and concrete implementations like `SciMLIntegrator`.
- `integrate(system, config, integrator)` is the action that integrates the system with the given configuration and integrator.
- `build_solution(result, flow, config)` is the action that builds a solution from the result of the integration.