# Integrating

```@meta
CurrentModule = CTFlows
```

Once a flow is built, calling it integrates the underlying ODE. There are two call
styles depending on whether you need the **full trajectory** or just the **final state**.

```@setup flows_integrating
using CTFlows
using CTBase.Data
using CTBase.Traits
using CTFlows.Systems
using CTFlows.Integrators
using CTFlows.Flows
using CTFlows.Trajectories
using CTFlows.Configs
import OrdinaryDiffEqTsit5
import ForwardDiff  # triggers the DifferentiationInterface ForwardDiff extension

vf = Data.VectorField(x -> -x)
flow = Flows.Flow(vf; reltol=1e-8)

hvf = Data.HamiltonianVectorField((x, p) -> (p, -x))
hflow = Flows.Flow(hvf; reltol=1e-10)
```

---

## Call styles

### Point integration — final state only

```julia
flow(t0, x0, tf)            # returns xf::Vector (StateFlow)
hflow(t0, x0, p0, tf)       # returns (xf, pf) (HamiltonianFlow)
```

```@example flows_integrating
x0 = [1.0, 0.0]
xf = flow(0.0, x0, 1.0)
```

```@example flows_integrating
p0 = [0.0, 1.0]
xf, pf = hflow(0.0, x0, p0, 1.0)
(xf, pf)
```

### Trajectory integration — full time history

```julia
flow((t0, tf), x0)          # returns VectorFieldTrajectory
hflow((t0, tf), x0, p0)     # returns HamiltonianVectorFieldTrajectory
```

```@example flows_integrating
sol = flow((0.0, 1.0), x0)
```

```@example flows_integrating
hsol = hflow((0.0, 1.0), x0, p0)
```

---

## Variable parameters

For a `NonFixed` flow, pass the variable ``v`` via the `variable` keyword:

```@example flows_integrating
vf_v = Data.VectorField((x, v) -> -v[1] .* x; is_variable=true)
flow_v = Flows.Flow(vf_v)

xf_v = flow_v(0.0, [1.0, 0.0], 1.0; variable=[2.0])
```

The `variable` argument is required when `is_variable(flow)` is `true`, and silently
ignored for `Fixed` flows.

---

## Variable costate

For a `NonFixed` `HamiltonianFlow`, pass `variable_costate=true` to also integrate the
augmented adjoint ``\dot{p}_v = -\partial H/\partial v`` (initialized at
``p_v(t_0) = 0``) alongside the state and costate. The point call then returns a triple
`(xf, pf, pvf)` instead of `(xf, pf)`:

```@example flows_integrating
h_v = Data.Hamiltonian((x, p, v) -> v[1] * p^2 / 2; is_variable=true)
hflow_v = Flows.Flow(h_v)

xf, pf, pvf = hflow_v(0.0, 1.0, 0.5, 1.0; variable=[2.0], variable_costate=true)
(xf, pf, pvf)
```

This is only available for point evaluation, and only when `variable` is provided
(`NonFixed` flows require it).

### Free times

The positional `tf` argument is the **evaluation time**; it is independent of the
`variable` value, even when a variable component *represents* a free initial or final
time. Passing `flow(t0, x0, p0, t1; variable=v)` with `t1 ≠ v` is valid.

When a variable component is a free time, the flow keeps integrating the same naive
adjoint — no special-casing — with the augmented costate started at ``p_v(t_0) = 0``
(the convention `variable_costate=true` always uses). This zero start is exactly what
makes the **mitigated** free-time transversality conditions valid: written at ``t_f``,
they are

```math
p_{t_0}(t_f) = -H(t_0, x_0, p_0, v), \qquad p_{t_f}(t_f) = H(t_f, x_f, p_f, v),
```

where `H` is obtained from [`CTFlows.Systems.hamiltonian`](@ref)`(flow)`; a nonzero
``p_v(t_0)`` would shift both sides. The shooting method writes these conditions by hand.

