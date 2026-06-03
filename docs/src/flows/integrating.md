# Integrating

```@meta
CurrentModule = CTFlows
```

Once a flow is built, calling it integrates the underlying ODE. There are two call
styles depending on whether you need the **full trajectory** or just the **final state**.

```@setup flows_integrating
using CTFlows
using CTFlows.Data
using CTFlows.Traits
using CTFlows.Systems
using CTFlows.Integrators
using CTFlows.Flows
using CTFlows.Solutions
using CTFlows.Configs
import OrdinaryDiffEqTsit5

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
flow((t0, tf), x0)          # returns VectorFieldSolution
hflow((t0, tf), x0, p0)     # returns HamiltonianVectorFieldSolution
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

## Configuration objects

The convenience call signatures above internally build **configuration objects**
that bundle the integration parameters. You can also construct them explicitly and
pass them to `Flows._invoke_flow`:

| Config type | Usage | Arguments |
|---|---|---|
| `StatePointConfig` | state final value | `(t0, x0, tf)` |
| `StateTrajectoryConfig` | state full trajectory | `(tspan, x0)` |
| `HamiltonianPointConfig` | state+costate final value | `(t0, x0, p0, tf)` |
| `HamiltonianTrajectoryConfig` | state+costate trajectory | `(tspan, x0, p0)` |

```@example flows_integrating
cfg = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0, 0.0])
Configs.tspan(cfg)
```

Configuration objects separate *what to integrate* from *how to integrate* (the flow).
This separation is useful when the same config must be passed to several flows.

---

## Integrator options {#integrator-options}

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

The `SciML` strategy wraps SciML's `solve` under the
[`CTSolvers`](https://github.com/control-toolbox/CTSolvers.jl) option system. The
`build_problem` / `solve_problem` separation lets the same problem definition be
re-solved with different parameters efficiently.

```@example flows_integrating
integ = Integrators.build_integrator(; reltol=1e-8)
typeof(integ)
```

---

## API reference

```@docs
CTFlows.Configs.StatePointConfig
CTFlows.Configs.StateTrajectoryConfig
CTFlows.Configs.HamiltonianPointConfig
CTFlows.Configs.HamiltonianTrajectoryConfig
CTFlows.Configs.tspan
CTFlows.Configs.initial_state
CTFlows.Configs.initial_costate
CTFlows.Integrators.SciML
CTFlows.Integrators.build_integrator
CTFlows.Integrators.AbstractIntegrator
```
