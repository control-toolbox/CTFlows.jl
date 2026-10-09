# Breaking Changes

This file lists breaking and near-breaking changes in CTFlows.jl since the last
stable baseline, [0.8.23](CHANGELOG.md#0823---2026-04-06).

## Unreleased

- **Time grid of a trajectory with `saveat` and `dense=false`** ([#434](https://github.com/control-toolbox/CTFlows.jl/issues/434)):
  it is now the `saveat` grid only; it used to be the union of the `saveat` times and of
  every solver step (the trajectory options forced `save_everystep=true`). Pass
  `save_everystep=true` explicitly to get the union back. With the default (dense)
  output, `saveat` used to crash on a trajectory call; it now returns the `saveat` grid.
- **Memory with `saveat`:** a dense trajectory with `saveat` keeps the full dense
  interpolant (that is what makes it accurate between the grid points). To store only
  the grid values, pass `dense=false` as well.
- **Merged multi-phase result type:** `Integrators.merge` of SciML segments returns a
  `CTSolvers.Integrators.PiecewiseIntegrationResult` (CTSolvers ≥ 0.6) instead of a
  single flattened `SciMLIntegrationResult`. Code using only the `Integrators` accessors
  (`times`, `evaluate_at`, `final_state`, `status`, `successful`) is unaffected; code
  reading the internal `ode_sol` of a merged result is not.
- **Trajectory configs gain a `grid` field/type parameter**
  (`StateTrajectoryConfig{TS,X0,G}`, `HamiltonianTrajectoryConfig{TS,X0,P0,G}`). The
  public constructors `StateTrajectoryConfig(tspan, x0)` / `HamiltonianTrajectoryConfig(tspan, x0, p0)`
  are unchanged; only the explicit-parameter inner constructors changed.

## 0.18.1

Stable release of the 0.18 line. **No breaking change since 0.18.0-beta.** Users
upgrading from the previous stable release (0.17.2) should read the 0.18.0-beta note
below: everything is additive except the internal `TrajectoryPlots` relocation.

## Non-breaking note (0.18.0-beta)

- **Makie plotting backend for trajectories** ([#414](https://github.com/control-toolbox/CTFlows.jl/issues/414)):
  a new `CTFlowsMakie` weak-dependency extension adds `Makie.plot` / `Makie.plot!` for
  the trajectory types. All additive — no public signature, type or name changed; the
  `Plots.plot(traj)` path is unchanged (frozen by `test_plots_extension.jl`).
- **`TrajectoryPlots` case layer moved from the `CTFlowsPlots` extension into a `src`
  submodule**, `CTFlows.TrajectoryPlots` (mirror of `CTModels.PlotCase`). Only code
  reaching those *internal* helpers through
  `Base.get_extension(CTFlows, :CTFlowsPlots).TrajectoryPlots` is affected; use
  `CTFlows.TrajectoryPlots` instead. `ext/CTFlowsPlots/` (folder) is replaced by
  `ext/CTFlowsPlots.jl`.

  ```julia
  # Before
  const TP = Base.get_extension(CTFlows, :CTFlowsPlots).TrajectoryPlots

  # After
  using CTFlows: TrajectoryPlots
  ```

### Compatibility

- Needs **`CTBase` ≥ 0.30.1-beta** (`Plotting.MakieBackend` at parity with the Plots
  backend) and **`CTModels` ≥ 0.19.1-beta**. `[compat]` moves to `CTBase = "0.30"` /
  `CTModels = "0.19"`; `Makie = "0.24"` is a new weak dependency. Requires
  `CTLie` ≥ 0.2.1-beta and `CTSolvers` ≥ 0.5.6-beta (their compat betas accepting the
  same CTBase / CTModels).

## 0.17.0

### `OpenLoop` laws now require time in the control function

`CTBase.Data.OpenLoop` is now unconditionally non-autonomous. Control functions
must accept `t` as their first argument.

```julia
# Before
law = CTBase.Data.OpenLoop(() -> 1.0)

# After
law = CTBase.Data.OpenLoop(t -> 1.0)
```

This follows the CTBase control-law contract and avoids silently ignoring time.

## 0.16.0-beta

### `Flow(::VectorField)` and `Flow(::ODEFunction)` use scalar values for 1-D states

Length-one vector states are now coerced to scalars for these flow constructors,
including point and trajectory calls.

```julia
# Before
x0 = [1.0]
xf = flow(t0, x0, tf)  # a length-one vector

# After
x0 = 1.0
xf = flow(t0, x0, tf)  # a scalar
```

`Flow(::ODEProblem)` is unaffected. See the shape contract documentation.

### `Systems` gradient accessors use `get_*` names

The accessor names were changed to avoid colliding with CTBase differentiation
functions.

```julia
# Before
Systems.hamiltonian_gradient(sys)

# After
Systems.get_hamiltonian_gradient(sys)
```

The same migration applies to `variable_gradient`, `pseudo_hamiltonian_gradient`,
and `pseudo_variable_gradient`.

## 0.15.0-beta

### `Flow(vf; ad_backend=...)` is rejected for AD-free flows

The keyword is no longer silently ignored when the flow has no AD path.
Remove the keyword or use an AD-enabled flow when an AD backend is required.

```julia
# Before
flow = Flows.Flow(vf; ad_backend=backend)  # silently ignored for AD-free vf

# After
flow = Flows.Flow(vf)
```

### `CTFlows.Integrators.build_integrator` is no longer re-exported

Construct the integrator strategy through the supported `SciML` constructor.

```julia
# Before
CTFlows.Integrators.build_integrator(...)

# After
CTFlows.Integrators.SciML(; opts...)
```

## 0.14.0-beta

### `ControlledTrajectory` was renamed to `StateFlowTrajectory`

There is no compatibility alias.

```julia
# Before
isa(trajectory, Trajectories.ControlledTrajectory)

# After
isa(trajectory, Trajectories.StateFlowTrajectory)
```

### `Data` moved to `CTBase.Data`

The source implementation moved out of CTFlows. Use the CTBase namespace for
new code; `CTFlows.Data` remains only as a compatibility alias.

```julia
# Before
CTFlows.Data.VectorField(...)

# After
CTBase.Data.VectorField(...)
```

### OCP-backed point calls coerce 1-D states to scalars

Basic, controlled, and multi-phase OCP-backed point calls now follow the
1-D-is-a-scalar convention.

```julia
# Before
xf = flow(t0, [x0], tf)  # length-one vector

# After
xf = flow(t0, x0, tf)    # scalar
```

## 0.12.0-beta

### Constrained flows require a control law

A constrained control-free OCP must now be rejected explicitly. Supply a control
law when constructing a constrained flow.

```julia
# Before
Flows.Flow(ocp; constraint=g, multiplier=μ)

# After
Flows.Flow(ocp, law; constraint=g, multiplier=μ)
```

### Constrained `hamiltonian_type=:partial` is now supported

Code that relied on construction failing with `IncorrectArgument` must no longer
treat that failure as the expected behavior.

```julia
# Before
@test_throws CTBase.Exceptions.IncorrectArgument Flows.Flow(
    ocp, law; constraint=g, multiplier=μ, hamiltonian_type=:partial
)

# After
flow = Flows.Flow(
    ocp, law; constraint=g, multiplier=μ, hamiltonian_type=:partial
)
```

## 0.10.0-beta

### `Flow(ocp)` rejects OCPs with controls

`Flow(ocp)` now supports only control-free OCPs. Use the control-law constructor
for an OCP with controls.

```julia
# Before
flow = Flows.Flow(controlled_ocp)  # silently ignored the control

# After
flow = Flows.Flow(controlled_ocp, law)
```

## 0.9.4-beta

### `Common.NotProvided` moved to `CTBase.Core`

The CTFlows-local sentinel and re-export were removed.

```julia
# Before
CTFlows.Common.NotProvided

# After
CTBase.Core.NotProvided
```