See `test/suite/flows/test_variable_costate_free_time.jl` for worked shooting residuals
built on this ``p_v`` mechanism (free ``t_0``, free ``t_f``, and both at once). The
Goddard tests (`test/suite/integration/test_goddard.jl`) instead close their free final
time with the classical ``H \equiv 0`` condition — not the ``p_v`` adjoint. This settles
issues [#231](https://github.com/control-toolbox/CTFlows.jl/issues/231) and
[#183](https://github.com/control-toolbox/CTFlows.jl/issues/183).

---

## Hamiltonian / pseudo-Hamiltonian getters

Any Hamiltonian flow exposes its underlying Hamiltonian and — when the flow was built
from a control law — its pseudo-Hamiltonian, control law, and their gradients:

```@example flows_integrating
Systems.hamiltonian(hflow_v)          # the callable H(t, x, p, v)
Systems.hamiltonian_gradient(hflow_v) # functor: (t, x, p, v) -> (∂H/∂x, ∂H/∂p)
Systems.variable_gradient(hflow_v)    # functor: (t, x, p, v) -> ∂H/∂v
```

`Systems.pseudo_hamiltonian`, `Systems.control_law`, `Systems.pseudo_hamiltonian_gradient`
and `Systems.pseudo_variable_gradient` are available on flows built from a
pseudo-Hamiltonian (or an OCP) and a control law — see [Control laws](control_laws.md).
Calling them on a flow with no associated control law throws `IncorrectArgument`.

---

## Configuration objects

The convenience call signatures above internally build **configuration objects**
that bundle the integration parameters. You can also construct them explicitly and
pass them to `Flows._invoke_flow`:

| Config type | Usage | Arguments |
|---|---|---|
| `StateEndPointConfig` | state final value | `(t0, x0, tf)` |
| `StateTrajectoryConfig` | state full trajectory | `(tspan, x0)` |
| `HamiltonianEndPointConfig` | state+costate final value | `(t0, x0, p0, tf)` |
| `HamiltonianTrajectoryConfig` | state+costate trajectory | `(tspan, x0, p0)` |
| `AugmentedHamiltonianEndPointConfig` | state+costate+variable-costate final value | `(t0, x0, p0, pv0, tf)` |

```@example flows_integrating
cfg = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0, 0.0])
Configs.tspan(cfg)
```

Configuration objects separate *what to integrate* from *how to integrate* (the flow).
This separation is useful when the same config must be passed to several flows.

---

## [Integrator options](@id integrator-options)

Options are passed as keyword arguments to `Flows.Flow(data; opts...)` or
`Integrators.build_integrator(; opts...)`.

The default integrator is **SciML** backed by `OrdinaryDiffEqTsit5` (loaded when
`import OrdinaryDiffEqTsit5` appears in your session).

### Common options

| Option | Default | Description |
|---|---|---|
| `reltol` | `1e-6` | Relative tolerance |
| `abstol` | `1e-8` | Absolute tolerance |
| `alg` | `Tsit5()` | ODE algorithm (any SciML algorithm) |
| `saveat` | `[]` | Extra time points to save |
| `dense` | `true` | Dense output for interpolation |

```@example flows_integrating
# Tighter tolerances
flow_tight = Flows.Flow(vf; reltol=1e-12, abstol=1e-12)

# Different algorithm (requires the matching OrdinaryDiffEq package to be loaded)
# using OrdinaryDiffEqRosenbrock
# flow_rodas = Flows.Flow(vf; alg=Rodas4())
```

### Unsafe mode

By default, a `SolverFailure` exception is thrown if the ODE solver returns
a non-success retcode. Pass `unsafe=true` to suppress this check:

```@example flows_integrating
xf_unsafe = flow(0.0, [1.0, 0.0], 1.0; unsafe=true)
```

Use `unsafe=true` inside shooting methods or optimisation loops where you want to
handle failures gracefully instead of relying on exceptions.

---

## SciML integrator internals

The `SciML` integrator strategy itself — its options, construction, and the
`CommonSolve.solve` method that wraps SciML's `solve` — is provided by
[`CTSolvers.Integrators`](https://github.com/control-toolbox/CTSolvers.jl). CTFlows
contributes only the *glue*: `Integrators.build_problem` turns a system and a
configuration into a SciML `ODEProblem`, and `Integrators.build_options` selects the
integrator's cached option bundle for the configuration. Integration is then
`CommonSolve.solve(prob, integ)`. Keeping `build_problem` separate from the solve step
lets the same problem definition be re-solved with different parameters efficiently.

```@example flows_integrating
integ = Integrators.build_integrator(; reltol=1e-8)
typeof(integ)
```

---

## See also

- [`CTFlows.Configs.StateEndPointConfig`](@ref), [`CTFlows.Configs.StateTrajectoryConfig`](@ref) — state configuration objects.
- [`CTFlows.Configs.HamiltonianEndPointConfig`](@ref), [`CTFlows.Configs.HamiltonianTrajectoryConfig`](@ref) — Hamiltonian configuration objects.
- [`CTFlows.Configs.tspan`](@ref), [`CTFlows.Configs.initial_state`](@ref), [`CTFlows.Configs.initial_costate`](@ref) — configuration accessors.
- [`CTFlows.Integrators.build_problem`](@ref), [`CTFlows.Integrators.build_options`](@ref) — the CTFlows-side integrator glue.
- [`CTSolvers.Integrators.SciML`](@extref), [`CTSolvers.Integrators.build_integrator`](@extref), [`CTSolvers.Integrators.AbstractIntegrator`](@extref) — the integrator strategy (provided by CTSolvers).
